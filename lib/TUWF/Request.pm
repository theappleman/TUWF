
package TUWF::Request;

use strict;
use warnings;
use Encode 'decode_utf8', 'encode_utf8';
use Exporter 'import';
use Carp 'croak';

our @EXPORT = qw|
  reqInit reqGET reqPOST reqParam reqUploadMIME reqUploadRaw reqSaveUpload
  reqCookie reqMethod reqHeader reqPath reqBaseURI reqURI reqHost reqIP
|;


sub reqInit {
  my $self = shift;
  $self->{_TUWF}{Req} = {};

  # lighttpd doesn't always split the query string from REQUEST_URI
  if($ENV{SERVER_SOFTWARE}||'' =~ /lighttpd/) {
    ($ENV{REQUEST_URI}, $ENV{QUERY_STRING}) = split /\?/, $ENV{REQUEST_URI}, 2
      if ($ENV{REQUEST_URI}||'') =~ /\?/;
  }

  # TODO: generate a proper error page instead of 500
  my $meth = $self->reqMethod;
  die "Unsupported HTTP method '$meth'\n" if $meth !~ /^(GET|POST|HEAD)$/;

  $self->{_TUWF}{Req}{Cookies} = _parse_cookies($ENV{HTTP_COOKIE} || $ENV{COOKIE});
  $self->{_TUWF}{Req}{GET} = _parse_urlencoded($ENV{QUERY_STRING});

  if($meth eq 'POST' && $ENV{CONTENT_LENGTH}) {
    # TODO: generate proper error page...
    die "POST body too large!\n" if $self->{_TUWF}{max_post_body} && $ENV{CONTENT_LENGTH} > $self->{_TUWF}{max_post_body};

    # TODO: generate a proper error page instead of 500
    my $data;
    die "Couldn't read all POST data.\n" if $ENV{CONTENT_LENGTH} > read STDIN, $data, $ENV{CONTENT_LENGTH}, 0;

    if(($ENV{'CONTENT_TYPE'}||'') =~ m{^multipart/form-data; boundary=(.+)$}) {
      _parse_multipart($self, $data, $1);
    } else {
      $self->{_TUWF}{Req}{POST} = _parse_urlencoded($data);
    }
  }
}


sub _parse_urlencoded {
  my %dat;
  for (split /[;&]/, decode_utf8 shift) {
    my($key, $val) = split /=/, $_, 2;
    next if !defined $key or !defined $val;
    for ($key, $val) {
      s/\+/ /gs;
      # assume %XX sequences represent UTF-8 bytes and properly decode it.
      s#((?:%[0-9a-fA-F]{2})+)#
        (my $s=encode_utf8 $1) =~ s/%(.{2})/chr hex($1)/eg;
        decode_utf8($s);
      #eg;
      s/%u([0-9a-fA-F]{4})/chr hex($1)/eg;
    }
    push @{$dat{$key}}, $val;
  }
  return \%dat;
}


# Heavily inspired by CGI::Minimal::Multipart::_burst_multipart_buffer()
sub _parse_multipart {
  my($self, $data, $boundary) = @_;
  my $nfo = $self->{_TUWF}{Req};
  my $CRLF = "\015\012";

  $nfo->{POST} = {};
  $nfo->{FILES} = {};
  $nfo->{MIMES} = {};

  for my $p (split /--\Q$boundary\E(?:--)?$CRLF/, $data) {
    next if !defined $p;
    $p =~ s/$CRLF$//;
    last if $p eq '--';
    next if !$p;
    my($header, $value) = split /$CRLF$CRLF/, $p, 2;

    my($name, $mime, $filename) = ('', '', '');
    for my $h (split /$CRLF/, $header) {
      my($hn, $hv) = split /: /, $h, 2;
      # Does not handle multipart/mixed, but those don't appear to be used in practice.
      if($hn =~ /^Content-Type$/i) {
        $mime = $hv;
      }
      if($hn =~ /^Content-Disposition$/i) {
        for my $dis (split /; /, $hv) {
          $name     = $2 if $dis =~ /^name=("?)(.*)\1$/;
          $filename = $2 if $dis =~ /^filename=("?)(.*)\1$/;
        }
      }
    }

    $name = decode_utf8 $name;

    # In the case of a file upload, use the filename as value instead of the
    # data. This is to ensure that reqPOST() always returns decoded data.

    # Note that I use the presence of a filename attribute for determining
    # whether this parameters comes from an <input type="file"> rather than a
    # regular form element. The standards do not require the filename to be
    # present, but I am not aware of any browser that does not send it.
    if($filename) {
      push @{$nfo->{POST}{$name}}, decode_utf8 $filename;
      push @{$nfo->{MIMES}{$name}}, decode_utf8 $mime;
      push @{$nfo->{FILES}{$name}}, $value; # not decoded, can be binary
    } else {
      push @{$nfo->{POST}{$name}}, decode_utf8 $value;
    }
  }
}


sub _parse_cookies {
  my $str = shift;
  return {} if !$str;

  my %dat;
  # The format of the Cookie: header is hardly standardized and the widely used
  # implementations all differ in how they interpret the data. This (rather)
  # lazy implementation assumes the cookie values are not escaped and don't
  # contain any characters that are used within the header format.
  for (split /[;,]/, decode_utf8 $str) {
    s/^ +//;
    s/ +$//;
    next if !$_ || !m{^([^\(\)<>@,;:\\"/\[\]\?=\{\}\t\s]+)=("?)(.*)\2$};
    $dat{$1} = $3 if !exists $dat{$1};
  }
  return \%dat;
}


# get parameters from the query string
sub reqGET {
  my($s, $n) = @_;
  my $lst = $s->{_TUWF}{Req}{GET};
  return keys %$lst if !$n;
  return wantarray ? () : undef if !$lst->{$n};
  return wantarray ? @{$lst->{$n}} : $lst->{$n}[0];
}


# get parameters from the POST body
sub reqPOST {
  my($s, $n) = @_;
  my $lst = $s->{_TUWF}{Req}{POST};
  return keys %$lst if !$n;
  return wantarray ? () : undef if !$lst->{$n};
  return wantarray ? @{$lst->{$n}} : $lst->{$n}[0];
}


# get parameters from either or both POST and GET
# (POST has priority over GET in scalar context)
sub reqParam {
  my($s, $n) = @_;
  my $nfo = $s->{_TUWF}{Req};
  if(!$n) {
    my %keys = map +($_,1), keys(%{$nfo->{GET}}), keys(%{$nfo->{POST}});
    return keys %keys;
  }
  my $val = [
    $nfo->{POST}{$n} ? @{$nfo->{POST}{$n}} : (),
    $nfo->{GET}{$n}  ? @{$nfo->{GET}{$n}}  : (),
  ];
  return wantarray ? () : undef if !@$val;
  return wantarray ? @$val : $val->[0];
}


# returns the MIME Type of an uploaded file.
sub reqUploadMIME {
  my($self, $n) = @_;
  my $nfo = $self->{_TUWF}{Req}{MIMES};
  return keys %$nfo if !defined $n;
  return wantarray ? () : undef if !$nfo->{$n};
  return wantarray ? @{$nfo->{$n}} : $nfo->{$n}[0];
}


# returns the raw (encoded) contents of an uploaded file
sub reqUploadRaw {
  my($self, $n) = @_;
  my $nfo = $self->{_TUWF}{Req}{FILES}{$n};
  return wantarray ? () : undef if !$nfo;
  return wantarray ? @$nfo : $nfo->[0];
}


# saves file contents identified by the form name to the specified file
# (doesn't support multiple file upload using the same form name yet)
sub reqSaveUpload {
  my($s, $n, $f) = @_;
  open my $F, '>', $f or croak "Unable to write to $f: $!";
  print $F scalar $s->reqUploadRaw($n);
  close $F;
}


sub reqCookie {
  my($self, $n) = @_;
  my $nfo = $self->{_TUWF}{Req}{Cookies};
  return keys %$nfo if !defined $n;
  return $nfo->{$n};
}


sub reqMethod {
  return decode_utf8 $ENV{REQUEST_METHOD}||'GET';
}


# Returns list of header names when no argument is passed
#   (may be in a different order and can have different casing than
#    the original headers - CGI doesn't preserve that information)
# Returns value of the specified header otherwise, header name is
#   case-insensitive
sub reqHeader {
  my($self, $name) = @_;
  if($name) {
    (my $v = uc $_[1]) =~ tr/-/_/;
    return decode_utf8 $ENV{"HTTP_$v"}||'';
  } else {
    return (map {
      if(/^HTTP_/) { 
        (my $h = lc $_) =~ s/_([a-z])/-\U$1/g;
        $h =~ s/^http-//;
        decode_utf8 $h;
      } else { () }
    } sort keys %ENV);
  }
}


# returns the path part of the current URI, excluding the leading slash
sub reqPath {
  (my $u = $ENV{REQUEST_URI}) =~ s{^/+}{};
  return decode_utf8 $u;
}


# returns base URI, excluding trailing slash
sub reqBaseURI {
  return decode_utf8 ($ENV{HTTPS} ? 'https://' : 'http://').$ENV{HTTP_HOST};
}


sub reqURI {
  my $s = shift;
  return $s->reqBaseURI().decode_utf8($ENV{REQUEST_URI}.($ENV{QUERY_STRING} ? '?'.$ENV{QUERY_STRING} : ''));
}


sub reqHost {
  return decode_utf8 $ENV{HTTP_HOST};
}


sub reqIP {
  return decode_utf8 $ENV{REMOTE_ADDR};
}


1;


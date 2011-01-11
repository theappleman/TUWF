
package TUWF::Request;

use strict;
use warnings;
use Encode 'decode_utf8', 'encode_utf8';
use Exporter 'import';

our @EXPORT = qw|
  reqInit reqGET reqPOST reqParam reqUploadMIME reqUploadFileName reqSaveUpload
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

  $self->{_TUWF}{Req}{GET} = _parse_urlencoded($ENV{QUERY_STRING});

  # TODO: set configurable maximum on CONTENT_LENGTH
  if($meth eq 'POST' && $ENV{CONTENT_LENGTH}) {
    # TODO: add support multipart/form-data support
    die "multipart/form-data is currently not supported.\n" if ($ENV{'CONTENT_TYPE'}||'') =~ m{^multipart/form-data};

    # TODO: generate a proper error page instead of 500
    my $data;
    die "Couldn't read all POST data.\n" if $ENV{CONTENT_LENGTH} > read STDIN, $data, $ENV{CONTENT_LENGTH}, 0;
    $self->{_TUWF}{Req}{POST} = _parse_urlencoded($data);
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


# returns the MIME Type of an uploaded file, requires form name as argument,
# can return an array if multiple file uploads have the same form name
#sub reqUploadMIME {
#  my $c = shift->{_TUWF}{Req}{c};
#  return $c->param_mime(shift);
#}


# same as reqUploadMIME, only this one fetches filenames
#sub reqUploadFileName {
#  my $c = shift->{_TUWF}{Req}{c};
#  return $c->param_filename(shift);
#}


# saves file contents identified by the form name to the specified file
# (doesn't support multiple file upload using the same form name yet)
#sub reqSaveUpload {
#  my($s, $n, $f) = @_;
#  open my $F, '>', $f or die "Unable to write to $f: $!";
#  print $F $s->{_TUWF}{Req}{c}->param($n);
#  close $F;
#}


sub reqCookie {
  require CGI::Cookie::XS;
  my $c = CGI::Cookie::XS->fetch;
  return $c && ref($c) eq 'HASH' && $c->{$_[1]} ? decode_utf8 $c->{$_[1]}[0] : '';
}


sub reqMethod {
  return $ENV{REQUEST_METHOD}||'GET';
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
    return $ENV{"HTTP_$v"}||'';
  } else {
    return (map {
      if(/^HTTP_/) { 
        (my $h = lc $_) =~ s/_([a-z])/-\U$1/g;
        $h =~ s/^http-//;
        $h;
      } else { () }
    } sort keys %ENV);
  }
}


# returns the path part of the current URI, excluding the leading slash
sub reqPath {
  (my $u = $ENV{REQUEST_URI}) =~ s{^/+}{};
  return $u;
}


# returns base URI, excluding trailing slash
sub reqBaseURI {
  return ($ENV{HTTPS} ? 'https://' : 'http://').$ENV{HTTP_HOST};
}


# returns undef if the request isn't initialized yet
sub reqURI {
  return $ENV{HTTP_HOST} && defined $ENV{REQUEST_URI} ?
    ($ENV{HTTPS} ? 'https://' : 'http://').$ENV{HTTP_HOST}.$ENV{REQUEST_URI}.($ENV{QUERY_STRING} ? '?'.$ENV{QUERY_STRING} : '')
    : undef;
}


sub reqHost {
  return $ENV{HTTP_HOST};
}


sub reqIP {
  return $ENV{REMOTE_ADDR};
}


1;


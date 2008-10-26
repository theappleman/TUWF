
package VNDB::Handler::Example;

use strict;
use warnings;
use YAWF ':html', ':xml';


YAWF::register(
  qr/envdump/,   \&envdump,
  qr/error/,     \&error,
  qr/html/,      \&htmlexample,
  qr{v([1-9]\d*)/xml},  \&vnxml,
);


sub envdump {
  my $self = shift;
  $self->resHeader('Content-Type', 'text/plain');
  my $fd = $self->resFd;

  # normally you'd use req* methods to fetch
  # environment-specific information...
  print  $fd "ENV-Dump:\n";
  printf $fd "  %s: %s\n", $_, $ENV{$_} for (sort keys %ENV);

  # ...like this
  print  $fd "\n";
  print  $fd "Header dump:\n";
  printf $fd "  %s: %s\n", $_, $self->reqHeader($_) for ($self->reqHeader());

  # ..and this
  print  $fd "\n";
  print  $fd "Param dump:\n";
  printf $fd "  %s: %s\n", $_, $self->reqParam($_) for ($self->reqParam());
}


sub error {
  # this handler demonstrates a function that fails, YAWF
  # should display a 500 error page and write a detailed
  # report to the log file
  warn "A random warning message before the error actually occurs";
  die "Some descriptive error message here";
}


sub htmlexample {
  html;
   head;
    title 'HTML Output Example';
   end;
   body;
    h1 'HTML Output Example';
    p 'This is a way to output HTML...';
   end;
  end;
}


# this function will get a number as argument, this number was parsed
# from the pattern match above (/v+/xml, we get the + here as argument)
sub vnxml {
  my($self, $id) = @_;

  # Let's actually serve XML as text/xml
  $self->resHeader('Content-Type' => 'text/xml');

  # fetch some information about that VN,
  # defined in VNDB::DB::Misc
  my $v = $self->dbVNInfo($id);

  # no results found, return a 404
  return 404 if !$v->{id};

  # XML output
  xml;
  tag 'vn', id => $id;
   tag 'title', $v->{title};
   tag 'original', $v->{original};
  end;
}


1;



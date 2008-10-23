
package VNDB::Handler::Example;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr/envdump/,   \&envdump,
  qr/error/,     \&error,
  qr/html/,      \&htmlexample,
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


1;


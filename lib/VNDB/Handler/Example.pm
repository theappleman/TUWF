
package VNDB::Handler::Example;

use strict;
use warnings;
use YAWF;


YAWF::register(
  qr/envdump/,  \&envdump
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
}


1;


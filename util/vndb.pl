#!/usr/bin/perl

# this script should be able to be used as both a CGI
# and a FastCGI script.


package VNDB;

use strict;
use warnings;

# determine root directory
use Cwd 'abs_path';
our $ROOT;
BEGIN {
  ($ROOT = abs_path $0) =~ s{/util/vndb\.pl$}{};
}

use lib $ROOT.'/lib';
use YAWF;


# default options
our %O = (
 # required
  namespace => 'VNDB',
  db_login => [ 'dbi:Pg:dbname=vndb', 'vndb', 'passwd' ],
 # optional
  debug => 1,
  logfile => $ROOT.'/data/logs/err.log',
);


# ...can be overwritten in data/config.pl
require $ROOT.'/data/config.pl' if -e $ROOT.'/data/config.pl';


YAWF::init(
  %O,
  error_404_handler => \&page_404,
);


sub page_404 {
  my $self = shift;
  my $fd = $self->resFd;
  print $fd "Wheeeee~ output!\n";
}


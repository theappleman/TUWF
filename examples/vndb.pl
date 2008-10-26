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
  ($ROOT = abs_path $0) =~ s{/examples/vndb\.pl$}{};
}

# make sure YAWF is findable
use lib $ROOT.'/lib';
# and make sure our own example modules are, too
use lib $ROOT.'/examples';


use YAWF;


YAWF::init(

 # required
  namespace => 'VNDB',
  db_login => [ 'dbi:Pg:dbname=vndb', 'vndb', 'passwd' ],

 # optional
  debug => 1,
  logfile => $ROOT.'/data/logs/err.log',

  error_404_handler => \&page_404,
);


sub page_404 {
  my $self = shift;
  my $fd = $self->resFd;
  print $fd "This is our custom 404 error page!\n";
}


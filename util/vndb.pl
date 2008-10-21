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

YAWF::init(
  namespace => 'VNDB',
  logfile => $ROOT.'/data/logs/err.log',
  # etc...
);



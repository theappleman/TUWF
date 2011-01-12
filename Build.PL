#!/usr/bin/perl

use Module::Build;

Module::Build->new(
  dist_name     => 'TUWF',
  dist_version  => '0.1',
  dist_author   => 'Yoran Heling <yorhel@cpan.org>',
  dist_abstract => 'The Ultimate Website Framework',
  license       => 'mit',
  requires => {
    perl => '5.10.0',
  },
  recommends => {
    'PerlIO::gzip'    => 0,
    'FCGI'            => 0,
    'DBI'             => 0,
  },
  create_makefile_pl => 'traditional',
)->create_build_script;


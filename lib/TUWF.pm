# TUWF.pm - the core module for TUWF
#  The Ultimate Website Framework

package TUWF;

use strict;
use warnings;
use Carp 'croak';

# Store the object in a global variable for some functions that don't get it
# passed as an argument. This will break when:
#  - using a threaded environment (threading sucks anyway)
#  - handling multiple requests asynchronously (which this framework can't do)
#  - handling multiple sites in the same perl process. This may be useful in
#    a mod_perl environment, which we don't support.
our $OBJ = bless {
  _TUWF => {
    # defaults
    mail_from => '<noreply-yawf@blicky.net>',
    mail_sendmail => '/usr/sbin/sendmail',
    error_500_handler => \&error_500,
    error_404_handler => \&error_404,
  }
}, 'TUWF::Object';

my @handlers;


sub import {
  my $self = shift;
  my $pack = caller();

  # load and import TUWF::XML when requested
  croak $@ if @_ && !eval "package $pack; use TUWF::XML qw|@_|; 1";
}


# set TUWF configuration variables
sub set {
  $OBJ->{_TUWF} = { %{$OBJ->{_TUWF}}, @_ };
}


sub run {
  # load the database module if requested
  $OBJ->load_module('TUWF::DB') if $OBJ->{_TUWF}{db_login};

  # install a warning handler to write to the log file
  $SIG{__WARN__} = sub { $TUWF::OBJ->log($_) for @_; };

  # load optional modules
  require Time::HiRes if $OBJ->debug || $OBJ->{_TUWF}{log_slow_pages};

  # initialize DB connection
  $OBJ->dbInit if $OBJ->{_TUWF}{db_login};

  # plain old CGI
  if($ENV{GATEWAY_INTERFACE} && $ENV{GATEWAY_INTERFACE} =~ /CGI/i) {
    $OBJ->handle_request;
  }
  # otherwise, assume a FastCGI environment
  else {
    require FCGI;
    import FCGI;
    my $r = FCGI::Request();
    while($r->Accept() >= 0) {
      $OBJ->handle_request;
      $r->Finish();
    }
  }

  # close the DB connection
  $OBJ->dbDisconnect if $OBJ->{_TUWF}{db_login};
}


# Maps URLs to handlers
sub register {
  push @handlers, @_;
}


# Load modules
sub load {
  $OBJ->load_module($_) for (@_);
}

# Load modules, recursively
# All submodules should be under the same directory in @INC
sub load_recursive {
  my $rec;
  $rec = sub {
    my($d, $f, $m) = @_;
    for my $s (glob "$d/$f/*") {
      $OBJ->load_module("${m}::$1") if -f $s && $s =~ /([^\/]+)\.pm$/;
      $rec->($d, "$f/$1", "${m}::$1") if -d $s && $s =~ /([^\/]+)$/;
    }
  };
  for my $m (@_) {
    (my $f = $m) =~ s/::/\//g;
    my $d = (grep +(-d "$_/$f" or -s "$_/$f.pm"), @INC)[0];
    croak "No module or submodules of '$m' found" if !$d;
    $OBJ->load_module($m) if -s "$d/$f.pm";
    $rec->($d, $f, $m) if -d "$d/$f";
  }
}


# these are defaults, you really want to replace these boring pages
sub error_404 {
  my $s = shift;
  $s->resInit;
  $s->resStatus(404);
  very_simple_page($s, '404 - Page Not Found', 'The page you were looking for does not exist...');
}


# a *very* helpful error message :-)
sub error_500 {
  my $s = shift;
  $s->resInit;
  $s->resStatus(500);
  very_simple_page($s, '500 - Internal Server Error', 'Ooooopsie~, something went wrong!');
}


# and an equally beautiful page
sub very_simple_page {
  my($s, $title, $msg) = @_;
  my $fd = $s->resFd;
  print $fd <<__;
<!DOCTYPE html
  PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
 <title>$title</title>
</head>
<body>
 <h1>$title</h1>
 <p>$msg</p>
</body>
</html>
__
}




# The namespace which inherits all functions to be available in the global
# object.
package TUWF::Object;

use TUWF::Response;
use TUWF::Request;
use TUWF::Misc;

require Carp; # but don't import()
our @CARP_NOT = ('TUWF');


sub load_module {
  my($self, $module) = @_;
  Carp::croak $@ if !eval "use $module; 1";
}


# Handles a request (sounds pretty obvious to me...)
sub handle_request {
  my $self = shift;

  my $start = [Time::HiRes::gettimeofday()] if $self->debug || $OBJ->{_TUWF}{log_slow_pages};

  # put everything in an eval to catch any error, even
  # those caused by a TUWF core module
  eval { 

    # initialize request and response objects
    $self->reqInit();
    $self->resInit();

    # initialize TUWF::XML
    $TUWF::XML::OBJ = TUWF::XML->new(
      write  => sub { print { $self->resFd } $_ for @_ },
      pretty => $self->{_TUWF}{xml_pretty},
    );

    # make sure our DB connection is still there and start a new transaction
    $self->dbCheck() if $self->{_TUWF}{db_login};

    # call pre request handler, if any
    $self->{_TUWF}{pre_request_handler}->($self) if $self->{_TUWF}{pre_request_handler};

    # find the handler
    my $loc = $self->reqPath;
    study $loc;
    my $han = $self->{_TUWF}{error_404_handler};
    my @args;
    for (@handlers ? 0..$#handlers/2 : ()) {
      if($loc =~ /^$handlers[$_*2]$/) {
        @args = map defined $-[$_] ? substr $loc, $-[$_], $+[$_]-$-[$_] : undef, 1..$#- if $#-;
        $han = $handlers[$_*2+1];
        last;
      }
    }

    # execute handler
    my $ret = $han->($self, @args);

    # give 404 page if the handler returned 404...
    if($ret && $ret eq '404') {
      $ret = $self->{_TUWF}{error_404_handler}->($self) if $han ne $self->{_TUWF}{error_404_handler};
      TUWF::DefaultHandlers::error_404($self) if $ret && $ret eq '404';
    }

    # execute post request handler, if any
    $self->{_TUWF}{post_request_handler}->($self) if $self->{_TUWF}{post_request_handler};

    # commit changes
    $self->dbCommit if $self->{_TUWF}{db_login};
  };

  # error handling
  if($@) {
    chomp( my $err = $@ );

    # act as if the changes to the DB never happened
    if($self->{_TUWF}{db_login}) {
      eval { $self->dbRollBack; };
      warn $@ if $@;
    }

    # Call the error_500_handler
    # The handler should manually call dbCommit if it makes any changes to the DB
    eval {
      $self->resInit;
      $self->{_TUWF}{error_500_handler}->($self, $err);
    };
    if($@) {
      chomp( my $m = $@ );
      warn "Error handler died as well, something is seriously wrong with your code. ($m)\n";
      TUWF::DefaultHandlers::error_500($self, $err);
    }

    # write detailed information about this error to the log
    $self->log(
      "FATAL ERROR!\n".
      "HTTP Request Headers:\n".
      join('', map sprintf("  %s: %s\n", $_, $self->reqHeader($_)), $self->reqHeader).
      "Param dump:\n".
      join('', map sprintf("  %s: %s\n", $_, $self->reqParam($_)), $self->reqParam).
      "Error:\n  $err\n"
    );
  }

  # finalize response (flush output, etc)
  eval { $self->resFinish; };
  warn $@ if $@;

  # log debug information in the form of:
  # >  12ms (SQL:  8ms,  2 qs) for http://beta.vndb.org/v10
  my $time = Time::HiRes::tv_interval($start)*1000 if $self->debug || $self->{_TUWF}{log_slow_pages};
  if($self->debug || ($self->{_TUWF}{log_slow_pages} && $self->{_TUWF}{log_slow_pages} < $time)) {
    # SQL stats (don't count the ping and commit as queries, but do count their time)
    my($sqlt, $sqlc) = (0, 0);
    if($self->{_TUWF}{db_login}) {
      $sqlc = grep $_->[0] ne 'ping/rollback' && $_->[0] ne 'commit', @{$self->{_TUWF}{DB}{queries}};
      $sqlt += $_->[1]*1000
        for (@{$self->{_TUWF}{DB}{queries}});
    }

    $self->log(sprintf('>%4dms (SQL:%4dms,%3d qs) for %s',
      $time, $sqlt, $sqlc, $self->reqURI), 1);
  }
}


# convenience function
sub debug {
  return shift->{_TUWF}{debug};
}


# writes a message to the log file. date, time and URL are automatically added
# An optional 3rd argument can be passed to exclude the date, time and url information
sub log {
  my($self, $msg, $excl) = @_;
  chomp $msg;
  $msg =~ s/\n/\n  | /g;
  if($self->{_TUWF}{logfile} && open my $F, '>>:utf8', $self->{_TUWF}{logfile}) {
    flock $F, 2;
    seek $F, 0, 2;
    printf $F "[%s] %s: %s\n", scalar localtime(), $self->reqURI||'[init]', $msg if !$excl;
    print $F "$msg\n" if $excl;
    flock $F, 4;
    close $F;
  }
}


1;


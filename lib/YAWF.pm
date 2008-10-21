# YAWF.pm - the core module for YAWF
#   Yet Another Website Framework
#   Yorhels Awesome Website Framework

package YAWF;

use strict;
use warnings;

# Store the object in a global variable for some functions that don't get it
# passed as an argument. This will break when:
#  - using a threaded environment (threading sucks anyway)
#  - handling multiple requests asynchronously (which this framework can't do)
#  - handling multiple sites in the same perl process. This may be useful in
#    a FastCGI or mod_perl environment, so need to find a fix for that >.>
our $OBJ;
my @handlers;


# The holy init() function
sub init {
  my %o = (
    # default error_500_handler and error_404_handler here...
    @_
  );
  die "No namespace argument specified!" if !$o{namespace};
  die "db_login argument required!" if !$o{db_login};

  # create object
  $OBJ = bless {
    _YAWF => \%o,
    $o{object_data} && ref $o{object_data} eq 'HASH' ? %{ delete $o{object_data} } : (),
  }, 'YAWF::Object';

  # install a warning handler to write to the log file
  $SIG{__WARN__} = \&log_warning;

  # load optional modules
  require Time::HiRes if $OBJ->debug;

  # load the modules
  $OBJ->load_modules;

  # initialize DB connection
  $OBJ->dbInit;

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
  $OBJ->dbDisconnect;
}


# Maps URLs to handlers
sub register {
  push @handlers, @_;
}


# Writes warning messages to the log file (if there is a log file)
sub log_warning {
  if($YAWF::OBJ->{_YAWF}{logfile} && open my $F, '>>', $YAWF::OBJ->{_YAWF}{logfile}) {
    flock $F, 2;
    seek $F, 0, 2;
    while(local $_ = shift) {
      chomp;
      printf $F "[%s] %s: %s\n", scalar localtime(), $OBJ->reqFullURI||'[init]', $_;
    }
    flock $F, 4;
    close $F;
  } else {
    warn @_;
  }
}



# The namespace which inherits all functions to be available in the global
# object. These functions are not inherited by the main YAWF namespace.
package YAWF::Object;

use YAWF::Request;
use YAWF::DB;


# This function will load all site modules and import the exported functions
sub load_modules {
  my $s = shift;
  (my $f = $s->{_YAWF}{namespace}) =~ s/::/\//g;
  for my $p (@INC) {
    for (glob $p.'/'.$f.'/{DB,Util,Handler}/*.pm') {
      (my $m = $_) =~ s{^\Q$p/}{};
      $m =~ s/\.pm$//;
      $m =~ s{/}{::}g;
      # the following is pretty much equivalent to eval "use $m";
      require $_;
      no strict 'refs';
      "$m"->import if *{"${m}::import"}{CODE};
    }
  }
}


# Handles a request (sounds pretty obvious to me...)
sub handle_request {
  my $self = shift;

  # put everything in an eval to catch any error, even
  # those caused by a YAWF core module
  eval { 

    # initialize request and response objects
    $self->reqInit();
    #$self->resInit();
    
    # make sure our DB connection is still there and start a new transaction
    $self->dbCheck();

    # call pre request handler, if any
    $self->{_YAWF}{pre_request_handler}->($self) if $self->{_YAWF}{pre_request_handler};

    # find the handler
    my $loc = ''; #$self->reqLocation;
    study $loc;
    my $han = $self->{_YAWF}{error_404_handler};
    for (@handlers ? 0..@handlers/2 : ()) {
      if($loc =~ /^$handlers[$_]$/) {
        $han = $handlers[$_+1];
        last;
      }
    }

    # a default 404 handler may be a better idea than just dying like this
    die "Oops, no handler found..." if !$han;
    
    # execute handler
    $han->($self);

    # execute post request handler, if any
    $self->{_YAWF}{post_request_handler}->($self) if $self->{_YAWF}{post_request_handler};

    # commit changes
    $self->dbCommit;
  };

  # error handling
  if($@) {
    # act as if the changes to the DB never happened
    eval { $self->dbRollBack; };
    warn $@ if $@;

    # Call the error_500_handler
    # The handler should manually call dbCommit if it makes any changes to the DB
    eval { $self->{_YAWF}{error_500_handler}->($self); };
    warn "Error handler died as well, something is seriously wrong with your code. ($@)" if $@;

    # some logging here...
  }

  # finalize response (flush output, etc)
  # eval { $self->resFinish; }
  warn $@ if $@;

  if($self->debug) {
    # log some debug info here
  }
}


# convenience function
sub debug {
  return shift->{_YAWF}{debug};
}


1;


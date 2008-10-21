# YAWF.pm - the core module for YAWF
#   Yet Another Website Framework
#   Yorhels Awesome Website Framework

package YAWF;

use strict;
use warnings;

# Store the object in a global variable for some functions that don't get it
# passed as an argument. This will break when YAWF is run in a threaded
# environment, but threading sucks anyway. >_>
our $OBJ;
my @handlers;


# The holy init() function
sub init {
  my %o = @_;
  die "No namespace argument specified!" if !$o{namespace};

  # create object
  $OBJ = bless {
    _YAWF => \%o,
    $o{object_data} && ref $o{object_data} eq 'HASH' ? %{ delete $o{object_data} } : (),
  }, 'YAWF::Object';

  # load the modules
  $OBJ->load_modules;

  # initialize DB connection
  #$OBJ->dbInit;

  # plain old CGI
  if($ENV{GATEWAY_INTERFACE} && $ENV{GATEWAY_INTERFACE} =~ /CGI/i) {
    $OBJ->handle_request;
  }
  # otherwise, assume a FastCGI environment
  else {
    require FCGI;
    my $r = FCGI::Request();
    while($r->Accept() >= 0) {
      $OBJ->handle_request;
      $r->Finish();
    }
  }

  # close the DB connection
  #$OBJ->dbDisconnect;
}


# Maps URLs to handlers
sub register {
  push @handlers, @_;
}



# The namespace which inherits all functions to be available in the global
# object. These functions are not inherited by the main YAWF namespace.
package YAWF::Object;


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

  # initialize request and response objects
  #$self->reqInit();
  #$self->resInit();
  
  # make sure our DB connection is still there and start a new transaction
  #$self->dbCheck();

  # find the handler
  my $loc = ''; #$self->resLocation;
  study $loc;
  my $han;
  for (@handlers ? 0..@handlers/2 : ()) {
    if($loc =~ /^$handlers[$_]$/) {
      $han = $handlers[$_+1];
      next;
    }
  }
}


1;


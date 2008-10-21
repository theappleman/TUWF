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


# The holy init() function
sub init {
  my %o = @_;
  die "No namespace argument specified!" if !$o{namespace};

  # create object
  $OBJ = bless {
    _YAWF => \%o,
    $o{object_data} && ref $o{object_data} eq 'HASH' ? %{ delete $o{object_data} } : (),
  }, 'YAWF::Object';

  $OBJ->load_modules;
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
      (my $m = $_) =~ s{^$p/}{};
      $m =~ s/\.pm$//;
      $m =~ s{/}{::}g;
      # the following is pretty much equivalent to eval "use $m";
      require $_;
      no strict 'refs';
      "$m"->import if *{"${m}::import"}{CODE};
    }
  }
}


1;


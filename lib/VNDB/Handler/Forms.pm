
package VNDB::Handler::Forms;

use strict;
use warnings;
use YAWF ':html';
use Data::Dumper 'Dumper';


$Data::Dumper::Sortkeys++;
$Data::Dumper::Terse++;


# an alternative way of writing handlers (TIMTOWTDI)
YAWF::register(
qr/formtest/, sub {
  my $self = shift;

  my @rules;
  my $rules = q{  (
    { name => 'string1', required => 1, maxlength => 20, minlength => 10, enum => [qw|50 hundred only-valid-value|] },
    { name => 'string2', required => 0, regex => [ qr/default/, 'fail message' ], default => 'this is a default (and matches)' },
    { name => 'string3', required => 1, func => [ sub {
        if(length $_[0] > 5) { $_[0] = uc($_[0]); return $_[0] } else { return undef }
      }, 'another fail message' ] },
    { name => 'string4', required => 1, template => 'int' },
  )};
  eval '@rules = '.$rules;

  my $frm = $self->formValidate(@rules);

  html;
   head;
    title 'Form Validation Test';
   end;
   body;
    h1 'Form Validation Test';
    h2 'A Random Form...';
    form action => '/formtest', method => 'post';
    fieldset;
     for (1..4) {
       label for => 'string'.$_, '#'.$_;
       input type => 'text', id => 'string'.$_, name => 'string'.$_,
         value => $frm->{"string$_"}, size => 50, undef;
       br undef;
     }
     input type => 'submit', value => 'Submit!', undef;
    end;
    end;
    h2 '@rules = ';
    pre $rules;
    h2 'Dumper($self->formValidate(@rules));';
    pre Dumper $frm;
   end;
  end;
},
);


1;

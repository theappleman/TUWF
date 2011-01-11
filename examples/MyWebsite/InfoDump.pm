#!/usr/bin/perl

# This example demonstrates how one can fetch request information

package MyWebsite::InfoDump;

use strict;
use warnings;
use TUWF ':html';


TUWF::register(
  qr/info/       => \&info,
  qr{info/forms} => \&forms,
);


sub info {
  my $self = shift;

  my $tr = sub { Tr; td shift; td shift; end };

  html;
   head;
    style type => 'text/css';
     txt 'thead td { font-weight: bold }';
     txt 'td { border: 1px outset; padding: 3px }';
    end;
   end;
   body;
    h1 'TUWF Info Dump';
    p;
     txt 'You can use ';
     a href => '/info/forms', 'these forms';
     txt ' to generate some interesting GET/POST data.';
    end;

    h2 'GET Parameters';
    table;
     thead; Tr; td 'Name'; td 'Value'; end; end;
     $tr->($_, join "\n---\n", $self->reqGET($_)) for ($self->reqGET());
    end;

    h2 'POST Parameters';
    table;
     thead; Tr; td 'Name'; td 'Value'; end; end;
     $tr->($_, join "\n---\n", $self->reqPOST($_)) for ($self->reqPOST());
    end;

    h2 'HTTP Headers';
    table;
     thead; Tr; td 'Header'; td 'Value'; end; end;
     $tr->($_, $self->reqHeader($_)) for ($self->reqHeader());
    end;

    h2 'Misc. request functions';
    table;
     thead; Tr; td 'Function'; td 'Return value'; end; end;
     $tr->($_, eval "\$self->$_;") for(qw{
       reqMethod() reqPath() reqBaseURI() reqURI() reqHost() reqIP()
     });
    end;
  end;
}


sub forms {
  html;
   body;
    h1 'Forms for generating some input for /info';
    a href => '/info', 'Back to /info';

    h2 'GET';
    form method => 'GET', action => '/info';
     for (0..5) {
       input type => 'checkbox', name => 'checkthing', value => $_, id => "checkthing_$_", $_%2 ? (checked => 'checked') : ();
       label for => "checkthing_$_", "checkthing $_";
     }
     br;
     label for => 'textfield', 'Text field: ';
     input type => 'text', name => 'textfield', id => 'textfield', value => 'Hello Text Field!';
     br;
     input type => 'submit';
    end;

    h2 'POST (urlencoded)';
    form method => 'POST', action => '/info';
     for (0..5) {
       input type => 'checkbox', name => 'checkbox', value => $_, id => "checkbox_$_", $_%2 ? (checked => 'checked') : ();
       label for => "checkthing_$_", "checkbox $_";
     }
     br;
     label for => 'text', 'Text: ';
     use utf8;
     input type => 'text', name => 'text', id => 'text', value => 'こんにちは';
     br;
     input type => 'submit';
    end;

   end;
  end;
}


1;


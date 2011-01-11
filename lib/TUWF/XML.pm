#!/usr/bin/perl


package TUWF::XML;


use strict;
use warnings;
use Exporter 'import';
use Carp 'carp', 'croak';


our(@EXPORT_OK, %EXPORT_TAGS, @htmltags, @htmlexport, @xmlexport, %htmlbool, $OBJ);


BEGIN {
  # xhtml 1.0 tags
  @htmltags = qw|
    address blockquote div dl fieldset form h1 h2 h3 h4 h5 h6 noscript ol p pre ul
    a abbr acronym b bdo big br button cite code dfn em i img input kbd label Map
    object q samp Select small span strong Sub sup textarea tt var caption col
    colgroup table tbody td tfoot th thead Tr area base body dd del dt head ins
    legend li Link meta optgroup option param script style title
  |;

  # boolean (self-closing) tags
  %htmlbool = map +($_,1), qw| hr br img input area base frame link param |;

  # functions to export
  @htmlexport = (@htmltags, qw| html lit txt tag end |);
  @xmlexport = qw| xml lit txt tag end |;

  # create the subroutines to map to the html tags
  no strict 'refs';
  for my $e (@htmltags) {
    *{__PACKAGE__."::$e"} = sub {
      my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
      $s->tag(lc($e), @_, $htmlbool{lc($e)} && $#_%2 ? undef : ());
    }
  }

  @EXPORT_OK = (@htmlexport, @xmlexport, 'xml_escape');
  %EXPORT_TAGS = (
    html => \@htmlexport,
    xml  => \@xmlexport,
  );
};


sub new {
  my($pack, %o) = @_;
  return bless {
    %o,
    stack => [],
  }, $pack;
};


# HTML escape, also does \n to <br /> conversion
# (not a method)
sub xml_escape {
  local $_ = shift;
  if(!defined $_) {
    carp "Attempting to XML-escape an undefined value";
    return '';
  }
  s/&/&amp;/g;
  s/</&lt;/g;
  s/>/&gt;/g;
  s/"/&quot;/g;
  s/\r?\n/<br \/>/g;
  return $_;
}


# output literal data (not HTML escaped)
sub lit {
  my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
  $s->{write}->($_) for @_;
}


# output text (HTML escaped)
sub txt {
  my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
  $s->lit(xml_escape $_) for @_;
}


# Output any XML or HTML tag.
# Arguments                           Output
#  'tagname'                           <tagname>
#  'tagname', id => "main"             <tagname id="main">
#  'tagname', '<bar>'                  <tagname>&lt;bar&gt;</tagname>
#  'tagname', id => 'main', '<bar>'    <tagname id="main">&lt;bar&gt;</tagname>
#  'tagname', id => 'main', undef      <tagname id="main" />
#  'tagname', undef                    <tagname />
sub tag {
  my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
  my $name = shift;
  croak "Invalid XML tag name" if !$name || $name =~ /^(xml|[^a-z])/i || $name =~ / /;

  my $t = $s->{pretty} ? "\n".(' 'x(@{$s->{stack}}*$s->{pretty})) : '';
  $t .= '<'.$name;
  while(@_ > 1) {
    my $attr = shift;
    croak "Invalid XML attribute name" if !$attr || $attr =~ /^(xml|[^a-z])/i || $attr =~ / /;
    $t .= qq{ $attr="}.xml_escape(shift).'"';
  }

  if(!@_) {
    $t .= '>';
    $s->lit($t);
    push @{$s->{stack}}, $name;
  } elsif(!defined $_[0]) {
    $s->lit($t.' />');
  } else {
    $s->lit($t.'>'.xml_escape(shift).'</'.$name.'>');
  } 
}


# Ends the last opened tag
sub end() {
  my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
  my $l = pop @{$s->{stack}};
  $s->lit("\n".(' 'x(@{$s->{stack}}*$s->{pretty}))) if $s->{pretty};
  $s->lit('</'.$l.'>');
}


# Special function, this writes the XHTML 1.0 Strict doctype
# (other doctypes aren't supported at the moment)
sub html() {
  my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
  $s->lit(qq|<!DOCTYPE html
  PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">|);
  push @{$s->{stack}}, 'html';
}


# Writes an xml header, doesn't open an <xml> tag, and doesn't need an
# end() either.
sub xml() {
  my $s = ref($_[0]) eq __PACKAGE__ ? shift : $OBJ;
  $s->lit(qq|<?xml version="1.0" encoding="UTF-8"?>|);
}


1;


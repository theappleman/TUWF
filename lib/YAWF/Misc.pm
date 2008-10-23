
package YAWF::Misc;


use Exporter 'import';

our @EXPORT = ('mail');


# A simple mail function, body and headers as arguments. Usage:
#  $self->mail('body', header1 => 'value of header 1', ..);
sub mail {
  my $self = shift;
  my $body = shift;
  my %hs = @_;

  die "No To: specified!\n" if !$hs{To};
  die "No Subject: specified!\n" if !$hs{Subject};
  $hs{'Content-Type'} ||= 'text/plain; charset=\'UTF-8\'';
  $hs{From} ||= $self->{_YAWF}{mail_from};
  $body =~ s/\r?\n/\n/g;

  my $mail = '';
  foreach (keys %hs) {
    $hs{$_} =~ s/[\r\n]//g;
    $mail .= sprintf "%s: %s\n", $_, $hs{$_};
  }
  $mail .= sprintf "\n%s", $body;

  if(open(my $mailer, '|-:utf8', "$self->{_YAWF}{mail_sendmail} -t -f '$hs{From}'")) {
    print $mailer $mail;
    die "Error running sendmail ($!)"
      if !close($mailer);
  } else {
    die "Error opening sendail ($!)";
  }
}


1;

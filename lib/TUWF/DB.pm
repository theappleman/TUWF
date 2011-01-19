
package TUWF::DB;

use strict;
use warnings;
use DBI;

use Exporter 'import';
our @EXPORT = qw|
  dbInit dbCheck dbDisconnect dbCommit dbRollBack
  dbExec dbRow dbAll dbPage
|;


sub dbInit {
  my $self = shift;
  $self->{_TUWF}{DB} = {
    sql => DBI->connect(@{$self->{_TUWF}{db_login}}, {
      PrintError => 0, RaiseError => 1, AutoCommit => 0,
      mysql_enable_utf8 => 1, # DBD::mysql
      pg_enable_utf8    => 1, # DBD::Pg
      sqlite_unicode    => 1, # DBD::SQLite
    }),
    queries => [],
  };
}


sub dbCheck {
  my $self = shift;
  my $info = $self->{_TUWF}{DB};

  my $start;
  if($self->debug || $self->{_TUWF}{log_slow_pages}) {
    $info->{queries} = [];
    $start = [Time::HiRes::gettimeofday()];
  }

  if(!$info->{sql}->ping) {
    warn "Ping failed, reconnecting";
    $self->dbInit;
  }
  $self->dbRollBack;
  push(@{$info->{queries}},
    [ 'ping/rollback', Time::HiRes::tv_interval($start) ])
   if $self->debug || $self->{_TUWF}{log_slow_pages};
}


sub dbDisconnect {
  shift->{_TUWF}{DB}{sql}->disconnect();
}


sub dbCommit {
  my $self = shift;
  my $start = [Time::HiRes::gettimeofday()] if $self->debug || $self->{_TUWF}{log_slow_pages};
  $self->{_TUWF}{DB}{sql}->commit();
  push(@{$self->{_TUWF}{DB}{queries}}, [ 'commit', Time::HiRes::tv_interval($start) ])
    if $self->debug || $self->{_TUWF}{log_slow_pages};
}


sub dbRollBack {
  shift->{_TUWF}{DB}{sql}->rollback();
}


# execute a query and return the number of rows affected
sub dbExec {
  return sqlhelper(shift, 0, @_);
}


# ..return the first row as an hashref
sub dbRow {
  return sqlhelper(shift, 1, @_);
}


# ..return all rows as an arrayref of hashrefs
sub dbAll {
  return sqlhelper(shift, 2, @_);
}


# same as dbAll, but paginates results by adding
# an OFFSET and LIMIT to the query, the first argument
# should be a hashref with the keys page and results.
# Returns the usual value from dbAll and a value
# indicating whether there is a next page
sub dbPage {
  my($s, $o, $q, @a) = @_;
  $q .= ' LIMIT ? OFFSET ?';
  push @a, $o->{results}+1, $o->{results}*($o->{page}-1);
  my $r = $s->dbAll($q, @a);
  return ($r, 0) if $#$r != $o->{results};
  pop @$r;
  return ($r, 1);
}


sub sqlhelper { # type, query, @list
  my $self = shift;
  my $type = shift;
  my $sqlq = shift;
  my $s = $self->{_TUWF}{DB}{sql};

  my $start = [Time::HiRes::gettimeofday()] if $self->debug || $self->{_TUWF}{log_slow_pages};

  $sqlq =~ s/\r?\n/ /g;
  $sqlq =~ s/  +/ /g;
  my(@q) = @_ ? sqlprint($sqlq, @_) : ($sqlq);
  $self->log($q[0].' | '.join(', ', map defined($_)?"'$_'":'NULL', @q[1..$#q])) if $self->{_TUWF}{log_queries};

  my $q = $s->prepare($q[0]);
  $q->execute($#q ? @q[1..$#q] : ());
  my $r = $type == 1 ? $q->fetchrow_hashref :
          $type == 2 ? $q->fetchall_arrayref({}) :
                       $q->rows;
  $q->finish();

  push(@{$self->{_TUWF}{DB}{queries}}, [ \@q, Time::HiRes::tv_interval($start) ]) if $self->debug || $self->{_TUWF}{log_slow_pages};

  $r = 0  if $type == 0 && (!$r || $r == 0);
  $r = {} if $type == 1 && (!$r || ref($r) ne 'HASH');
  $r = [] if $type == 2 && (!$r || ref($r) ne 'ARRAY');

  return $r;
}


# sqlprint:
#   ?    normal placeholder
#   !l   list of placeholders, expects arrayref
#   !H   list of SET-items, expects hashref or arrayref: format => (bind_value || \@bind_values)
#   !W   same as !H, but for WHERE clauses (AND'ed together)
#   !s   the classic sprintf %s, use with care
# This isn't sprintf, so all other things won't work,
# Only the ? placeholder is supported, so no dollar sign numbers or named placeholders
# Indeed, this also means you can't use PgSQL operators containing a question mark

sub sqlprint { # query, bind values. Returns new query + bind values
  my @a;
  my $q='';
  for my $p (split /(\?|![lHWs])/, shift) {
    next if !defined $p;
    if($p eq '?') {
      push @a, shift;
      $q .= $p;
    } elsif($p eq '!s') {
      $q .= shift;
    } elsif($p eq '!l') {
      my $l = shift;
      $q .= join ', ', map '?', 0..$#$l;
      push @a, @$l;
    } elsif($p eq '!H' || $p eq '!W') {
      my $h=shift;
      my @h=ref $h eq 'HASH' ? %$h : @$h;
      my @r;
      while(my($k,$v) = (shift(@h), shift(@h))) {
        last if !defined $k;
        my($n,@l) = sqlprint($k, ref $v eq 'ARRAY' ? @$v : $v);
        push @r, $n;
        push @a, @l;
      }
      $q .= ($p eq '!W' ? 'WHERE ' : 'SET ').join $p eq '!W' ? ' AND ' : ', ', @r
        if @r;
    } else {
      $q .= $p;
    }
  }
  return($q, @a);
}



1;

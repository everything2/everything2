package Everything::PasswordMigration;

use strict;
use warnings;

use JSON ();
use Time::HiRes ();

=head1 NAME

Everything::PasswordMigration - one-time migration of pre-salt password storage

=head1 DESCRIPTION

Moves every account whose password predates salting (user.salt empty or NULL) to the forms
described in Everything::Application (see "Password storage"): a stored password becomes a
salted legacy hash that still accepts what logs in today, and an empty one becomes the
no-password marker. Run by tools/migrate_legacy_passwords.pl (see --help).

Safety:

=over

=item * Dry run unless C<apply> is set.

=item * Keyset batches by user_id, so it can stop and resume; already-migrated rows have a salt
and aren't selected again.

=item * Each new value is checked against the old password before it's written.

=item * Each row is updated only if it's still exactly what was read (a login in between wins).

=item * The user's cache version is bumped in the same transaction, so running app processes
drop their cached copy.

=item * Progress is printed as one JSON line per batch; passwords are never printed.

=item * Guest User (configured guest_user) gets the no-password marker, not a legacy hash: being
the guest is decided by node id, so it must never authenticate by password. It's reported by
name. System accounts used as authors (EDB, Cool Man Eddie, ...) migrate like any other, so
their old password keeps working for admins who log into them.

=back

=cut

sub new
{
  my ($class, %opt) = @_;
  my $self = bless {
    app        => $opt{app} || $Everything::APP,
    db         => $opt{db}  || $Everything::DB,
    apply      => $opt{apply} ? 1 : 0,
    batch_size => $opt{batch_size} || 500,
    pause      => defined $opt{pause} ? $opt{pause} : 0.2,
    limit      => $opt{limit} || 0,
    ids        => $opt{ids},                         # arrayref: only these user_ids (testing)
    out        => $opt{out} || \*STDOUT,
  }, $class;
  $self->{guest_user_id} = defined $opt{guest_user_id} ? $opt{guest_user_id}
    : eval { $Everything::CONF->guest_user } // 0;
  return $self;
}

sub _dbh { return $_[0]->{db}->getDatabaseHandle() }

sub _scope_sql
{
  my ($self) = @_;
  my $sql = "(salt IS NULL OR salt = '')";
  if ($self->{ids}) {
    my @ids = grep { /^\d+$/ } @{ $self->{ids} };
    $sql .= @ids ? ' AND user_id IN (' . join(',', @ids) . ')' : ' AND 0';
  }
  return $sql;
}

sub remaining
{
  my ($self) = @_;
  my ($n) = $self->_dbh->selectrow_array('SELECT COUNT(*) FROM user WHERE ' . $self->_scope_sql);
  return $n || 0;
}

sub _emit
{
  my ($self, $fields) = @_;
  my $fh = $self->{out};
  print {$fh} 'MIGRATION ' . JSON->new->canonical->encode($fields) . "\n";
  return;
}

# Migrate one row ({user_id, passwd, salt} as read). Returns 'plaintext' or 'none' (what was
# migrated), 'changed' (the row moved on since it was read), or 'skipped' (not pre-salt).
# Dies if the new value doesn't verify; the caller rolls the batch back.
sub migrate_row
{
  my ($self, $row) = @_;
  my $app = $self->{app};

  my $kind = $app->password_kind($row);
  my ($new_passwd, $new_salt) = $app->migrated_legacy_password($row);
  return 'skipped' unless defined $new_passwd;

  # Guest User never authenticates by password.
  if ($self->{guest_user_id} && $row->{user_id} == $self->{guest_user_id}) {
    ($new_passwd, $kind) = ($app->NO_PASSWORD, 'guest');
  }

  # The new value must accept exactly what the old one did.
  my $probe = { passwd => $new_passwd, salt => $new_salt };
  if ($kind eq 'plaintext') {
    die "verification failed for user $row->{user_id}\n" unless $app->check_password($probe, $row->{passwd});
  } elsif ($kind eq 'guest') {
    die "verification failed for user $row->{user_id}\n"
      if $app->password_kind($probe) ne 'none' || $app->check_password($probe, $row->{passwd} // 'x');
  } else {
    die "verification failed for user $row->{user_id}\n" unless $app->password_kind($probe) eq 'none';
  }
  return $kind unless $self->{apply};

  my $updated = $self->_dbh->do(
    "UPDATE user SET passwd = ?, salt = ? WHERE user_id = ? AND (salt IS NULL OR salt = '') AND passwd <=> ?",
    undef, $new_passwd, $new_salt, $row->{user_id}, $row->{passwd});
  return 'changed' unless $updated && $updated == 1;
  $self->_emit({ status => 'special', user_id => $row->{user_id}, account => 'Guest User', now => 'no password' })
    if $kind eq 'guest';

  # Same statement as NodeCache::incrementGlobalVersion (node version only)
  $self->_dbh->do(
    'INSERT INTO version (version_id, version) VALUES (?, 1) ON DUPLICATE KEY UPDATE version = version + 1',
    undef, $row->{user_id});
  return $kind;
}

sub run
{
  my ($self) = @_;
  my $dbh = $self->_dbh;
  my $mode = $self->{apply} ? 'apply' : 'dry-run';
  my $started = Time::HiRes::time();
  my $total = $self->remaining;
  my %count = (scanned => 0, plaintext => 0, none => 0, guest => 0, changed => 0, skipped => 0);
  my ($last_id, $batch) = (0, 0);

  $self->_emit({ status => 'start', mode => $mode, to_migrate => $total,
    batch_size => $self->{batch_size}, limit => $self->{limit} });

  my $select = $dbh->prepare('SELECT user_id, passwd, salt FROM user WHERE ' . $self->_scope_sql
    . ' AND user_id > ? ORDER BY user_id LIMIT ?');

  while (1) {
    my $size = $self->{batch_size};
    if ($self->{limit}) {
      my $left = $self->{limit} - $count{scanned};
      last if $left <= 0;
      $size = $left if $left < $size;
    }
    $select->execute($last_id, $size);
    my $rows = $select->fetchall_arrayref({});
    last unless @$rows;
    $batch++;

    my %this = (plaintext => 0, none => 0, guest => 0, changed => 0, skipped => 0);
    my $ok = eval {
      $dbh->begin_work if $self->{apply};
      $this{ $self->migrate_row($_) }++ for @$rows;
      $dbh->commit if $self->{apply};
      1;
    };
    unless ($ok) {
      my $error = $@ || 'unknown error';
      chomp $error;
      my $rolled_back = $self->{apply} ? ( eval { $dbh->rollback; 1 } ? 1 : 0 ) : undef;
      $self->_emit({ status => 'error', mode => $mode, batch => $batch, error => $error,
        after_user_id => $last_id, rolled_back => $rolled_back, %count });
      return { ok => 0, error => $error, %count };
    }

    $count{scanned} += @$rows;
    $count{$_} += $this{$_} for keys %this;
    $last_id = $rows->[-1]{user_id};

    my $elapsed = Time::HiRes::time() - $started;
    my $rate = $elapsed > 0 ? $count{scanned} / $elapsed : 0;
    my $left = $total - $count{scanned};
    $left = 0 if $left < 0;
    $self->_emit({ status => 'progress', mode => $mode, batch => $batch, last_user_id => $last_id,
      %count, elapsed_s => sprintf('%.1f', $elapsed), rows_per_s => sprintf('%.1f', $rate),
      eta_s => $rate > 0 ? int($left / $rate) : undef });

    Time::HiRes::sleep($self->{pause}) if $self->{pause} > 0;
  }

  my $remaining = $self->remaining;
  my $elapsed = Time::HiRes::time() - $started;
  $self->_emit({ status => 'done', mode => $mode, %count, remaining => $remaining,
    elapsed_s => sprintf('%.1f', $elapsed) });
  return { ok => 1, remaining => $remaining, %count };
}

1;

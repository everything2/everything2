#!/usr/bin/perl
#
# tomb_strip_credentials.pl -- ONE-OFF cleanup (#4716). Removes credentials from the tomb copies
# of deleted accounts.
#
# tombstoneNode no longer stores an account's credentials (NodeBase %TOMB_NEVER_STORES), and
# resurrecting an account gives it no usable password until it is reset. Copies written before
# that still carry them; this job takes them out. Everything else in each copy stays, including
# the email address a reset link goes to.
#
# Each copy is read, the credential fields removed, and the result written back only after it
# reads back as exactly the original minus those fields. A copy that can't be read is reported
# and left alone.
#
# Runs via the maintenance-job facility (cron/run_s3_job.pl; see docs/maintenance-jobs.md):
#   bash tools/aws/run-fargate-job.sh tools/jobs/tomb_strip_credentials.pl              # dry run
#   bash tools/aws/run-fargate-job.sh tools/jobs/tomb_strip_credentials.pl E2_APPLY=1   # strip
#
# Env:
#   E2_APPLY=1        write the stripped copies (otherwise a dry run that changes nothing)
#   E2_TOMB_ONLY=a,b  limit to these node_ids
#
# Only field names and counts are printed, never stored values. Running it again finds nothing.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Everything;
use Everything::Serialization qw(safe_deserialize_dumper);
use Data::Dumper;

initEverything 'everything';

my $apply = $ENV{E2_APPLY} ? 1 : 0;
my @only  = grep { /\A\d+\z/ } split /\s*,\s*/, ($ENV{E2_TOMB_ONLY} // '');
die "[tomb_strip_credentials] E2_TOMB_ONLY must be a comma-separated list of node ids\n"
  if length($ENV{E2_TOMB_ONLY} // '') && !@only;

my $dbh = $DB->getDatabaseHandle();
local $dbh->{RaiseError} = 1;
local $dbh->{PrintError} = 0;

my $user_type = $DB->getType('user') or die "[tomb_strip_credentials] no user nodetype\n";
my @fields    = $DB->tomb_never_stores($user_type);
die "[tomb_strip_credentials] no credential fields defined for user\n" unless @fields;

my $limit = @only ? ' AND node_id IN (' . join(',', map { int } @only) . ')' : '';
my $rows  = $dbh->selectall_arrayref(
  'SELECT node_id, data FROM tomb WHERE type_nodetype = ?' . $limit . ' ORDER BY node_id',
  { Slice => {} }, int($user_type->{node_id}));

sub canonical { local $Data::Dumper::Sortkeys = 1; local $Data::Dumper::Indent = 1; return Dumper($_[0]) }

my (%count, @work, @unreadable);
for my $r (@$rows) {
  my $copy = safe_deserialize_dumper('my ' . ($r->{data} // ''));
  unless (ref $copy eq 'HASH') { push @unreadable, $r->{node_id}; next }

  my @present = grep { exists $copy->{$_} } @fields;
  next unless @present;
  $count{$_}++ for @present;

  my %stripped = %$copy;
  delete @stripped{@present};
  my $text = Data::Dumper->Dump([\%stripped]);

  # Write it back only if it reads back as exactly the original minus those fields.
  my $check = safe_deserialize_dumper('my ' . $text);
  unless (ref $check eq 'HASH' && canonical($check) eq canonical(\%stripped)) {
    push @unreadable, $r->{node_id};
    next;
  }
  push @work, { node_id => $r->{node_id}, old => $r->{data}, new => $text, fields => \@present };
}

printf "[tomb_strip_credentials] %d deleted-account copies; %d deleted-account copies with credentials%s\n",
  scalar(@$rows), scalar(@work), $apply ? '' : ' (dry run: nothing changed)';
printf "[tomb_strip_credentials]   %s: %d\n", $_, $count{$_} || 0 for @fields;
printf "[tomb_strip_credentials] %d could not be read and are left alone: %s\n",
  scalar(@unreadable), join(', ', @unreadable) if @unreadable;

exit 0 unless $apply;

my $done = 0;
for my $w (@work) {
  # Only if the copy hasn't changed since it was read.
  my $updated = $dbh->do('UPDATE tomb SET data = ? WHERE node_id = ? AND data = ?',
    undef, $w->{new}, $w->{node_id}, $w->{old});
  if ($updated == 1) {
    $done++;
  } else {
    print "[tomb_strip_credentials] node $w->{node_id}: changed since it was read, left alone\n";
  }
}

printf "[tomb_strip_credentials] stripped %d of %d\n", $done, scalar(@work);
exit($done == @work ? 0 : 1);

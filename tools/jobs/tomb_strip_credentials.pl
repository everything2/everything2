#!/usr/bin/perl
#
# tomb_strip_credentials.pl -- ONE-OFF cleanup (#4716). Removes credentials from the tomb copies
# of deleted accounts.
#
# tombstoneNode no longer stores an account's credentials (NodeBase %TOMB_NEVER_STORES), and
# resurrecting an account gives it no usable password until it is reset. Copies written before
# that still carry them; this job takes them out, along with the _ORIGINAL_VALUES snapshot some
# old copies hold (it carries its own copy of the credentials, #4726). Everything else in each
# copy stays, including the email address a reset link goes to.
#
# Each copy is read, those keys removed, and the result written back only after it reads back as
# exactly the original minus them. A copy that can't be read, or that would still hold a
# credential field anywhere in its nested data, is reported and left alone.
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
use Scalar::Util qw(reftype refaddr);

initEverything 'everything';

my $apply = $ENV{E2_APPLY} ? 1 : 0;
my @only  = grep { /\A\d+\z/ } split /\s*,\s*/, ($ENV{E2_TOMB_ONLY} // '');
die "[tomb_strip_credentials] E2_TOMB_ONLY must be a comma-separated list of node ids\n"
  if length($ENV{E2_TOMB_ONLY} // '') && !@only;

my $dbh = $DB->getDatabaseHandle();
local $dbh->{RaiseError} = 1;
local $dbh->{PrintError} = 0;

my $user_type = $DB->getType('user') or die "[tomb_strip_credentials] no user nodetype\n";
# The keys an account's tomb copy leaves out: its credentials and the old _ORIGINAL_VALUES snapshot.
my @fields     = $DB->tomb_never_stores($user_type);
my %credential = map { $_ => 1 } @{ $Everything::NodeBase::TOMB_NEVER_STORES{user} || [] };
die "[tomb_strip_credentials] no credential fields defined for user\n" unless %credential;

my $limit = @only ? ' AND node_id IN (' . join(',', map { int } @only) . ')' : '';
my $rows  = $dbh->selectall_arrayref(
  'SELECT node_id, data FROM tomb WHERE type_nodetype = ?' . $limit . ' ORDER BY node_id',
  { Slice => {} }, int($user_type->{node_id}));

# A copy's text can come back with its strings flagged as characters or not (older copies hold
# them literally, newer ones as \x{} escapes, which read back unflagged). Flag every non-ASCII
# string as characters so Data::Dumper writes it as an escape (the text stored is plain ASCII)
# and comparisons see the characters rather than Perl's internal encoding.
sub as_characters {
  my ($seen) = $_[1] || {};
  my $type = reftype($_[0]) // '';
  if ($type eq 'HASH')  { return if $seen->{refaddr $_[0]}++; as_characters($_, $seen) for values %{ $_[0] } }
  elsif ($type eq 'ARRAY') { return if $seen->{refaddr $_[0]}++; as_characters($_, $seen) for @{ $_[0] } }
  elsif ($type eq 'SCALAR' || $type eq 'REF') { return if $seen->{refaddr $_[0]}++; as_characters(${ $_[0] }, $seen) }
  elsif (!$type && defined $_[0] && $_[0] =~ /[^\x00-\x7f]/) { utf8::upgrade($_[0]) }
  return;
}

# True if a credential field appears anywhere in the copy, nested data included.
sub holds_credentials {
  my ($v, $seen) = @_;
  $seen ||= {};
  my $type = reftype($v) // '';
  return 0 unless $type =~ /\A(?:HASH|ARRAY|SCALAR|REF)\z/;
  return 0 if $seen->{refaddr $v}++;
  if ($type eq 'HASH') {
    for my $k (keys %$v) { return 1 if $credential{$k} || holds_credentials($v->{$k}, $seen) }
    return 0;
  }
  if ($type eq 'ARRAY') {
    for my $e (@$v) { return 1 if holds_credentials($e, $seen) }
    return 0;
  }
  return holds_credentials(${$v}, $seen);
}

sub canonical {
  as_characters($_[0]);
  local $Data::Dumper::Sortkeys = 1; local $Data::Dumper::Indent = 1;
  return Dumper($_[0]);
}

my (%count, @work, @unreadable, @nested);
for my $r (@$rows) {
  my $copy = safe_deserialize_dumper('my ' . ($r->{data} // ''));
  unless (ref $copy eq 'HASH') { push @unreadable, $r->{node_id}; next }

  my @present = grep { exists $copy->{$_} } @fields;
  unless (@present) {
    push @nested, $r->{node_id} if holds_credentials($copy);
    next;
  }

  my %stripped = %$copy;
  delete @stripped{@present};
  # Never write a copy that would still hold a credential field somewhere.
  if (holds_credentials(\%stripped)) {
    push @nested, $r->{node_id};
    next;
  }
  as_characters(\%stripped);
  my $text = Data::Dumper->Dump([\%stripped]);

  # Write it back only if it is plain ASCII and reads back as exactly the original minus those fields.
  my $check = $text =~ /[^\x00-\x7f]/ ? undef : safe_deserialize_dumper('my ' . $text);
  unless (ref $check eq 'HASH' && canonical($check) eq canonical(\%stripped)) {
    push @unreadable, $r->{node_id};
    next;
  }
  $count{$_}++ for @present;
  push @work, { node_id => $r->{node_id}, old => $r->{data}, new => $text, fields => \@present };
}

printf "[tomb_strip_credentials] %d deleted-account copies; %d deleted-account copies with credentials%s\n",
  scalar(@$rows), scalar(@work), $apply ? '' : ' (dry run: nothing changed)';
printf "[tomb_strip_credentials]   %s: %d\n", $_, $count{$_} || 0 for @fields;
printf "[tomb_strip_credentials] %d could not be read and are left alone: %s\n",
  scalar(@unreadable), join(', ', @unreadable) if @unreadable;
printf "[tomb_strip_credentials] %d still hold credentials in nested data and are left alone: %s\n",
  scalar(@nested), join(', ', @nested) if @nested;

exit 0 unless $apply;

my $done = 0;
for my $w (@work) {
  # Only if the copy hasn't changed since it was read.
  # A failed write is reported and the run goes on. DBI's message quotes stored data, so it isn't printed.
  my $updated = eval { $dbh->do('UPDATE tomb SET data = ? WHERE node_id = ? AND data = ?',
    undef, $w->{new}, $w->{node_id}, $w->{old}) };
  if (!defined $updated) {
    print "[tomb_strip_credentials] node $w->{node_id}: the write failed, left alone\n";
  } elsif ($updated == 1) {
    $done++;
  } else {
    print "[tomb_strip_credentials] node $w->{node_id}: changed since it was read, left alone\n";
  }
}

printf "[tomb_strip_credentials] stripped %d of %d\n", $done, scalar(@work);
exit($done == @work ? 0 : 1);

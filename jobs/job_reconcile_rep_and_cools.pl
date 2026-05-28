#!/usr/bin/env perl
#
# job_reconcile_rep_and_cools.pl
#
# One-time reconciliation of cached writeup counters against the
# source-of-truth tables:
#
#   node.reputation  = SUM(vote.weight)        WHERE vote_id        = writeup_id
#   writeup.cooled   = COUNT(coolwriteups.*)   WHERE coolwriteups_id = writeup_id
#
# Resolves the rep/cool drift cluster (#4137, #4011, #4072, #4010, #27).
# Drift accumulated from multiple historical sources:
#   * delta-math write paths that missed updates (cools/votes don't decrement)
#   * the angelToDraft restore path preserving cached rep while clearing vote
#     rows (#27)
#   * concurrent updates without locking
#
# Going forward, all write paths SUM-rebuild on every vote/cool action so
# drift can't reaccumulate. This job is the catch-up for historical state.
#
# Cache coherency: each fixed writeup goes through Everything::NodeBase::
# updateNode (not raw sqlUpdate), which ticks incrementGlobalVersion so
# every Apache webhead invalidates its NodeCache copy on next access.
# Without that, stale rep keeps serving from per-webhead memory until TTL.
#
# Usage (inside the heavyjob Fargate container or dev shell):
#
#   perl jobs/job_reconcile_rep_and_cools.pl --dry-run   # report, no writes
#   perl jobs/job_reconcile_rep_and_cools.pl             # actually write
#
# Idempotent: rerunning after a successful pass should fix zero writeups.

use strict;
use warnings;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Getopt::Long;

my $dry_run    = 0;
my $batch_size = 500;
my $verbose    = 0;
GetOptions(
    'dry-run'   => \$dry_run,
    'batch=i'   => \$batch_size,
    'verbose'   => \$verbose,
) or die "Usage: $0 [--dry-run] [--batch=N] [--verbose]\n";

initEverything 'everything';

my $DB           = $Everything::DB;
my $APP          = $Everything::APP;
my $writeup_type = $DB->getType('writeup')
    or die "Could not find 'writeup' nodetype\n";

print "=== Writeup rep/cool reconciliation ===\n";
print "  mode:  ", ($dry_run ? 'DRY RUN (no writes)' : 'WRITE'), "\n";
print "  batch: $batch_size writeups per fetch\n";

my $start_time     = time();
my $total_examined = 0;
my $rep_off        = 0;
my $cool_off       = 0;
my $updated        = 0;
my $offset         = 0;

while (1) {
    # Stable order by node_id so OFFSET doesn't shift under us if anything
    # else inserts writeups during the run. New writeups appended after
    # the current cursor won't be examined — that's fine; their write
    # paths SUM-rebuild themselves.
    my $rows = $DB->{dbh}->selectall_arrayref(
        q{SELECT n.node_id, n.reputation, w.cooled
            FROM node n
            JOIN writeup w ON w.writeup_id = n.node_id
           WHERE n.type_nodetype = ?
           ORDER BY n.node_id
           LIMIT ? OFFSET ?},
        { Slice => {} },
        $writeup_type->{node_id}, $batch_size, $offset
    );

    last unless @$rows;

    for my $row (@$rows) {
        $total_examined++;
        my $writeup_id  = $row->{node_id};
        my $cached_rep  = $row->{reputation} // 0;
        my $cached_cool = $row->{cooled}     // 0;

        # Sources of truth.
        my $true_rep =
            $DB->sqlSelect('COALESCE(SUM(weight),0)', 'vote',
                           "vote_id=$writeup_id") // 0;
        my $true_cool =
            $DB->sqlSelect('COUNT(*)', 'coolwriteups',
                           "coolwriteups_id=$writeup_id") // 0;

        my $rep_mismatch  = ($cached_rep  != $true_rep);
        my $cool_mismatch = ($cached_cool != $true_cool);
        next unless $rep_mismatch || $cool_mismatch;

        $rep_off++  if $rep_mismatch;
        $cool_off++ if $cool_mismatch;

        if ($verbose) {
            printf "  writeup %d: rep %d->%d  cool %d->%d\n",
                $writeup_id, $cached_rep, $true_rep,
                             $cached_cool, $true_cool;
        }

        next if $dry_run;

        # Load the node (forces a fresh read), set the corrected fields,
        # and call updateNode so other webheads invalidate their cache via
        # NodeCache::incrementGlobalVersion.
        my $NODE = $DB->getNodeById($writeup_id, 'force');
        unless ($NODE) {
            warn "  writeup $writeup_id: could not load node, skipping\n";
            next;
        }
        $NODE->{reputation} = $true_rep;
        $NODE->{cooled}     = $true_cool;
        my $ok = $DB->updateNode($NODE, -1);  # -1 = superuser
        if ($ok) {
            $updated++;
        } else {
            warn "  writeup $writeup_id: updateNode returned false\n";
        }
    }

    $offset += $batch_size;

    # Periodic progress.
    if ($offset % ($batch_size * 10) == 0) {
        my $elapsed = time() - $start_time;
        my $rate    = $elapsed > 0 ? int($total_examined / $elapsed) : 0;
        print "  progress: examined=$total_examined "
            . "rep_off=$rep_off cool_off=$cool_off "
            . "updated=$updated  elapsed=${elapsed}s rate=${rate}/s\n";
    }
}

my $elapsed = time() - $start_time;
print "\n=== Summary ===\n";
print "  total writeups examined: $total_examined\n";
print "  rep mismatches found:    $rep_off\n";
print "  cool mismatches found:   $cool_off\n";
print "  writeups updated:        $updated\n",
      ($dry_run ? "  (dry run — nothing actually written)\n" : "");
print "  elapsed: ${elapsed}s\n";

exit 0;

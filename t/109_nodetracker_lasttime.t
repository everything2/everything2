#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 109_nodetracker_lasttime.t
#
# Guards the MySQL 8.4 zero-date fix on nodetracker.lasttime (#4081):
#   lasttime datetime NULL DEFAULT NULL
#
# nodetracker (the Node Tracker stats page) inserts a row WITHOUT lasttime
# (Page/node_tracker.pm:53) and only sets it on "update" (:254, NOW()). So the
# default is exercised on insert — the vote.revotetime pattern — and 864 prod
# rows are trackers created but never updated.
#
# The reader (node_tracker.pm:74) does `sqlSelect("lasttime",...) || 'never'`,
# which *expects* a falsy value to mean "never". A zero-date came back from
# DBD::mysql as the truthy STRING '0000-00-00 00:00:00' (verified), so it
# displayed the zero-date instead of "never" — a latent bug. NULL is falsy,
# so it both makes the table 8.4-legal AND fixes that display bug.
#
# Schema-only fix; no app code changed.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/
                || $w =~ /overwriting a locally defined function/;
};

initEverything('development-docker');
ok($DB, 'Database connection established');

my $tu = 99999;   # synthetic tracker_user; nodetracker has no FKs
$DB->sqlDelete('nodetracker', "tracker_user=$tu");   # clean any prior run

#############################################################################
# 1. Insert omitting lasttime (mirrors node_tracker.pm:53) → NULL, not a
#    zero-date. And the reader's `|| 'never'` idiom resolves to "never".
#############################################################################
{
    $DB->sqlInsert('nodetracker', { tracker_user => $tu, tracker_data => 'data' });

    my $lasttime = $DB->sqlSelect('lasttime', 'nodetracker', "tracker_user=$tu limit 1");
    ok(!defined $lasttime,
        'fresh tracker: lasttime is NULL, not a zero-date (#4081)');

    # Verbatim mirror of node_tracker.pm:74
    my $display = $lasttime || 'never';
    is($display, 'never',
        'the `|| "never"` reader shows "never" for a NULL lasttime (display bug fixed)');
}

#############################################################################
# 2. "update" sets a real lasttime (mirrors node_tracker.pm:254).
#############################################################################
{
    $DB->sqlUpdate('nodetracker',
        { tracker_data => 'snapshot', -lasttime => 'now()', -hits => 'hits + 1' },
        "tracker_user=$tu limit 1");

    my $lasttime = $DB->sqlSelect('lasttime', 'nodetracker', "tracker_user=$tu limit 1");
    ok(defined $lasttime && $lasttime !~ /^0000-00-00/,
        'after update: lasttime is a real timestamp');
}

# Cleanup
$DB->sqlDelete('nodetracker', "tracker_user=$tu");

done_testing();

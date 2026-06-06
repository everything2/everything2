#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 113_podcast_pubdate.t
#
# Guards the MySQL 8.4 zero-date fix on podcast.pubdate (#4086):
#   pubdate datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# podcast is a live-but-dormant feature (RSS feed + React controller + API;
# newest episode 2013, 0 zero-dates). pubdate is user-provided on the update
# API; the RSS feed already falls back to time() when it's empty. So
# CURRENT_TIMESTAMP is the sensible 8.4-legal default. Schema-only fix; no code
# change, no backfill.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');
ok($DB, 'Database connection established');

my $pid = 990000888;   # synthetic podcast_id, no FKs
$DB->sqlDelete('podcast', "podcast_id=$pid");

#############################################################################
# Bare insert (no pubdate) must default to a real CURRENT_TIMESTAMP, not a
# zero-date — the direct test of the #4086 column-default change.
#############################################################################
{
    $DB->sqlInsert('podcast', { podcast_id => $pid, description => 'test' });

    my $pd = $DB->sqlSelect('pubdate', 'podcast', "podcast_id=$pid");
    ok(defined $pd && $pd !~ /^0000-00-00/,
        'pubdate defaults to a real CURRENT_TIMESTAMP, not a zero-date (#4086)');
    like($pd, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/, 'pubdate is a well-formed datetime');
}

# Cleanup
$DB->sqlDelete('podcast', "podcast_id=$pid");

done_testing();

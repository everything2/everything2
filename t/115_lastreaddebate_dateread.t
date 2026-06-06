#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 115_lastreaddebate_dateread.t
#
# Guards the MySQL 8.4 zero-date fix on lastreaddebate.dateread (#4083):
#   dateread datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# lastreaddebate tracks when a user last read a discussion. Every insert site
# (Controller/debatecomment.pm:58, Page/mark_all_discussions_as_read.pm:109)
# already sets -dateread => "NOW()", so the column default is never exercised in
# the live paths -- this is a trivial ALTER, not a code breaker. But the old
# '0000-00-00' default is still illegal under 8.4 strict mode, so we move it to
# CURRENT_TIMESTAMP (correct for an always-set "last read" event timestamp).
# Schema-only fix; no backfill (prod had 0 zero-dates across 4211 rows).
#
# This test asserts the schema default produces a real timestamp for an insert
# that omits dateread -- proving the column itself is 8.4-legal regardless of
# caller behavior.
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

# lastreaddebate has no PK; key on a synthetic user_id/debateroot_id pair.
my $uid = 990000555;
my $did = 990000556;
$DB->sqlDelete('lastreaddebate', "user_id=$uid AND debateroot_id=$did");

#############################################################################
# Bare insert omitting dateread must default to a real CURRENT_TIMESTAMP, not a
# zero-date -- the direct test of the #4083 column-default change.
#############################################################################
{
    $DB->sqlInsert('lastreaddebate', { user_id => $uid, debateroot_id => $did });

    my $dr = $DB->sqlSelect('dateread', 'lastreaddebate',
        "user_id=$uid AND debateroot_id=$did");
    ok(defined $dr && $dr !~ /^0000-00-00/,
        'dateread defaults to a real CURRENT_TIMESTAMP, not a zero-date (#4083)');
    like($dr, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/, 'dateread is a well-formed datetime');
}

# Cleanup
$DB->sqlDelete('lastreaddebate', "user_id=$uid AND debateroot_id=$did");

done_testing();

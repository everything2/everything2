#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 108_pollvote_votetime.t
#
# Guards the MySQL 8.4 zero-date fix on pollvote.votetime (#4080):
#   votetime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# pollvote has a single date column, votetime, and both insert paths set it
# explicitly (API/poll.pm convertEpochToDate(time()), Delegation/opcode.pm
# 'NOW()') — so the default is never exercised in normal operation and there
# are 0 zero-date rows. This test asserts the schema default itself produces a
# real timestamp (not a zero-date) for a bare insert, which is what makes the
# table 8.4-legal. Schema-only fix; no app code changed.
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

my $voter = $DB->getNode('normaluser1', 'user');
ok($voter, 'Got voter user');

# pollvote PK is (pollvote_id, voter_user); no FKs, so a synthetic high id is
# safe and self-contained. choice has a default; votetime is what we test.
my $test_id = 990000001;
$DB->sqlDelete('pollvote', "pollvote_id=$test_id");   # clean any prior run

#############################################################################
# Bare insert (no votetime) must default to a real CURRENT_TIMESTAMP, not a
# zero-date — the direct test of the #4080 column-default change.
#############################################################################
{
    $DB->sqlInsert('pollvote',
        { pollvote_id => $test_id, voter_user => $voter->{node_id}, choice => 1 });

    my $row = $DB->sqlSelectHashref('*', 'pollvote',
        "pollvote_id=$test_id AND voter_user=$voter->{node_id}");

    ok($row, 'bare pollvote insert succeeded');
    ok(defined $row->{votetime} && $row->{votetime} !~ /^0000-00-00/,
        'votetime defaults to a real timestamp (CURRENT_TIMESTAMP), not a zero-date (#4080)');
    like($row->{votetime}, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/,
        'votetime is a well-formed datetime');
}

# Cleanup
$DB->sqlDelete('pollvote', "pollvote_id=$test_id");

done_testing();

#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 110_weblog_linkedtime.t
#
# Guards the MySQL 8.4 zero-date fix on weblog.linkedtime (#4079):
#   linkedtime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# weblog backs the curated-feed mechanism (usergroup picks, news archives).
# Both insert paths set linkedtime explicitly — API/weblog.pm
# (-linkedtime => 'NOW()') and Delegation/opcode.pm (-linkedtime => 'now()') —
# so the default is never exercised and there are 0 zero-date rows. This is the
# clean event-timestamp case (like vote.votetime / pollvote.votetime): the
# default just needs to be 8.4-legal. Schema-only fix; no app code changed.
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

# weblog PK is (weblog_id, to_node); no FKs, so synthetic high ids are safe.
my ($wid, $tonode) = (990000001, 990000002);
$DB->sqlDelete('weblog', "weblog_id=$wid AND to_node=$tonode");   # clean prior run

#############################################################################
# Bare insert (no linkedtime) must default to a real CURRENT_TIMESTAMP, not a
# zero-date — the direct test of the #4079 column-default change.
#############################################################################
{
    $DB->sqlInsert('weblog',
        { weblog_id => $wid, to_node => $tonode, linkedby_user => 1 });

    my $row = $DB->sqlSelectHashref('*', 'weblog',
        "weblog_id=$wid AND to_node=$tonode");

    ok($row, 'bare weblog insert succeeded');
    ok(defined $row->{linkedtime} && $row->{linkedtime} !~ /^0000-00-00/,
        'linkedtime defaults to a real timestamp (CURRENT_TIMESTAMP), not a zero-date (#4079)');
    like($row->{linkedtime}, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/,
        'linkedtime is a well-formed datetime');
}

# Cleanup
$DB->sqlDelete('weblog', "weblog_id=$wid AND to_node=$tonode");

done_testing();

#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 112_writeup_publishtime.t
#
# Guards the MySQL 8.4 zero-date fix on writeup.publishtime (#4076):
#   publishtime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# publishtime is an always-set event timestamp: the modern publish path
# (API/drafts.pm) sets -publishtime => 'NOW()'. But the legacy writeup-submit
# opcode (Delegation/opcode.pm:103) OMITS it, relying on the default — so the
# default IS exercised, and under the old '0000-00-00' it would fail 8.4 strict
# mode. CURRENT_TIMESTAMP (published-now) is both correct and 8.4-legal.
#
# This test asserts the schema default produces a real timestamp for an insert
# that omits publishtime (the opcode-path shape). Schema-only fix.
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

# writeup PK is writeup_id; synthetic high id, no FKs to worry about.
my $wid = 990000777;
$DB->sqlDelete('writeup', "writeup_id=$wid");   # clean any prior run

#############################################################################
# Bare insert omitting publishtime (the opcode.pm:103 shape) must default to a
# real CURRENT_TIMESTAMP, not a zero-date — the direct test of the #4076 fix.
#############################################################################
{
    $DB->sqlInsert('writeup', { writeup_id => $wid, parent_e2node => 0 });

    my $pt = $DB->sqlSelect('publishtime', 'writeup', "writeup_id=$wid");
    ok(defined $pt && $pt !~ /^0000-00-00/,
        'publishtime defaults to a real CURRENT_TIMESTAMP, not a zero-date (#4076)');
    like($pt, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/,
        'publishtime is a well-formed datetime');
}

# Cleanup
$DB->sqlDelete('writeup', "writeup_id=$wid");

done_testing();

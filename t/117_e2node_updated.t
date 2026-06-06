#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 117_e2node_updated.t
#
# Guards the MySQL 8.4 zero-date fix on e2node.updated (#4077):
#   updated datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# e2node backs the `e2node` nodetype, so NodeBase::insertNode creates the row
# with ONLY e2node_id (NodeBase.pm:1193) on every node creation -- the column
# default IS exercised, and the old '0000-00-00' default fails 8.4 strict mode.
# `updated` is a hand-managed last-modified stamp (Delegation/htmlcode.pm:902
# sets it to now() when a writeup is published; no ON UPDATE clause). It feeds
# schema.org dateModified (HTMLShell.pm:297). CURRENT_TIMESTAMP is the right
# 8.4-legal default (a brand-new node's "last updated" is its creation moment).
#
# Existing zero-dates (176,487 in prod, ~40%) are backfilled to MATCH the live
# logic, in three tiers: nodes that have writeups (102,904) -> the last writeup's
# publishtime (exactly what htmlcode.pm:902 would have stamped); nodes with no
# writeups (73,583 nodeshells/firmlink targets) -> the node's own createtime; the
# ~15 with neither a writeup nor a real createtime -> the '1998-03-23' sentinel.
# This keeps schema.org dateModified truthful per-page instead of a uniform date.
#
# This test asserts the schema default produces a real timestamp for an insert
# that omits `updated` (the insertNode shape).
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

my $eid = 990000444;   # synthetic e2node_id, no FKs
$DB->sqlDelete('e2node', "e2node_id=$eid");

#############################################################################
# Bare insert (the insertNode:1193 shape -- only the *_id) must default to a
# real CURRENT_TIMESTAMP, not a zero-date -- the direct test of the #4077 fix.
#############################################################################
{
    $DB->sqlInsert('e2node', { e2node_id => $eid });

    my $up = $DB->sqlSelect('updated', 'e2node', "e2node_id=$eid");
    ok(defined $up && $up !~ /^0000-00-00/,
        'updated defaults to a real CURRENT_TIMESTAMP, not a zero-date (#4077)');
    like($up, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/, 'updated is a well-formed datetime');
}

# Cleanup
$DB->sqlDelete('e2node', "e2node_id=$eid");

done_testing();

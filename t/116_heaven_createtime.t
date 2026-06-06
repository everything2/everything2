#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 116_heaven_createtime.t
#
# Guards the MySQL 8.4 zero-date fix on heaven.createtime (#4089):
#   createtime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# heaven is a vestigial 1999-era Everything-Engine archive (a frozen mirror of
# the node table). In the modern engine NOTHING writes to it -- node deletion
# archives via tombstoneNode -> tomb (NodeBase.pm:1241), never heaven. Prod holds
# 0 rows. The table is still read (XP reputation, resurrect, who_killed_what),
# and its full retirement is tracked separately as infra-cleanup (#4204). For
# 8.4 we just need the column default to be legal: CURRENT_TIMESTAMP, matching
# the node.createtime treatment (#4075) since heaven mirrors node. Schema-only;
# no live writer means the default is never exercised in prod, and the sentinel
# backfill for any pre-existing zero-dates is a no-op (0 rows).
#
# This test asserts the schema default produces a real timestamp for an insert
# that omits createtime -- proving the column is 8.4-legal.
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

# heaven.node_id is AUTO_INCREMENT; insert without it and read back the new id.
#############################################################################
# Bare insert omitting createtime must default to a real CURRENT_TIMESTAMP, not
# a zero-date -- the direct test of the #4089 column-default change.
#############################################################################
{
    my $marker = "zd_test_4089 only";
    $DB->sqlDelete('heaven', "title=" . $DB->quote($marker));

    $DB->sqlInsert('heaven', { type_nodetype => 0, title => $marker, author_user => 0 });
    my $id = $DB->sqlSelect('LAST_INSERT_ID()');

    my $ct = $DB->sqlSelect('createtime', 'heaven', "node_id=$id");
    ok(defined $ct && $ct !~ /^0000-00-00/,
        'createtime defaults to a real CURRENT_TIMESTAMP, not a zero-date (#4089)');
    like($ct, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/, 'createtime is a well-formed datetime');

    # Cleanup
    $DB->sqlDelete('heaven', "node_id=$id");
}

done_testing();

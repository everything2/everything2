#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 118_node_createtime.t
#
# Guards the MySQL 8.4 zero-date fix on node.createtime (#4075) -- the keystone
# that gates NO_ZERO_DATE strict mode for the whole engine:
#   createtime datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# node is THE central table (1.58M rows). NodeBase::insertNode always sets
# -createtime => 'now()' (NodeBase.pm:1177), so the default is not exercised by
# normal creation -- but the old '0000-00-00' default is still illegal under 8.4,
# and 140 legacy zero-date rows had to be cleared (backfilled: old-core nodes ->
# their first writeup's publishtime; reparented/high-id + writeup-less nodes ->
# nearest-lower-id createtime; final fallback sentinel). Crucially the backfill
# matched ONLY exact '0000-00-00', preserving valid hand-edited "joke" dates such
# as the L. Frank Baum user node backdated to his 1856 birthday.
#
# This test asserts the schema default is itself 8.4-legal: a bare insert that
# omits createtime yields a real CURRENT_TIMESTAMP, never a zero-date.
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

# node.node_id is AUTO_INCREMENT; insert without createtime and read the new row.
#############################################################################
# Bare insert omitting createtime must default to a real CURRENT_TIMESTAMP, not
# a zero-date -- the direct test of the #4075 column-default change.
#############################################################################
{
    my $marker = "zd_test_4075 marker";
    $DB->sqlDelete('node', "title=" . $DB->quote($marker));

    $DB->sqlInsert('node', { type_nodetype => 1, title => $marker, author_user => 0 });
    my $id = $DB->sqlSelect('LAST_INSERT_ID()');

    my $ct = $DB->sqlSelect('createtime', 'node', "node_id=$id");
    ok(defined $ct && $ct !~ /^0000-00-00/,
        'createtime defaults to a real CURRENT_TIMESTAMP, not a zero-date (#4075)');
    like($ct, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/, 'createtime is a well-formed datetime');

    # Cleanup
    $DB->sqlDelete('node', "node_id=$id");
}

done_testing();

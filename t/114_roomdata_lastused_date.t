#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 114_roomdata_lastused_date.t
#
# Guards the MySQL 8.4 zero-date fix on roomdata.lastused_date (#4087):
#   lastused_date date NOT NULL DEFAULT (curdate())
#
# roomdata backs the `room` nodetype (nodepack/nodetype/room.xml sqltable).
# When a room node is created, NodeBase::insertNode inserts the secondary-table
# row with ONLY roomdata_id (NodeBase.pm:1193), so lastused_date relies on the
# column default on every room creation. Under the old '0000-00-00' default that
# INSERT fails 8.4 strict mode. lastused_date is genuinely live: it's stamped on
# every room entry (Controller/room.pm:40) and read by the stale-room reaper
# (Application.pm clean_old_rooms). curdate() ("used at creation") is the
# DATE-typed equivalent of CURRENT_TIMESTAMP -- it's 8.4-legal AND gives a fresh
# room a fair window before the reaper, instead of the old behavior where a
# never-entered room was instantly reapable. Schema-only fix; no backfill (prod
# had 0 zero-dates).
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

my $rid = 990000666;   # synthetic roomdata_id, no FKs
$DB->sqlDelete('roomdata', "roomdata_id=$rid");

#############################################################################
# Bare insert (the insertNode:1193 shape -- only the *_id) must default to a
# real curdate(), not a zero-date -- the direct test of the #4087 fix.
#############################################################################
{
    $DB->sqlInsert('roomdata', { roomdata_id => $rid });

    my $lud = $DB->sqlSelect('lastused_date', 'roomdata', "roomdata_id=$rid");
    ok(defined $lud && $lud !~ /^0000-00-00/,
        'lastused_date defaults to a real curdate(), not a zero-date (#4087)');
    like($lud, qr/^\d{4}-\d\d-\d\d$/, 'lastused_date is a well-formed date');
}

# Cleanup
$DB->sqlDelete('roomdata', "roomdata_id=$rid");

done_testing();

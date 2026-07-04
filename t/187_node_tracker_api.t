#!/usr/bin/perl -w
# Everything::API::node_tracker -- POST /api/node_tracker/update (#4458, Refs #4298).
#
# The node-tracker "update" snapshot-save (persist the current writing stats as the new
# baseline) used to run inside Everything::Page::node_tracker's buildReactData off the
# ?update query param. It now lives here, sharing the stats computation with the page via
# Everything::Roles::NodeTrackerStats. Tests the NoGuest gate and a real update for
# normaluser1, restoring normaluser1's nodetracker row afterward so re-runs stay stable.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::node_tracker;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::node_tracker->new();
ok($api, 'Created node_tracker API instance');
is_deeply($api->routes, {'update' => 'update_stats'}, 'routes: update -> update_stats');

#############################################################################
# Gate: guest -> refused (200 + success=0)
#############################################################################
my $r = $api->update_stats(MockRequest->new(is_guest_flag => 1));
is($r->[0], $api->HTTP_OK, 'returns 200 for guest');
is($r->[1]{success}, 0, 'guest refused');
like($r->[1]{error}, qr/logged in/i, 'guest error mentions login');

#############################################################################
# Logged-in: a real update -- returns the refreshed payload, persists a row
#############################################################################
SKIP: {
    my $target = $DB->getNode('normaluser1', 'user');
    skip 'normaluser1 not present', 5 unless $target;
    my $uid = $target->{node_id};

    # Capture the pre-existing nodetracker row (if any) for restore.
    my $existed   = $DB->sqlSelect('tracker_user', 'nodetracker', "tracker_user=$uid limit 1");
    my $orig_data = $existed ? $DB->sqlSelect('tracker_data', 'nodetracker', "tracker_user=$uid limit 1") : undef;

    $r = $api->update_stats(MockRequest->new(is_guest_flag => 0, nodedata => $target));
    is($r->[0], $api->HTTP_OK, 'returns 200');
    is($r->[1]{success}, 1, 'update succeeds');
    ok(exists $r->[1]{stats}, 'payload has stats');
    ok(ref $r->[1]{stats}{nodes} eq 'HASH' && exists $r->[1]{stats}{nodes}{current},
        'stats carry {current,diff} shape');
    ok(exists $r->[1]{last_update}, 'payload has last_update');

    # After an update the row exists and lasttime is set (not 'never').
    isnt($r->[1]{last_update}, 'never', 'last_update stamped by the save');

    # Restore: put the original baseline back, or drop the row we created.
    if ($existed) {
        $DB->sqlUpdate('nodetracker', {tracker_data => $orig_data}, "tracker_user=$uid limit 1");
    } else {
        $DB->sqlDelete('nodetracker', "tracker_user=$uid");
    }
}

done_testing;

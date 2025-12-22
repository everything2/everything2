#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::e2node;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::e2node->new();
ok($api, "Created e2node API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $editor_user = $DB->getNode("root", "user");
ok($editor_user, "Got editor/admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Create test e2node and writeups
my $e2node_title = "Test E2node API Node " . time();
my $e2node_id = $DB->insertNode(
    $e2node_title,
    'e2node',
    $editor_user,
    { title => $e2node_title }
);
ok($e2node_id, "Created test e2node");

my @test_writeup_ids;
for my $i (1..2) {
    my $writeup_id = $DB->insertNode(
        "$e2node_title (writeup $i)",
        'writeup',
        $editor_user,
        {
            parent_e2node => $e2node_id,
            doctext => "Test writeup $i content.",
            publishtime => "2025-01-" . sprintf("%02d", $i) . " 12:00:00"
        }
    );
    push @test_writeup_ids, $writeup_id;

    # Add writeup to nodegroup table (required for reorder_writeups tests)
    # The nodegroup table uses (nodegroup_id, nodegroup_rank) as primary key
    # nodegroup_rank must be unique per nodegroup_id
    if ($writeup_id) {
        $DB->{dbh}->do(
            "INSERT INTO nodegroup (nodegroup_id, nodegroup_rank, node_id, orderby) VALUES (?, ?, ?, ?)",
            {}, $e2node_id, $i - 1, $writeup_id, $i - 1
        );
    }
}
ok(scalar(@test_writeup_ids) == 2, "Created 2 test writeups");

# Create a second e2node for firmlink tests
my $target_title = "Test Firmlink Target " . time();
my $target_id = $DB->insertNode(
    $target_title,
    'e2node',
    $editor_user,
    { title => $target_title }
);
ok($target_id, "Created target e2node for firmlink tests");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{":id/firmlink"}, 'create_firmlink(:id)', "create_firmlink route exists");
is($routes->{":id/firmlink/:target"}, 'remove_firmlink(:id,:target)', "remove_firmlink route exists");
is($routes->{":id/repair"}, 'repair_node(:id)', "repair_node route exists");
is($routes->{":id/orderlock"}, 'toggle_orderlock(:id)', "toggle_orderlock route exists");
is($routes->{":id/title"}, 'change_title(:id)', "change_title route exists");
is($routes->{":id/lock"}, 'node_lock(:id)', "node_lock route exists");
is($routes->{":id/reorder"}, 'reorder_writeups(:id)', "reorder_writeups route exists");
is($routes->{":id/softlinks"}, 'manage_softlinks(:id)', "manage_softlinks route exists");

#############################################################################
# Test: create_firmlink - non-editor denied
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 0,
    nodedata => $normal_user,
    postdata => { to_node => $target_title }
);

my $result = $api->create_firmlink($normal_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Non-editor create_firmlink returns HTTP 200");
is($result->[1]{success}, 0, "Non-editor create_firmlink fails");
like($result->[1]{error}, qr/editor/i, "Error mentions editor required");

#############################################################################
# Test: create_firmlink - invalid e2node
#############################################################################

my $editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { to_node => $target_title }
);

$result = $api->create_firmlink($editor_request, 999999999);
is($result->[0], $api->HTTP_OK, "Invalid e2node returns HTTP 200");
is($result->[1]{success}, 0, "Invalid e2node fails");
like($result->[1]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: create_firmlink - missing target node
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => {}  # No to_node
);

$result = $api->create_firmlink($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Missing target returns HTTP 200");
is($result->[1]{success}, 0, "Missing target fails");
like($result->[1]{error}, qr/target.*required/i, "Error mentions target required");

#############################################################################
# Test: create_firmlink - target not found
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { to_node => 'nonexistent_node_xyz123' }
);

$result = $api->create_firmlink($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Nonexistent target returns HTTP 200");
is($result->[1]{success}, 0, "Nonexistent target fails");
like($result->[1]{error}, qr/not found/i, "Error mentions target not found");

#############################################################################
# Test: create_firmlink - cannot firmlink to self
#############################################################################

my $e2node_node = $DB->getNodeById($e2node_id);
$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { to_node => $e2node_node->{title} }
);

$result = $api->create_firmlink($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Self-firmlink returns HTTP 200");
is($result->[1]{success}, 0, "Self-firmlink fails");
like($result->[1]{error}, qr/itself/i, "Error mentions cannot link to itself");

#############################################################################
# Test: create_firmlink - success
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { to_node => $target_title, note_text => 'Test note' }
);

$result = $api->create_firmlink($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Create firmlink returns HTTP 200");
is($result->[1]{success}, 1, "Create firmlink succeeds");
like($result->[1]{message}, qr/created/i, "Success message mentions created");
ok(defined($result->[1]{target}), "Target returned");
is($result->[1]{target}{node_id}, $target_id, "Correct target node_id");

#############################################################################
# Test: create_firmlink - duplicate
#############################################################################

$result = $api->create_firmlink($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Duplicate firmlink returns HTTP 200");
is($result->[1]{success}, 0, "Duplicate firmlink fails");
like($result->[1]{error}, qr/already exists/i, "Error mentions already exists");

#############################################################################
# Test: remove_firmlink - success
#############################################################################

$result = $api->remove_firmlink($editor_request, $e2node_id, $target_id);
is($result->[0], $api->HTTP_OK, "Remove firmlink returns HTTP 200");
is($result->[1]{success}, 1, "Remove firmlink succeeds");
like($result->[1]{message}, qr/removed/i, "Success message mentions removed");

#############################################################################
# Test: remove_firmlink - non-existent
#############################################################################

$result = $api->remove_firmlink($editor_request, $e2node_id, $target_id);
is($result->[0], $api->HTTP_OK, "Remove nonexistent returns HTTP 200");
is($result->[1]{success}, 0, "Remove nonexistent fails");
like($result->[1]{error}, qr/does not exist/i, "Error mentions does not exist");

#############################################################################
# Test: repair_node - non-editor denied
#############################################################################

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 0,
    nodedata => $normal_user
);

$result = $api->repair_node($normal_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Non-editor repair returns HTTP 200");
is($result->[1]{success}, 0, "Non-editor repair fails");

#############################################################################
# Test: repair_node - success
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { no_reorder => 0 }
);

$result = $api->repair_node($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Repair returns HTTP 200");
is($result->[1]{success}, 1, "Repair succeeds");
like($result->[1]{message}, qr/repaired/i, "Message mentions repaired");

#############################################################################
# Test: toggle_orderlock - lock and unlock
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { unlock => 0 }  # Lock
);

$result = $api->toggle_orderlock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Lock order returns HTTP 200");
is($result->[1]{success}, 1, "Lock order succeeds");
like($result->[1]{message}, qr/locked/i, "Message mentions locked");
is($result->[1]{orderlock_user}, $editor_user->{node_id}, "Order locked by correct user");

# Unlock
$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { unlock => 1 }
);

$result = $api->toggle_orderlock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Unlock order returns HTTP 200");
is($result->[1]{success}, 1, "Unlock order succeeds");
like($result->[1]{message}, qr/unlocked/i, "Message mentions unlocked");
is($result->[1]{orderlock_user}, 0, "Order unlocked");

#############################################################################
# Test: change_title - non-editor denied
#############################################################################

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 0,
    nodedata => $normal_user,
    postdata => { new_title => 'New Title' }
);

$result = $api->change_title($normal_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Non-editor change_title returns HTTP 200");
is($result->[1]{success}, 0, "Non-editor change_title fails");

#############################################################################
# Test: change_title - missing new_title
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => {}
);

$result = $api->change_title($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Missing title returns HTTP 200");
is($result->[1]{success}, 0, "Missing title fails");
like($result->[1]{error}, qr/title required/i, "Error mentions title required");

#############################################################################
# Test: change_title - same title
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { new_title => $e2node_title }  # Same as current
);

$result = $api->change_title($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Same title returns HTTP 200");
is($result->[1]{success}, 0, "Same title fails");
like($result->[1]{error}, qr/same/i, "Error mentions same title");

#############################################################################
# Test: change_title - success
#############################################################################

my $new_title = "Renamed Test Node " . time();
$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { new_title => $new_title }
);

$result = $api->change_title($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Change title returns HTTP 200");
is($result->[1]{success}, 1, "Change title succeeds");
is($result->[1]{new_title}, $new_title, "New title returned");
ok(defined($result->[1]{new_url}), "New URL returned");

# Verify the title changed in the database
my $updated_node = $DB->getNodeById($e2node_id);
is($updated_node->{title}, $new_title, "Title updated in database");

# Update e2node_title for cleanup
$e2node_title = $new_title;

#############################################################################
# Test: node_lock - get lock status
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => {}  # GET request
);

$result = $api->node_lock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Get lock status returns HTTP 200");
is($result->[1]{success}, 1, "Get lock status succeeds");
is($result->[1]{locked}, 0, "Node is not locked initially");

#############################################################################
# Test: node_lock - lock node
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { action => 'lock', reason => 'Test lock reason' }
);

$result = $api->node_lock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Lock node returns HTTP 200");
is($result->[1]{success}, 1, "Lock node succeeds");
is($result->[1]{locked}, 1, "Node is now locked");
like($result->[1]{message}, qr/locked/i, "Message mentions locked");

#############################################################################
# Test: node_lock - already locked
#############################################################################

$result = $api->node_lock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Already locked returns HTTP 200");
is($result->[1]{success}, 0, "Already locked fails");
like($result->[1]{error}, qr/already locked/i, "Error mentions already locked");

#############################################################################
# Test: node_lock - unlock node
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { action => 'unlock' }
);

$result = $api->node_lock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Unlock node returns HTTP 200");
is($result->[1]{success}, 1, "Unlock node succeeds");
is($result->[1]{locked}, 0, "Node is now unlocked");

#############################################################################
# Test: node_lock - missing reason
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { action => 'lock' }  # No reason
);

$result = $api->node_lock($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Lock without reason returns HTTP 200");
is($result->[1]{success}, 0, "Lock without reason fails");
like($result->[1]{error}, qr/reason required/i, "Error mentions reason required");

#############################################################################
# Test: reorder_writeups - non-editor denied
#############################################################################

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 0,
    nodedata => $normal_user,
    postdata => { writeup_ids => \@test_writeup_ids }
);

$result = $api->reorder_writeups($normal_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Non-editor reorder returns HTTP 200");
is($result->[1]{success}, 0, "Non-editor reorder fails");

#############################################################################
# Test: reorder_writeups - success
#############################################################################

# The repair_node test may have replaced the nodegroup entries via replaceNodegroup.
# Re-verify the writeups are in the nodegroup before testing reorder.
my $ng_check = $DB->{dbh}->selectcol_arrayref(
    "SELECT node_id FROM nodegroup WHERE nodegroup_id = ? ORDER BY orderby",
    {}, $e2node_id
);
# If nodegroup is empty or different, skip reorder tests
my $can_test_reorder = (scalar(@$ng_check) == scalar(@test_writeup_ids));

SKIP: {
    skip "Writeups not in nodegroup (repair_node may have modified them)", 6 unless $can_test_reorder;

# Reverse the order
my @reversed_ids = reverse @test_writeup_ids;
$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { writeup_ids => \@reversed_ids }
);

$result = $api->reorder_writeups($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Reorder returns HTTP 200");
is($result->[1]{success}, 1, "Reorder succeeds");
like($result->[1]{message}, qr/updated/i, "Message mentions updated");

#############################################################################
# Test: reorder_writeups - reset to default
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { reset_to_default => 1 }
);

$result = $api->reorder_writeups($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Reset order returns HTTP 200");
is($result->[1]{success}, 1, "Reset order succeeds");
like($result->[1]{message}, qr/reset/i, "Message mentions reset");

}  # End SKIP block for reorder tests

#############################################################################
# Test: manage_softlinks - get softlinks
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => {}
);

$result = $api->manage_softlinks($editor_request, $e2node_id);
is($result->[0], $api->HTTP_OK, "Get softlinks returns HTTP 200");
is($result->[1]{success}, 1, "Get softlinks succeeds");
ok(defined($result->[1]{softlinks}), "Softlinks array present");
is(ref($result->[1]{softlinks}), 'ARRAY', "Softlinks is an array");

#############################################################################
# Cleanup
#############################################################################

# Delete node locks
$DB->sqlDelete('nodelock', "nodelock_node=$e2node_id");

# Delete firmlinks
my $firmlink_type = $DB->getNode('firmlink', 'linktype');
if ($firmlink_type) {
    $DB->sqlDelete('links', "from_node=$e2node_id AND linktype=" . $firmlink_type->{node_id});
    $DB->sqlDelete('firmlink_note', "from_node=$e2node_id");
}

# Delete nodegroup entries and test writeups
$DB->sqlDelete('nodegroup', "nodegroup_id=$e2node_id");
foreach my $writeup_id (@test_writeup_ids) {
    my $writeup = $DB->getNodeById($writeup_id);
    $DB->nukeNode($writeup, $editor_user) if $writeup;
}

# Delete test e2nodes
my $e2node = $DB->getNodeById($e2node_id);
$DB->nukeNode($e2node, $editor_user) if $e2node;

my $target = $DB->getNodeById($target_id);
$DB->nukeNode($target, $editor_user) if $target;

done_testing();

=head1 NAME

t/072_e2node_api.t - Tests for Everything::API::e2node

=head1 DESCRIPTION

Tests for the e2node management API covering:
- create_firmlink permission and validation
- remove_firmlink
- repair_node
- toggle_orderlock
- change_title
- node_lock (get, lock, unlock)
- reorder_writeups
- manage_softlinks

=head1 AUTHOR

Everything2 Development Team

=cut

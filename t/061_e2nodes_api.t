#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::e2nodes;
use Everything::API::nodes;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test E2nodes API - Create and Delete
#
# This test verifies:
# - Guest users cannot create e2nodes (401 Unauthorized)
# - Authenticated users can create e2nodes (200 OK)
# - E2nodes have correct author/createdby fields
# - Non-admin users cannot delete e2nodes (403 Forbidden)
# - Admin users can delete e2nodes (200 OK)
#
# Replaces legacy t/008_e2nodes.t that used Everything::APIClient
#############################################################################

# Get test users
my $normaluser1 = $DB->getNode("e2e_user", "user");
my $root = $DB->getNode("root", "user");

ok($normaluser1, "Got normaluser1");
ok($root, "Got root user");

# Create API instances
my $e2nodes_api = Everything::API::e2nodes->new();
my $nodes_api = Everything::API::nodes->new();

ok($e2nodes_api, "Created e2nodes API instance");
ok($nodes_api, "Created nodes API instance");

# Generate unique title
my $title = "API Test E2node " . time();

#############################################################################
# Test 1: Guest User - Cannot Create E2node (401 Unauthorized)
#############################################################################

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1,
  is_admin_flag => 0,
  postdata => { title => $title }
);

my $result = $e2nodes_api->create($guest_request);
is($result->[0], $e2nodes_api->HTTP_UNAUTHORIZED, "Guest create e2node returns 401 Unauthorized");

# Verify node doesn't exist
my $check_node = $DB->getNode($title, "e2node");
ok(!$check_node || !$check_node->{node_id}, "E2node was not created by guest");

#############################################################################
# Test 2: Authenticated User - Can Create E2node (200 OK)
#############################################################################

my $user1_request = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  postdata => { title => $title }
);

$result = $e2nodes_api->create($user1_request);
is($result->[0], $e2nodes_api->HTTP_OK, "User create e2node returns 200 OK");

my $e2node_data = $result->[1];
ok($e2node_data, "E2node data returned");
ok($e2node_data->{node_id}, "E2node has node_id");
is($e2node_data->{title}, $title, "E2node title is correct");

# Check author and createdby fields
# Note: E2nodes are owned by "Content Editors" group by convention
my $content_editors = $DB->getNode("Content Editors", "usergroup");
if ($content_editors) {
  is($e2node_data->{author}{node_id}, $content_editors->{node_id},
     "E2node author is Content Editors");
  is($e2node_data->{author}{title}, "Content Editors",
     "E2node author title is Content Editors");
}

is($e2node_data->{createdby}{node_id}, $normaluser1->{node_id},
   "E2node createdby is normaluser1");
is($e2node_data->{createdby}{title}, $normaluser1->{title},
   "E2node createdby title is normaluser1");

my $e2node_id = $e2node_data->{node_id};

#############################################################################
# Test 3: Non-Admin - Cannot Delete E2node (403 Forbidden)
#############################################################################

$result = $nodes_api->delete($user1_request, $e2node_id);
is($result->[0], 403, "Non-admin delete e2node returns 403 Forbidden");

# Verify node still exists
my $node_check = $DB->getNodeById($e2node_id);
ok($node_check && $node_check->{node_id}, "E2node still exists after failed delete");

#############################################################################
# Test 4: Guest - Cannot Delete E2node (403 Forbidden)
#############################################################################

$result = $nodes_api->delete($guest_request, $e2node_id);
is($result->[0], 403, "Guest delete e2node returns 403 Forbidden");

# Verify node still exists
$node_check = $DB->getNodeById($e2node_id);
ok($node_check && $node_check->{node_id}, "E2node still exists after guest delete attempt");

#############################################################################
# Test 5: Admin - Can Delete E2node (200 OK)
#############################################################################

my $admin_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1
);

$result = $nodes_api->delete($admin_request, $e2node_id);
is($result->[0], 200, "Admin delete e2node returns 200 OK");
is($result->[1]->{deleted}, $e2node_id, "Delete returns correct node_id");

# Verify node no longer exists
$node_check = $DB->getNodeById($e2node_id);
ok(!$node_check || !$node_check->{node_id}, "E2node no longer exists after admin delete");

#############################################################################
# Test Bulk Rename API
#############################################################################

# Create test e2nodes for bulk rename testing
my $rename_title1 = "Bulk Rename Test Node 1 " . time();
my $rename_title2 = "Bulk Rename Test Node 2 " . time();

my $rename_request1 = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  postdata => { title => $rename_title1 }
);

$result = $e2nodes_api->create($rename_request1);
is($result->[0], $e2nodes_api->HTTP_OK, "Created first test node for rename");
my $rename_node1_id = $result->[1]->{node_id};

my $rename_request2 = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  postdata => { title => $rename_title2 }
);

$result = $e2nodes_api->create($rename_request2);
is($result->[0], $e2nodes_api->HTTP_OK, "Created second test node for rename");
my $rename_node2_id = $result->[1]->{node_id};

#############################################################################
# Test 6: Non-Editor - Cannot Bulk Rename (Permission Denied)
#############################################################################

my $non_editor_request = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { renames => [{ from => $rename_title1, to => "Should Fail" }] }
);

$result = $e2nodes_api->bulk_rename($non_editor_request);
is($result->[0], $e2nodes_api->HTTP_OK, "Non-editor bulk_rename returns HTTP 200");
is($result->[1]->{success}, 0, "Non-editor bulk_rename fails");
like($result->[1]->{error}, qr/permission/i, "Error mentions permission denied");

#############################################################################
# Test 7: Editor - Successful Bulk Rename
#############################################################################

my $new_title1 = "Renamed Node 1 " . time();
my $new_title2 = "Renamed Node 2 " . time();

my $editor_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1,
  is_editor_flag => 1,
  postdata => {
    renames => [
      { from => $rename_title1, to => $new_title1 },
      { from => $rename_title2, to => $new_title2 }
    ]
  }
);

$result = $e2nodes_api->bulk_rename($editor_request);
is($result->[0], $e2nodes_api->HTTP_OK, "Editor bulk_rename returns HTTP 200");
is($result->[1]->{success}, 1, "Editor bulk_rename succeeds");
ok($result->[1]->{results}, "Results returned");
is(scalar(@{$result->[1]->{results}}), 2, "Two results returned");
is($result->[1]->{counts}->{renamed}, 2, "Two nodes renamed");

# Verify the renames in database
my $renamed_node1 = $DB->getNodeById($rename_node1_id);
my $renamed_node2 = $DB->getNodeById($rename_node2_id);
is($renamed_node1->{title}, $new_title1, "First node title updated in database");
is($renamed_node2->{title}, $new_title2, "Second node title updated in database");

#############################################################################
# Test 8: Bulk Rename - Node Not Found
#############################################################################

$editor_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1,
  is_editor_flag => 1,
  postdata => {
    renames => [{ from => "Nonexistent Node XYZ123 " . time(), to => "New Title" }]
  }
);

$result = $e2nodes_api->bulk_rename($editor_request);
is($result->[0], $e2nodes_api->HTTP_OK, "Not found bulk_rename returns HTTP 200");
is($result->[1]->{success}, 1, "Request succeeds (with not_found status)");
is($result->[1]->{counts}->{not_found}, 1, "One not_found result");
is($result->[1]->{results}->[0]->{status}, 'not_found', "Status is not_found");

#############################################################################
# Test 9: Bulk Rename - Target Already Exists
#############################################################################

# Try to rename node1 to node2's title (which should fail)
$editor_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1,
  is_editor_flag => 1,
  postdata => {
    renames => [{ from => $new_title1, to => $new_title2 }]
  }
);

$result = $e2nodes_api->bulk_rename($editor_request);
is($result->[0], $e2nodes_api->HTTP_OK, "Target exists bulk_rename returns HTTP 200");
is($result->[1]->{success}, 1, "Request succeeds (with target_exists status)");
is($result->[1]->{counts}->{target_exists}, 1, "One target_exists result");
is($result->[1]->{results}->[0]->{status}, 'target_exists', "Status is target_exists");

#############################################################################
# Test 10: Bulk Rename - Same Title (No Change)
#############################################################################

$editor_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1,
  is_editor_flag => 1,
  postdata => {
    renames => [{ from => $new_title1, to => $new_title1 }]
  }
);

$result = $e2nodes_api->bulk_rename($editor_request);
is($result->[0], $e2nodes_api->HTTP_OK, "Same title bulk_rename returns HTTP 200");
is($result->[1]->{success}, 1, "Request succeeds (with no_change status)");
is($result->[1]->{counts}->{no_change}, 1, "One no_change result");
is($result->[1]->{results}->[0]->{status}, 'no_change', "Status is no_change");

#############################################################################
# Test 11: Bulk Rename - Invalid Request Body
#############################################################################

$editor_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1,
  is_editor_flag => 1,
  postdata => {}  # Missing renames array
);

$result = $e2nodes_api->bulk_rename($editor_request);
is($result->[0], $e2nodes_api->HTTP_OK, "Invalid body bulk_rename returns HTTP 200");
is($result->[1]->{success}, 0, "Invalid body fails");
like($result->[1]->{error}, qr/invalid/i, "Error mentions invalid request");

#############################################################################
# Cleanup: Delete test e2nodes
#############################################################################

$admin_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1
);

$nodes_api->delete($admin_request, $rename_node1_id) if $rename_node1_id;
$nodes_api->delete($admin_request, $rename_node2_id) if $rename_node2_id;

done_testing();

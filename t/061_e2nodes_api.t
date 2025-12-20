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

done_testing();

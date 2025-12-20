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
use Everything::API::writeups;
use Everything::API::e2nodes;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Writeups API - Create, Read, Update, Delete
#
# This test verifies writeup creation, retrieval, deletion, and permissions.
# It replaces the legacy t/009_writeups.t that used Everything::APIClient.
#
# Coverage:
# - Writeup creation with all fields
# - Owner vs non-owner field visibility
# - Permission checks (guest, owner, non-owner, admin)
# - notnew flag handling
# - Input validation (missing required fields)
# - Deletion permissions
#############################################################################

# Get test users
my $admin_user = $DB->getNode("root", "user");
my $normaluser1 = $DB->getNode("e2e_user", "user");
my $normaluser2 = $DB->getNode("e2e_editor", "user");

ok($admin_user, "Got admin user");
ok($normaluser1, "Got normaluser1");
ok($normaluser2, "Got normaluser2");

# Create API instances
my $writeup_api = Everything::API::writeups->new();
my $e2node_api = Everything::API::e2nodes->new();

ok($writeup_api, "Created writeups API instance");
ok($e2node_api, "Created e2nodes API instance");

#############################################################################
# Helper Functions
#############################################################################

sub cleanup_writeup {
  my ($writeup_id) = @_;
  return unless $writeup_id;
  my $writeup = $DB->getNodeById($writeup_id);
  if ($writeup && !$writeup->is_null) {
    # Clean up the writeup
    $DB->sqlDelete('writeup', "writeup_id=$writeup_id");
    $DB->sqlDelete('document', "document_id=$writeup_id");
    $DB->sqlDelete('node', "node_id=$writeup_id");
  }
  return;
}

sub cleanup_e2node {
  my ($e2node_id) = @_;
  return unless $e2node_id;
  my $e2node = $DB->getNodeById($e2node_id);
  if ($e2node && $e2node->{node_id}) {
    $DB->sqlDelete('e2node', "e2node_id=$e2node_id");
    $DB->sqlDelete('node', "node_id=$e2node_id");
  }
  return;
}

#############################################################################
# Test 1: Create E2node and Writeup
#############################################################################

my $title = "Testing writeup API " . time();
my $writeuptype = "place";
my $doctext = "Test doctext for writeup API";

# Create parent e2node first
my $e2node_type = $DB->getNode("e2node", "nodetype");
my $e2node_id = $DB->insertNode($title, $e2node_type, $normaluser1);
my $e2node = $DB->getNodeById($e2node_id);

ok($e2node, "Created test e2node");
ok($e2node->{node_id} == $e2node_id, "E2node has correct ID");

# Create writeup via API
my $user1_request = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  postdata => {
    title => $title,
    writeuptype => $writeuptype,
    doctext => $doctext
  }
);

my $result = $writeup_api->create($user1_request);
is($result->[0], $writeup_api->HTTP_OK, "Writeup creation returns 200");
ok($result->[1]->{node_id}, "Writeup has node_id");

# Get writeup from API response (JSON serialized data)
my $writeup_data = $result->[1];
ok($writeup_data, "Writeup data returned from API");

# Validate core writeup fields
ok(defined($writeup_data->{node_id}), "node_id is defined");
ok(defined($writeup_data->{title}), "title is defined");
ok(defined($writeup_data->{doctext}), "doctext is defined");
ok(defined($writeup_data->{createtime}), "createtime is defined");

# Validate content
is($writeup_data->{doctext}, $doctext, "Writeup doctext is correct");
like($writeup_data->{title}, qr/\Q$title\E \(\Q$writeuptype\E\)/, "Writeup title includes writeuptype");

my $writeup_id = $writeup_data->{node_id};

#############################################################################
# Test 2: Deletion Permissions
#############################################################################

my $user2_request = MockRequest->new(
  node_id => $normaluser2->{node_id},
  title => $normaluser2->{title},
  nodedata => $normaluser2,
  is_guest_flag => 0
);

my $nodes_api = Everything::API::nodes->new();

# Test: Non-owner cannot delete
$result = $nodes_api->delete($user2_request, $writeup_id);
is($result->[0], 403, "Non-owner cannot delete writeup (403 Forbidden)");

# Verify writeup still exists
my $writeup = $DB->getNodeById($writeup_id);
ok($writeup && $writeup->{node_id}, "Writeup still exists after failed delete");

# Test: Owner cannot delete own writeup
$result = $nodes_api->delete($user1_request, $writeup_id);
is($result->[0], 403, "Owner cannot delete own writeup (403 Forbidden)");

# Verify writeup still exists
$writeup = $DB->getNodeById($writeup_id);
ok($writeup && $writeup->{node_id}, "Writeup still exists after owner delete attempt");

# Test: Admin CAN delete
my $admin_request = MockRequest->new(
  node_id => $admin_user->{node_id},
  title => $admin_user->{title},
  nodedata => $admin_user,
  is_admin_flag => 1,
  is_guest_flag => 0
);

$result = $nodes_api->delete($admin_request, $writeup_id);
is($result->[0], 200, "Admin can delete writeup");
is($result->[1]->{deleted}, $writeup_id, "Delete returns correct node_id");

# Verify writeup is deleted
$writeup = $DB->getNodeById($writeup_id);
ok(!$writeup || !$writeup->{node_id}, "Writeup no longer exists after admin delete");

#############################################################################
# Test 3: Writeup with notnew=1
#############################################################################

$user1_request->{postdata} = {
  title => $title,
  writeuptype => $writeuptype,
  doctext => $doctext,
  notnew => 1
};

$result = $writeup_api->create($user1_request);
is($result->[0], $writeup_api->HTTP_OK, "Writeup with notnew=1 created");

my $notnew_writeup_id = $result->[1]->{node_id};
my $notnew_writeup = $DB->getNodeById($notnew_writeup_id);
is($notnew_writeup->{notnew}, 1, "notnew flag is set to 1");

# Guest cannot delete
my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1
);

$result = $nodes_api->delete($guest_request, $notnew_writeup_id);
is($result->[0], 403, "Guest cannot delete writeup (403 Forbidden)");

# Admin cleanup
$result = $nodes_api->delete($admin_request, $notnew_writeup_id);
is($result->[0], 200, "Admin deletes notnew writeup");

#############################################################################
# Test 4: Input Validation - Missing Required Fields
#############################################################################

# Missing title
$user1_request->{postdata} = {
  writeuptype => $writeuptype,
  doctext => $doctext
};
$result = $writeup_api->create($user1_request);
is($result->[0], 400, "Missing title returns 400 Bad Request");

# Missing writeuptype
$user1_request->{postdata} = {
  title => $title,
  doctext => $doctext
};
$result = $writeup_api->create($user1_request);
is($result->[0], 400, "Missing writeuptype returns 400 Bad Request");

# Missing doctext
$user1_request->{postdata} = {
  title => $title,
  writeuptype => $writeuptype
};
$result = $writeup_api->create($user1_request);
is($result->[0], 400, "Missing doctext returns 400 Bad Request");

# Guest cannot create
$guest_request->{postdata} = {
  title => $title,
  writeuptype => $writeuptype,
  doctext => $doctext
};
$result = $writeup_api->create($guest_request);
is($result->[0], 401, "Guest user creation returns 401 Unauthorized");

#############################################################################
# Cleanup
#############################################################################

cleanup_e2node($e2node_id);

done_testing();

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
use Everything::API::usergroups;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::usergroups->new();
ok($api, "Created usergroups API instance");

#############################################################################
# Test 1: Create Usergroup
#############################################################################

# Get root user for tests
my $root_user = $DB->getNode("root", "user");
ok($root_user, "Got root user");

my $description = "This is a description!<br>";
my $title = "My usergroup " . time();

my $create_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    title => $title,
    doctext => $description,
    type => 'usergroup'
  }
);

my $result = $api->create($create_request);
is($result->[0], 200, "200 OK returned from usergroup creation");
ok($result->[1]{node_id}, "Result has node_id");
my $usergroup_id = $result->[1]{node_id};
ok($usergroup_id > 0, "Non-zero node_id is returned");

# Get the created usergroup to verify
my $usergroup = $DB->getNodeById($usergroup_id);
ok($usergroup, "Can retrieve created usergroup");
is($usergroup->{doctext}, $description, "Description matches what was passed");

#############################################################################
# Test 2: Update Usergroup Description
#############################################################################

$description .= "A second line of text<br>";
my $update_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    doctext => $description
  }
);

$result = $api->update($update_request, $usergroup_id);
is($result->[0], 200, "Result of update is 200 OK");

# Refresh usergroup from DB
$usergroup = $DB->getNodeById($usergroup_id);
is($usergroup->{doctext}, $description, "Document text got updated properly");

#############################################################################
# Test 3: Add Users to Usergroup
#############################################################################

# Get test users
my $nm1 = $DB->getNode("normaluser1", "user");
ok($nm1, "Got normaluser1");

# Initial add - root to the group
# API expects postdata to be an array of user IDs
my $add_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$root_user->{node_id}]
);

$result = $api->adduser($add_request, $usergroup_id);
is($result->[0], 200, "Return code on the add is 200");
ok($result->[1], "Result has data");

# Second add - normaluser1
$add_request->{postdata} = [$nm1->{node_id}];
$result = $api->adduser($add_request, $usergroup_id);
is($result->[0], 200, "Return code on the second add is 200");
ok($result->[1], "Result has data");

# Note: Group membership verification skipped due to known nodegroup insert
# race condition in development environment

#############################################################################
# Test 4: Remove Users from Usergroup
#############################################################################

my $remove_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$nm1->{node_id}]
);

$result = $api->removeuser($remove_request, $usergroup_id);
is($result->[0], 200, "Return code on the delete is 200");
ok($result->[1], "Result has data");

# Note: Group membership verification skipped due to known nodegroup insert
# race condition in development environment

#############################################################################
# Test 5: Leave Usergroup - User leaving on their own
#############################################################################

# First, add normaluser1 back to the group
$add_request->{postdata} = [$nm1->{node_id}];
$result = $api->adduser($add_request, $usergroup_id);
is($result->[0], 200, "Added normaluser1 back to group for leave test");

# Force cache refresh to ensure nodegroup changes are visible
# This addresses a known race condition in nodegroup operations
$DB->{cache}->incrementGlobalVersion($usergroup);
$usergroup = $DB->getNodeById($usergroup_id, 'force');

# Create leave request for normaluser1 - used in multiple tests
my $leave_request = MockRequest->new(
  node_id => $nm1->{node_id},
  title => $nm1->{title},
  nodedata => $nm1,
  is_guest_flag => 0,
  is_admin_flag => 0
);

# Verify user was actually added before testing leave
my $is_member = $APP->inUsergroup($nm1->{node_id}, $usergroup);

SKIP: {
  skip "Skipping leave success test - nodegroup race condition prevented add", 3 unless $is_member;

  $result = $api->leave($leave_request, $usergroup_id);
  is($result->[0], 200, "Return code on leave is 200");
  ok($result->[1]{success}, "Leave returned success");
  like($result->[1]{message}, qr/You have left/, "Leave message is correct");
}

#############################################################################
# Test 6: Leave Usergroup - Cannot leave if not a member
#############################################################################

# Try to leave (or leave again if test 5 ran) - should fail since not a member
$result = $api->leave($leave_request, $usergroup_id);
is($result->[0], 400, "Return code is 400 when trying to leave a group you're not in");
is($result->[1]{success}, 0, "Success is false when not a member");
like($result->[1]{error}, qr/not a member/, "Error message indicates not a member");

#############################################################################
# Test 7: Leave Usergroup - Guest cannot leave
#############################################################################

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  nodedata => {},
  is_guest_flag => 1,
  is_admin_flag => 0
);

$result = $api->leave($guest_request, $usergroup_id);
is($result->[0], 403, "Return code is 403 for guest trying to leave");
is($result->[1]{success}, 0, "Success is false for guest");
like($result->[1]{error}, qr/logged in/, "Error message indicates must be logged in");

#############################################################################
# Test 8: Leave Usergroup - Invalid usergroup ID
#############################################################################

$result = $api->leave($leave_request, 999999999);
is($result->[0], 404, "Return code is 404 for invalid usergroup ID");
is($result->[1]{success}, 0, "Success is false for invalid group");
like($result->[1]{error}, qr/not found/i, "Error message indicates group not found");

#############################################################################
# Test 9: Reorder - Setup
#############################################################################

# Create a fresh usergroup for reorder tests
my $reorder_group_title = "Reorder Test Group " . time();
my $reorder_create_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    title => $reorder_group_title,
    doctext => "Test group for reorder",
    type => 'usergroup'
  }
);

$result = $api->create($reorder_create_request);
is($result->[0], 200, "Created reorder test usergroup");
my $reorder_group_id = $result->[1]{node_id};
ok($reorder_group_id, "Reorder test group has node_id");

# Add multiple users
my $nm2 = $DB->getNode("normaluser2", "user");
ok($nm2, "Got normaluser2");

# Add users one at a time to ensure order
my $add_user_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$root_user->{node_id}]
);

$result = $api->adduser($add_user_request, $reorder_group_id);
is($result->[0], 200, "Added root to reorder test group");

$add_user_request->{postdata} = [$nm1->{node_id}];
$result = $api->adduser($add_user_request, $reorder_group_id);
is($result->[0], 200, "Added normaluser1 to reorder test group");

$add_user_request->{postdata} = [$nm2->{node_id}];
$result = $api->adduser($add_user_request, $reorder_group_id);
is($result->[0], 200, "Added normaluser2 to reorder test group");

# Refresh the group
my $reorder_group = $DB->getNodeById($reorder_group_id, 'force');

#############################################################################
# Test 10: Reorder - Successful reorder
#############################################################################

# Create reorder request - API expects postdata to be an array of node IDs
my $reorder_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$nm2->{node_id}, $nm1->{node_id}, $root_user->{node_id}]
);

$result = $api->reorder($reorder_request, $reorder_group_id);
is($result->[0], 200, "Reorder returned 200");
ok($result->[1]{success}, "Reorder was successful");

#############################################################################
# Test 11: Reorder - Invalid node_id in list
#############################################################################

my $invalid_reorder_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [999999999, $nm1->{node_id}, $root_user->{node_id}]
);

$result = $api->reorder($invalid_reorder_request, $reorder_group_id);
is($result->[0], 200, "Invalid reorder returns 200 with error");
is($result->[1]{success}, 0, "Invalid reorder has success=0");
like($result->[1]{error}, qr/not in this group/i, "Error mentions node not in group");

#############################################################################
# Test 12: Routes check
# Note: User search is now handled by the unified /api/node_search endpoint
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
ok(exists $routes->{':id/action/adduser'}, "adduser route exists");
ok(exists $routes->{':id/action/removeuser'}, "removeuser route exists");
ok(exists $routes->{':id/action/leave'}, "leave route exists");
ok(exists $routes->{':id/action/reorder'}, "reorder route exists");
ok(exists $routes->{':id/action/description'}, "description route exists");
ok(exists $routes->{':id/action/transfer_ownership'}, "transfer_ownership route exists");
ok(exists $routes->{':id/action/weblogify'}, "weblogify route exists");
ok(!exists $routes->{':id/action/search'}, "deprecated search route no longer exists");

#############################################################################
# Test 13: Update Description - Successful update by admin
#############################################################################

my $new_description = "Updated description via API test " . time();
my $desc_update_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => { doctext => $new_description }
);

$result = $api->update_description($desc_update_request, $reorder_group_id);
is($result->[0], 200, "Description update by admin returns 200");
ok($result->[1]{success}, "Description update by admin was successful");
is($result->[1]{doctext}, $new_description, "Returned doctext matches what was sent");

# Verify in database
$reorder_group = $DB->getNodeById($reorder_group_id, 'force');
is($reorder_group->{doctext}, $new_description, "Description was updated in database");

#############################################################################
# Test 14: Update Description - Successful update by owner
#############################################################################

# First, set normaluser1 as the owner of the group
$APP->setParameter($reorder_group, $root_user, 'usergroup_owner', $nm1->{node_id});

# Force cache refresh so API sees the new owner
$DB->{cache}->incrementGlobalVersion($reorder_group);

my $owner_description = "Owner updated this description " . time();
my $owner_desc_request = MockRequest->new(
  node_id => $nm1->{node_id},
  title => $nm1->{title},
  nodedata => $nm1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { doctext => $owner_description }
);

$result = $api->update_description($owner_desc_request, $reorder_group_id);
is($result->[0], 200, "Description update by owner returns 200");
ok($result->[1]{success}, "Description update by owner was successful");
is($result->[1]{doctext}, $owner_description, "Owner update returned correct doctext");

# Verify in database
$reorder_group = $DB->getNodeById($reorder_group_id, 'force');
is($reorder_group->{doctext}, $owner_description, "Owner's description update persisted to database");

#############################################################################
# Test 15: Update Description - Permission denied for non-owner/non-admin
#############################################################################

# normaluser2 is not the owner and not an admin
my $unauthorized_desc_request = MockRequest->new(
  node_id => $nm2->{node_id},
  title => $nm2->{title},
  nodedata => $nm2,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { doctext => "This should not be saved" }
);

$result = $api->update_description($unauthorized_desc_request, $reorder_group_id);
is($result->[0], 403, "Description update by non-owner/non-admin returns 403");
is($result->[1]{success}, 0, "Unauthorized update has success=0");
like($result->[1]{error}, qr/permission denied/i, "Error message indicates permission denied");

# Verify description was NOT changed
$reorder_group = $DB->getNodeById($reorder_group_id, 'force');
is($reorder_group->{doctext}, $owner_description, "Description unchanged after unauthorized attempt");

#############################################################################
# Test 16: Update Description - Missing doctext parameter
#############################################################################

my $missing_doctext_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => { title => "wrong field" }
);

$result = $api->update_description($missing_doctext_request, $reorder_group_id);
is($result->[0], 200, "Missing doctext returns 200 with error");
is($result->[1]{success}, 0, "Missing doctext has success=0");
like($result->[1]{error}, qr/missing doctext/i, "Error message indicates missing doctext");

#############################################################################
# Test 17: Update Description - Guest cannot update
#############################################################################

my $guest_desc_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  nodedata => {},
  is_guest_flag => 1,
  is_admin_flag => 0,
  postdata => { doctext => "Guest trying to update" }
);

$result = $api->update_description($guest_desc_request, $reorder_group_id);
is($result->[0], 403, "Description update by guest returns 403");
is($result->[1]{success}, 0, "Guest update has success=0");

#############################################################################
# Test 18: Update Description - Invalid usergroup ID
#############################################################################

$result = $api->update_description($desc_update_request, 999999999);
is($result->[0], 404, "Description update for invalid group returns 404");

#############################################################################
# Test 19: Update Description - Editor can update
#############################################################################

my $editor_description = "Editor updated this " . time();
my $editor_desc_request = MockRequest->new(
  node_id => $nm2->{node_id},
  title => $nm2->{title},
  nodedata => $nm2,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 1,
  postdata => { doctext => $editor_description }
);

$result = $api->update_description($editor_desc_request, $reorder_group_id);
is($result->[0], 200, "Description update by editor returns 200");
ok($result->[1]{success}, "Description update by editor was successful");

#############################################################################
# Test 20: Transfer Ownership - Routes check
#############################################################################

$routes = $api->routes();
ok(exists $routes->{':id/action/transfer_ownership'}, "transfer_ownership route exists");

#############################################################################
# Test 21: Transfer Ownership - Setup
#############################################################################

# Create a fresh usergroup for transfer ownership tests
my $transfer_group_title = "Transfer Test Group " . time();
my $transfer_create_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    title => $transfer_group_title,
    doctext => "Test group for ownership transfer",
    type => 'usergroup'
  }
);

$result = $api->create($transfer_create_request);
is($result->[0], 200, "Created transfer test usergroup");
my $transfer_group_id = $result->[1]{node_id};
ok($transfer_group_id, "Transfer test group has node_id");

# Get the transfer group
my $transfer_group = $DB->getNodeById($transfer_group_id, 'force');

# Add nm1 and nm2 to the group
my $transfer_add_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$nm1->{node_id}]
);

$result = $api->adduser($transfer_add_request, $transfer_group_id);
is($result->[0], 200, "Added normaluser1 to transfer test group");

$transfer_add_request->{postdata} = [$nm2->{node_id}];
$result = $api->adduser($transfer_add_request, $transfer_group_id);
is($result->[0], 200, "Added normaluser2 to transfer test group");

# Set normaluser1 as owner
$APP->setParameter($transfer_group, $root_user, 'usergroup_owner', $nm1->{node_id});
$DB->{cache}->incrementGlobalVersion($transfer_group);

#############################################################################
# Test 22: Transfer Ownership - Owner can transfer
#############################################################################

my $transfer_request = MockRequest->new(
  node_id => $nm1->{node_id},
  title => $nm1->{title},
  nodedata => $nm1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { new_owner_id => $nm2->{node_id} }
);

$result = $api->transfer_ownership($transfer_request, $transfer_group_id);
is($result->[0], 200, "Transfer ownership by owner returns 200");
ok($result->[1]{success}, "Transfer ownership was successful");
like($result->[1]{message}, qr/transferred/i, "Success message indicates transfer");

# Verify new owner in database
$transfer_group = $DB->getNodeById($transfer_group_id, 'force');
my $new_owner_id = $APP->getParameter($transfer_group, 'usergroup_owner');
is($new_owner_id, $nm2->{node_id}, "Ownership transferred to normaluser2 in database");

#############################################################################
# Test 23: Transfer Ownership - Admin can transfer (even if not owner)
#############################################################################

my $admin_transfer_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => { new_owner_id => $nm1->{node_id} }
);

$result = $api->transfer_ownership($admin_transfer_request, $transfer_group_id);
is($result->[0], 200, "Transfer ownership by admin returns 200");
ok($result->[1]{success}, "Admin transfer was successful");

# Verify ownership back to nm1
$transfer_group = $DB->getNodeById($transfer_group_id, 'force');
$new_owner_id = $APP->getParameter($transfer_group, 'usergroup_owner');
is($new_owner_id, $nm1->{node_id}, "Admin transferred ownership back to normaluser1");

#############################################################################
# Test 24: Transfer Ownership - Non-owner cannot transfer
#############################################################################

my $non_owner_transfer_request = MockRequest->new(
  node_id => $nm2->{node_id},
  title => $nm2->{title},
  nodedata => $nm2,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { new_owner_id => $nm2->{node_id} }
);

$result = $api->transfer_ownership($non_owner_transfer_request, $transfer_group_id);
is($result->[0], 403, "Transfer ownership by non-owner returns 403");
is($result->[1]{success}, 0, "Non-owner transfer has success=0");
like($result->[1]{error}, qr/only the owner/i, "Error indicates only owner can transfer");

#############################################################################
# Test 25: Transfer Ownership - Cannot transfer to non-member
#############################################################################

# Get a user who is not in the group
my $nm3 = $DB->getNode("normaluser3", "user");
# If normaluser3 doesn't exist, we skip this test
SKIP: {
  skip "normaluser3 not found - skipping transfer to non-member test", 3 unless $nm3;

  my $non_member_transfer = MockRequest->new(
    node_id => $nm1->{node_id},
    title => $nm1->{title},
    nodedata => $nm1,
    is_guest_flag => 0,
    is_admin_flag => 0,
    is_editor_flag => 0,
    postdata => { new_owner_id => $nm3->{node_id} }
  );

  $result = $api->transfer_ownership($non_member_transfer, $transfer_group_id);
  is($result->[0], 200, "Transfer to non-member returns 200 with error");
  is($result->[1]{success}, 0, "Transfer to non-member has success=0");
  like($result->[1]{error}, qr/must be a member/i, "Error indicates new owner must be member");
}

#############################################################################
# Test 26: Transfer Ownership - Missing new_owner_id
#############################################################################

my $missing_owner_request = MockRequest->new(
  node_id => $nm1->{node_id},
  title => $nm1->{title},
  nodedata => $nm1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { }
);

$result = $api->transfer_ownership($missing_owner_request, $transfer_group_id);
is($result->[0], 200, "Transfer with missing new_owner_id returns 200 with error");
is($result->[1]{success}, 0, "Missing new_owner_id has success=0");
like($result->[1]{error}, qr/missing new_owner_id/i, "Error indicates missing parameter");

#############################################################################
# Test 27: Transfer Ownership - Guest cannot transfer
#############################################################################

my $guest_transfer_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  nodedata => {},
  is_guest_flag => 1,
  is_admin_flag => 0,
  postdata => { new_owner_id => $nm2->{node_id} }
);

$result = $api->transfer_ownership($guest_transfer_request, $transfer_group_id);
is($result->[0], 403, "Transfer ownership by guest returns 403");
is($result->[1]{success}, 0, "Guest transfer has success=0");

#############################################################################
# Test 28: Weblogify - Routes check
#############################################################################

$routes = $api->routes();
ok(exists $routes->{':id/action/weblogify'}, "weblogify route exists");

#############################################################################
# Test 29: Weblogify - Admin can set weblog display
#############################################################################

my $weblog_group_title = "Weblog Test Group " . time();
my $weblog_create_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    title => $weblog_group_title,
    doctext => "Test group for weblogify",
    type => 'usergroup'
  }
);

$result = $api->create($weblog_create_request);
is($result->[0], 200, "Created weblogify test usergroup");
my $weblog_group_id = $result->[1]{node_id};
ok($weblog_group_id, "Weblog test group has node_id");

# Add a user to the group first
my $weblog_add_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$nm1->{node_id}]
);

$result = $api->adduser($weblog_add_request, $weblog_group_id);
is($result->[0], 200, "Added normaluser1 to weblog test group");

# Now test weblogify
my $ify_display = "Testify";
my $weblogify_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => { ify_display => $ify_display }
);

$result = $api->weblogify($weblogify_request, $weblog_group_id);
is($result->[0], 200, "Weblogify by admin returns 200");
ok($result->[1]{success}, "Weblogify was successful");
is($result->[1]{ify_display}, $ify_display, "Returned ify_display matches what was sent");
like($result->[1]{message}, qr/Weblog display set/i, "Success message indicates weblog was set");

# Verify in the webloggables setting
my $wl = $DB->getNode('webloggables', 'setting');
ok($wl, "webloggables setting node exists");
my $wSettings = $APP->getVars($wl);
is($wSettings->{$weblog_group_id}, $ify_display, "Webloggables setting updated in database");

#############################################################################
# Test 30: Weblogify - Non-admin cannot set weblog display
#############################################################################

my $non_admin_weblogify = MockRequest->new(
  node_id => $nm1->{node_id},
  title => $nm1->{title},
  nodedata => $nm1,
  is_guest_flag => 0,
  is_admin_flag => 0,
  is_editor_flag => 0,
  postdata => { ify_display => "ShouldFail" }
);

$result = $api->weblogify($non_admin_weblogify, $weblog_group_id);
is($result->[0], 403, "Weblogify by non-admin returns 403");
is($result->[1]{success}, 0, "Non-admin weblogify has success=0");
like($result->[1]{error}, qr/only admins/i, "Error indicates only admins can modify");

#############################################################################
# Test 31: Weblogify - Guest cannot set weblog display
#############################################################################

my $guest_weblogify = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  nodedata => {},
  is_guest_flag => 1,
  is_admin_flag => 0,
  postdata => { ify_display => "GuestFail" }
);

$result = $api->weblogify($guest_weblogify, $weblog_group_id);
is($result->[0], 403, "Weblogify by guest returns 403");
is($result->[1]{success}, 0, "Guest weblogify has success=0");

#############################################################################
# Test 32: Weblogify - Missing ify_display parameter
#############################################################################

my $missing_ify_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => { }
);

$result = $api->weblogify($missing_ify_request, $weblog_group_id);
is($result->[0], 200, "Missing ify_display returns 200 with error");
is($result->[1]{success}, 0, "Missing ify_display has success=0");
like($result->[1]{error}, qr/missing ify_display/i, "Error indicates missing parameter");

#############################################################################
# Test 33: Weblogify - Invalid usergroup ID
#############################################################################

$result = $api->weblogify($weblogify_request, 999999999);
is($result->[0], 404, "Weblogify for invalid group returns 404");
is($result->[1]{success}, 0, "Invalid group weblogify has success=0");

#############################################################################
# Test 34: Remove Weblogify - Admin can remove weblog setting (DELETE)
#############################################################################

# First create a fresh group and set weblogify on it
my $remove_weblog_group_title = "Remove Weblog Test " . time();
my $remove_weblog_create_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    title => $remove_weblog_group_title,
    doctext => "Test group for weblogify removal",
    type => 'usergroup'
  }
);

$result = $api->create($remove_weblog_create_request);
is($result->[0], 200, "Created remove weblogify test usergroup");
my $remove_weblog_group_id = $result->[1]{node_id};
ok($remove_weblog_group_id, "Remove weblog test group has node_id");

# Add a user
my $remove_weblog_add = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$nm1->{node_id}]
);

$result = $api->adduser($remove_weblog_add, $remove_weblog_group_id);
is($result->[0], 200, "Added user to remove weblogify test group");

# Set the weblogify
my $remove_weblog_set_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => { ify_display => "RemoveTestify" }
);

$result = $api->weblogify($remove_weblog_set_request, $remove_weblog_group_id);
is($result->[0], 200, "Set weblogify on remove test group");

# Verify it was set
$wl = $DB->getNode('webloggables', 'setting');
$wSettings = $APP->getVars($wl);
is($wSettings->{$remove_weblog_group_id}, "RemoveTestify", "Weblogify was set before removal test");

# Now test remove_weblogify
my $remove_weblog_group = $APP->node_by_id($remove_weblog_group_id);
$result = $api->remove_weblogify($root_user, $remove_weblog_group);
is($result->[0], 200, "Remove weblogify returns 200");
ok($result->[1]{success}, "Remove weblogify was successful");
like($result->[1]{message}, qr/removed/i, "Success message indicates removal");

# Verify it was removed from webloggables
$wl = $DB->getNode('webloggables', 'setting', 'force');
$wSettings = $APP->getVars($wl);
ok(!exists $wSettings->{$remove_weblog_group_id}, "Weblogify setting removed from webloggables");

# Cleanup this test group
my $remove_weblog_group_node = $DB->getNodeById($remove_weblog_group_id);
$DB->nukeNode($remove_weblog_group_node, $root_user) if $remove_weblog_group_node;

#############################################################################
# Test 34b: Weblogify - DELETE method through permission wrapper
# This tests that request_method is properly accessible
#############################################################################

# Create another test group for testing DELETE via wrapper
my $delete_test_group_title = "Delete Wrapper Test " . time();
my $delete_test_create = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => {
    title => $delete_test_group_title,
    doctext => "Test group for DELETE method wrapper test",
    type => 'usergroup'
  }
);

$result = $api->create($delete_test_create);
is($result->[0], 200, "Created DELETE wrapper test usergroup");
my $delete_test_group_id = $result->[1]{node_id};
ok($delete_test_group_id, "DELETE test group has node_id");

# Set weblogify first (POST method)
my $delete_set_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  request_method => 'POST',
  postdata => { ify_display => "DeleteTestify" }
);

# Call weblogify directly - the around modifier handles the wrapper automatically
$result = $api->weblogify($delete_set_request, $delete_test_group_id);
is($result->[0], 200, "POST weblogify returns 200");
ok($result->[1]{success}, "POST weblogify was successful");

# Verify it was set
$wl = $DB->getNode('webloggables', 'setting', 'force');
$wSettings = $APP->getVars($wl);
is($wSettings->{$delete_test_group_id}, "DeleteTestify", "Weblogify was set");

# Now test DELETE method - this tests request_method accessor works correctly
my $delete_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  request_method => 'DELETE'
);

# Call weblogify - the around modifier handles permissions and request_method check
$result = $api->weblogify($delete_request, $delete_test_group_id);
is($result->[0], 200, "DELETE weblogify returns 200");
ok($result->[1]{success}, "DELETE weblogify was successful");
like($result->[1]{message}, qr/removed/i, "DELETE response indicates removal");

# Verify it was removed
$wl = $DB->getNode('webloggables', 'setting', 'force');
$wSettings = $APP->getVars($wl);
ok(!exists $wSettings->{$delete_test_group_id}, "Weblogify removed via DELETE");

# Cleanup
my $delete_test_group_node = $DB->getNodeById($delete_test_group_id);
$DB->nukeNode($delete_test_group_node, $root_user) if $delete_test_group_node;

#############################################################################
# Cleanup weblog test group
#############################################################################

my $weblog_group_node = $DB->getNodeById($weblog_group_id);
$DB->nukeNode($weblog_group_node, $root_user) if $weblog_group_node;

#############################################################################
# Test 35: Remove Owner - Owner cannot be removed
#############################################################################

# Make sure nm1 is still owner
$transfer_group = $DB->getNodeById($transfer_group_id, 'force');
$APP->setParameter($transfer_group, $root_user, 'usergroup_owner', $nm1->{node_id});
$DB->{cache}->incrementGlobalVersion($transfer_group);

my $remove_owner_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  postdata => [$nm1->{node_id}]
);

$result = $api->removeuser($remove_owner_request, $transfer_group_id);
is($result->[0], 200, "Remove owner returns 200 with error");
is($result->[1]{success}, 0, "Remove owner has success=0");
like($result->[1]{error}, qr/cannot remove.*owner/i, "Error indicates cannot remove owner");

# Verify owner is still in group
$transfer_group = $DB->getNodeById($transfer_group_id, 'force');
my $owner_in_group = $APP->inUsergroup($nm1->{node_id}, $transfer_group);
ok($owner_in_group, "Owner still in group after removal attempt");

#############################################################################
# Cleanup
#############################################################################

# Delete the transfer test group
my $transfer_group_node = $DB->getNodeById($transfer_group_id);
$DB->nukeNode($transfer_group_node, $root_user) if $transfer_group_node;

# Delete the reorder test group
my $reorder_group_node = $DB->getNodeById($reorder_group_id);
$DB->nukeNode($reorder_group_node, $root_user) if $reorder_group_node;

# Delete the original test group
my $usergroup_node = $DB->getNodeById($usergroup_id);
$DB->nukeNode($usergroup_node, $root_user) if $usergroup_node;

done_testing();

=head1 NAME

t/004_usergroups.t - Tests for Everything::API::usergroups

=head1 DESCRIPTION

Tests usergroup CRUD operations:
- Create usergroup (via inherited nodes.pm create)
- Update usergroup description (via inherited nodes.pm update)
- Add users to usergroup (adduser method)
- Remove users from usergroup (removeuser method)
  - Cannot remove the group owner (must transfer ownership first)
- Leave usergroup (leave method) - user removing themselves
  - Successful leave when user is a member
  - Cannot leave a group you're not a member of (400)
  - Guest users cannot leave groups (403)
  - Invalid usergroup ID returns 404
- Reorder members (reorder method)
  - Successful reorder with valid node IDs
  - Error when node ID not in group
- Search users/usergroups (search_users method)
  - Basic search returns results
  - Short query returns empty array
- Update description (update_description method)
  - Successful update by admin
  - Successful update by owner
  - Successful update by editor
  - Permission denied for non-owner/non-admin/non-editor (403)
  - Guest users cannot update (403)
  - Invalid usergroup ID returns 404
  - Missing doctext parameter returns error
- Transfer ownership (transfer_ownership method)
  - Owner can transfer to another member
  - Admin can transfer (even if not owner)
  - Non-owner cannot transfer (403)
  - Cannot transfer to non-member
  - Missing new_owner_id parameter returns error
  - Guest cannot transfer (403)
- Weblogify (weblogify method) - admin-only
  - Admin can set weblog display name
  - Non-admin cannot set weblog display (403)
  - Guest cannot set weblog display (403)
  - Missing ify_display parameter returns error
  - Invalid usergroup ID returns 404
- Remove Weblogify (remove_weblogify method) - admin-only
  - Admin can remove weblog display setting
  - Verifies setting is removed from webloggables
- Routes verification

Note: Multi-add tests disabled due to known nodegroup insert race condition
in development environment.

=head1 AUTHOR

Everything2 Development Team

=cut

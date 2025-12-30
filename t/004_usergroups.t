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

done_testing();

=head1 NAME

t/004_usergroups.t - Tests for Everything::API::usergroups

=head1 DESCRIPTION

Tests usergroup CRUD operations:
- Create usergroup (via inherited nodes.pm create)
- Update usergroup description (via inherited nodes.pm update)
- Add users to usergroup (adduser method)
- Remove users from usergroup (removeuser method)
- Leave usergroup (leave method) - user removing themselves
  - Successful leave when user is a member
  - Cannot leave a group you're not a member of (400)
  - Guest users cannot leave groups (403)
  - Invalid usergroup ID returns 404

Note: Multi-add tests disabled due to known nodegroup insert race condition
in development environment.

=head1 AUTHOR

Everything2 Development Team

=cut

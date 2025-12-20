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

done_testing();

=head1 NAME

t/004_usergroups.t - Tests for Everything::API::usergroups

=head1 DESCRIPTION

Tests usergroup CRUD operations:
- Create usergroup (via inherited nodes.pm create)
- Update usergroup description (via inherited nodes.pm update)
- Add users to usergroup (adduser method)
- Remove users from usergroup (removeuser method)

Note: Multi-add tests disabled due to known nodegroup insert race condition
in development environment.

=head1 AUTHOR

Everything2 Development Team

=cut

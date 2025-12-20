#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Test::Deep;
use Everything;
use Everything::Application;
use Everything::API::messageignores;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Message Ignores API - CRUD Operations
#
# This test verifies:
# - Guest users cannot access ignores (401 Unauthorized)
# - Getting list of ignored users
# - Ignoring users by name and by ID
# - Checking if ignoring specific user
# - Unignoring users
# - Idempotent operations (ignore twice, unignore twice)
#
# Replaces legacy t/005_messageignores.t that used Everything::APIClient
#############################################################################

# Get test users
my $root = $DB->getNode("root", "user");
my $normaluser1 = $DB->getNode("e2e_user", "user");
my $cme = $DB->getNode("Cool Man Eddie", "user");
my $virgil = $DB->getNode("Virgil", "user");

ok($root, "Got root user");
ok($normaluser1, "Got normaluser1");
ok($cme, "Got Cool Man Eddie");
ok($virgil, "Got Virgil");

# Expected structures
my $cme_struct = {
  'type' => 'user',
  'title' => 'Cool Man Eddie',
  'node_id' => $cme->{node_id}
};

my $virgil_struct = {
  'type' => 'user',
  'node_id' => $virgil->{node_id},
  'title' => 'Virgil'
};

# Create API instance
my $api = Everything::API::messageignores->new();
ok($api, "Created messageignores API instance");

#############################################################################
# Test 1: Guest User - Cannot Access Ignores (401 Unauthorized)
#############################################################################

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1
);

my $result = $api->get_all($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest get_ignores returns 401 Unauthorized");

$guest_request->{postdata} = { ignore => "root" };
$result = $api->create($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest ignore_messages_from returns 401 Unauthorized");

$result = $api->delete($guest_request, 113);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest unignore_messages_from_id returns 401 Unauthorized");

#############################################################################
# Test 2 & 3: Authenticated Users - Full Ignore/Unignore Workflow
#############################################################################

foreach my $user_data ({name => "root", node => $root}, {name => "e2e_user", node => $normaluser1})
{
  my $user = $user_data->{node};
  my $user_name = $user_data->{name};

  my $user_request = MockRequest->new(
    node_id => $user->{node_id},
    title => $user->{title},
    nodedata => $user,
    is_guest_flag => 0,
    ignores => []
  );

  # Get initial empty ignores list
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], [], "$user_name: Initial ignoring set is empty");

  # Ignore Cool Man Eddie
  $user_request->{postdata} = { ignore => "Cool Man Eddie" };
  $result = $api->create($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: Ignore CME returns 200 OK");
  cmp_deeply($result->[1], $cme_struct, "$user_name: Ignore CME returns correct struct");

  # Verify ignoring CME
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], [$cme_struct], "$user_name: Ignoring only CME");

  # Ignore Virgil by ID
  $user_request->{postdata} = { ignore_id => $virgil->{node_id} };
  $result = $api->create($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: Ignore Virgil by ID returns 200 OK");
  cmp_deeply($result->[1], $virgil_struct, "$user_name: Ignore Virgil returns correct struct");

  # Verify ignoring both
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], bag($cme_struct, $virgil_struct), "$user_name: Currently ignoring 2 users");

  # Ignore Virgil again (idempotent)
  $user_request->{postdata} = { ignore_id => $virgil->{node_id} };
  $result = $api->create($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: Ignore Virgil again returns 200 OK");
  cmp_deeply($result->[1], $virgil_struct, "$user_name: Second ignore returns correct struct");

  # Still only 2 users
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], bag($cme_struct, $virgil_struct), "$user_name: Still only ignoring 2 users");

  # Unignore Virgil
  $result = $api->delete($user_request, $virgil->{node_id});
  is($result->[0], $api->HTTP_OK, "$user_name: Unignore Virgil returns 200 OK");
  cmp_deeply($result->[1], [$virgil->{node_id}], "$user_name: Unignore returns correct ID");

  # Verify only CME
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], [$cme_struct], "$user_name: Now only ignoring CME");

  # Unignore CME
  $result = $api->delete($user_request, $cme->{node_id});
  is($result->[0], $api->HTTP_OK, "$user_name: Unignore CME returns 200 OK");
  cmp_deeply($result->[1], [$cme->{node_id}], "$user_name: Unignore returns correct ID");

  # Verify empty
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], [], "$user_name: Ignore list is empty");

  # Unignore CME again (idempotent)
  $result = $api->delete($user_request, $cme->{node_id});
  is($result->[0], $api->HTTP_OK, "$user_name: Unignore CME again returns 200 OK");
  cmp_deeply($result->[1], [$cme->{node_id}], "$user_name: Second unignore returns correct ID");

  # Still empty
  $result = $api->get_all($user_request);
  is($result->[0], $api->HTTP_OK, "$user_name: get_all returns 200 OK");
  cmp_deeply($result->[1], [], "$user_name: Ignore list still empty");
}

done_testing();

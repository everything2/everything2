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
use Everything::API::preferences;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Preferences API - Get, Set, Validation
#
# This test verifies preference management including:
# - Getting default preferences as guest
# - Setting preferences requires authentication
# - Preference validation (whitelisted keys and values)
# - String preferences (collapsedNodelets)
# - Mixed valid/invalid preference handling
#
# Replaces legacy t/010_preferences.t that used Everything::APIClient
#############################################################################

# Test preference keys
my $testpref = "vit_hidenodeinfo";
my $testpref2 = "vit_hidemisc";

# Get test users
my $normaluser1 = $DB->getNode("e2e_user", "user");
ok($normaluser1, "Got normaluser1");

# Create API instance
my $api = Everything::API::preferences->new();
ok($api, "Created preferences API instance");

#############################################################################
# Test 1: Guest User - Get Preferences (Returns Defaults)
#############################################################################

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1
);

my $result = $api->get_preferences($guest_request);
is($result->[0], $api->HTTP_OK, "Guest get preferences returns 200 OK");
ok($result->[1], "Guest get preferences returns data");
ok(defined($result->[1]->{$testpref}) && $result->[1]->{$testpref} == 0, "Sample guest preference is zero (default)");

#############################################################################
# Test 2: Guest User - Cannot Set Preferences (401 Unauthorized)
#############################################################################

$guest_request->{postdata} = { $testpref => 1 };
$result = $api->set_preferences($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest set preferences returns 401 Unauthorized");

# String preference
$guest_request->{postdata} = { "collapsedNodelets" => "epicenter!" };
$result = $api->set_preferences($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest set string preference returns 401 Unauthorized");

#############################################################################
# Test 3: Authenticated User - Set Valid Preference
#############################################################################

my $user1_request = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  vars => {}
);

$user1_request->{postdata} = { $testpref => 1 };
$result = $api->set_preferences($user1_request);
is($result->[0], $api->HTTP_OK, "User set preference returns 200 OK");
is($result->[1]->{$testpref}, 1, "Set preference returns updated value");

#############################################################################
# Test 4: Verify Preference Persisted
#############################################################################

$result = $api->get_preferences($user1_request);
is($result->[0], $api->HTTP_OK, "Get preferences returns 200 OK");
is($result->[1]->{$testpref}, 1, "Preference was persisted");

#############################################################################
# Test 5: Invalid Preference Key (401 Unauthorized)
#############################################################################

$user1_request->{postdata} = { "non_whitelisted_pref" => 1 };
$result = $api->set_preferences($user1_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Non-whitelisted preference returns 401 Unauthorized");

#############################################################################
# Test 6: Invalid Preference Value (401 Unauthorized)
#############################################################################

$user1_request->{postdata} = { $testpref => "badvalue" };
$result = $api->set_preferences($user1_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Invalid preference value returns 401 Unauthorized");

#############################################################################
# Test 7: Mixed Valid/Invalid Preferences (401 Unauthorized)
#############################################################################

$user1_request->{postdata} = { $testpref => "badvalue", $testpref2 => 0 };
$result = $api->set_preferences($user1_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Mixed valid/invalid preferences returns 401 Unauthorized");

#############################################################################
# Test 8: String Preferences (collapsedNodelets)
#############################################################################

# Test various string values for collapsedNodelets
foreach my $pref_value ("epicenter!", "", "epicenter!readthis!", "epicenter!")
{
  $user1_request->{postdata} = { "collapsedNodelets" => $pref_value };
  $result = $api->set_preferences($user1_request);
  is($result->[0], $api->HTTP_OK, "Set collapsedNodelets to '$pref_value' returns 200 OK");
  is($result->[1]->{collapsedNodelets}, $pref_value, "Set returns correct value '$pref_value'");

  # Verify it persisted
  $result = $api->get_preferences($user1_request);
  is($result->[0], $api->HTTP_OK, "Get preferences returns 200 OK");
  is($result->[1]->{collapsedNodelets}, $pref_value, "String preference persisted as '$pref_value'");
}

done_testing();

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
use Everything::API::developervars;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Developer VARS API - Authorization and Data Access
#
# This test verifies that:
# - Guest users cannot access developer VARS (401 Unauthorized)
# - Normal users cannot access developer VARS (401 Unauthorized)
# - Developers can access their VARS (200 OK)
# - VARS data is returned correctly
#
# Replaces legacy t/011_developervars.t that used Everything::APIClient
#############################################################################

# Get test users
my $normaluser1 = $DB->getNode("e2e_user", "user");
my $developer = $DB->getNode("genericdev", "user");

ok($normaluser1, "Got normaluser1");
ok($developer, "Got developer user");

# Create API instance
my $api = Everything::API::developervars->new();
ok($api, "Created developervars API instance");

#############################################################################
# Test 1: Guest User - Cannot Access Developer VARS (401 Unauthorized)
#############################################################################

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1,
  is_developer_flag => 0
);

my $result = $api->get_vars($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest get developer VARS returns 401 Unauthorized");

#############################################################################
# Test 2: Normal User - Cannot Access Developer VARS (401 Unauthorized)
#############################################################################

my $normal_request = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  is_developer_flag => 0
);

$result = $api->get_vars($normal_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Normal user get developer VARS returns 401 Unauthorized");

#############################################################################
# Test 3: Developer - Can Access Developer VARS (200 OK)
#############################################################################

my $dev_request = MockRequest->new(
  node_id => $developer->{node_id},
  title => $developer->{title},
  nodedata => $developer,
  is_guest_flag => 0,
  is_developer_flag => 1,
  vars => {
    nodelets => 'epicenter!readthis!',
    some_dev_setting => 1
  }
);

$result = $api->get_vars($dev_request);
is($result->[0], $api->HTTP_OK, "Developer get VARS returns 200 OK");
ok($result->[1], "Developer VARS returns data");
ok(exists($result->[1]->{nodelets}), "Sample VARS key exists");
is($result->[1]->{nodelets}, 'epicenter!readthis!', "VARS value is correct");

done_testing();

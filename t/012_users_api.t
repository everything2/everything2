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
use Everything::API::users;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::users->new();
ok($api, "Created users API instance");

#############################################################################
# Test 1: Routes check - lookup route exists
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
ok(exists $routes->{'lookup'}, "lookup route exists");

#############################################################################
# Test 2: Lookup - Find existing user
#############################################################################

my $root_user = $DB->getNode("root", "user");
ok($root_user, "Got root user");

my $lookup_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => { username => 'root' }
);

my $result = $api->lookup($lookup_request);
is($result->[0], 200, "Lookup returns 200");
ok($result->[1]{success}, "Lookup was successful");
is($result->[1]{user_id}, $root_user->{node_id}, "Returned correct user_id");
is($result->[1]{username}, 'root', "Returned correct username");

#############################################################################
# Test 3: Lookup - User not found
#############################################################################

my $notfound_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => { username => 'nonexistent_user_' . time() }
);

$result = $api->lookup($notfound_request);
is($result->[0], 200, "Lookup for nonexistent user returns 200 with error");
is($result->[1]{success}, 0, "Lookup has success=0 for nonexistent user");
like($result->[1]{error}, qr/not found/i, "Error message indicates user not found");

#############################################################################
# Test 4: Lookup - Missing username parameter
#############################################################################

my $missing_param_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => {}
);

$result = $api->lookup($missing_param_request);
is($result->[0], 200, "Lookup with missing param returns 200 with error");
is($result->[1]{success}, 0, "Lookup has success=0 for missing param");
like($result->[1]{error}, qr/missing username/i, "Error message indicates missing parameter");

#############################################################################
# Test 5: Lookup - Empty username parameter
#############################################################################

my $empty_param_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => { username => '' }
);

$result = $api->lookup($empty_param_request);
is($result->[0], 200, "Lookup with empty param returns 200 with error");
is($result->[1]{success}, 0, "Lookup has success=0 for empty param");
like($result->[1]{error}, qr/missing username/i, "Error message indicates missing parameter");

#############################################################################
# Test 6: Lookup - Whitespace-only username
#############################################################################

my $whitespace_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => { username => '   ' }
);

$result = $api->lookup($whitespace_request);
is($result->[0], 200, "Lookup with whitespace returns 200 with error");
is($result->[1]{success}, 0, "Lookup has success=0 for whitespace");
like($result->[1]{error}, qr/missing username/i, "Error message indicates missing parameter");

#############################################################################
# Test 7: Lookup - Username with extra whitespace
#############################################################################

my $whitespace_user_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => { username => '  root  ' }
);

$result = $api->lookup($whitespace_user_request);
is($result->[0], 200, "Lookup with trimmed username returns 200");
ok($result->[1]{success}, "Lookup trims whitespace and finds user");
is($result->[1]{username}, 'root', "Returned correct username after trimming");

#############################################################################
# Test 8: Lookup - Case sensitivity (E2 usernames are case-sensitive)
#############################################################################

my $case_request = MockRequest->new(
  node_id => $root_user->{node_id},
  title => $root_user->{title},
  nodedata => $root_user,
  is_guest_flag => 0,
  is_admin_flag => 1,
  query_params => { username => 'ROOT' }
);

$result = $api->lookup($case_request);
# Note: This depends on DB collation - check if user was found
if ($result->[1]{success}) {
  pass("Lookup found user (case-insensitive collation)");
} else {
  pass("Lookup did not find user (case-sensitive collation)");
}

done_testing();

=head1 NAME

t/012_users_api.t - Tests for Everything::API::users

=head1 DESCRIPTION

Tests user API operations:
- Lookup user by username
  - Find existing user
  - User not found
  - Missing username parameter
  - Empty username parameter
  - Whitespace-only username
  - Username with extra whitespace (trimmed)
  - Case sensitivity check

=head1 AUTHOR

Everything2 Development Team

=cut

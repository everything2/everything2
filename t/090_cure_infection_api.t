#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::user;
use MockRequest;

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");

#############################################################################
# Test POST /api/user/cure - Cure User Infection API
#
# This endpoint allows admins to remove the "infected" flag from users.
# The infected flag is a primitive bot detection mechanism.
#
# Tests verify:
# 1. Guest users are rejected
# 2. Non-admin users are rejected
# 3. Missing user_id parameter is rejected
# 4. Invalid user_id is rejected
# 5. Non-infected users are handled gracefully
# 6. Successful cure operation
#############################################################################

# Get test users
my $test_user = $DB->getNode("normaluser1", "user");
ok($test_user, "Got test user normaluser1");

my $root = $DB->getNode("root", "user");
ok($root, "Got root (admin) user");

# Create API instance
my $api = Everything::API::user->new();
ok($api, "Created user API instance");

#############################################################################
# Test 1: Guest user blocked
#############################################################################
subtest "Guest user blocked" => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        is_guest_flag => 1,
        request_method => 'POST',
        postdata => { user_id => $test_user->{node_id} }
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false for guest");
};

#############################################################################
# Test 2: Non-admin user blocked
#############################################################################
subtest "Non-admin user blocked" => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => { user_id => $test_user->{node_id} }
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false for non-admin");
    like($response->[1]->{error}, qr/Admin/, "Error mentions admin requirement");
};

#############################################################################
# Test 3: Missing user_id parameter
#############################################################################
subtest "Missing user_id parameter" => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $root->{node_id},
        title => $root->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => {}  # No user_id
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false when user_id missing");
    like($response->[1]->{error}, qr/user_id/, "Error mentions missing user_id");
};

#############################################################################
# Test 4: Invalid user_id (non-numeric)
#############################################################################
subtest "Invalid user_id (non-numeric)" => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $root->{node_id},
        title => $root->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { user_id => 'not_a_number' }
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false for invalid user_id");
    like($response->[1]->{error}, qr/invalid user_id/, "Error mentions invalid user_id");
};

#############################################################################
# Test 5: User not found
#############################################################################
subtest "User not found" => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $root->{node_id},
        title => $root->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { user_id => 999999999 }  # Very unlikely to exist
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false for non-existent user");
    like($response->[1]->{error}, qr/not found/i, "Error mentions user not found");
};

#############################################################################
# Test 6: User not infected
#############################################################################
subtest "User not infected" => sub {
    plan tests => 3;

    # First ensure test_user is NOT infected
    my $vars = Everything::getVars($test_user);
    delete $vars->{infected};
    Everything::setVars($test_user, $vars);

    my $request = MockRequest->new(
        node_id => $root->{node_id},
        title => $root->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { user_id => $test_user->{node_id} }
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false for non-infected user");
    like($response->[1]->{error}, qr/not infected/i, "Error mentions user is not infected");
};

#############################################################################
# Test 7: Successful cure operation
#############################################################################
subtest "Successful cure operation" => sub {
    plan tests => 5;

    # First, infect the test_user
    my $vars = Everything::getVars($test_user);
    $vars->{infected} = 1;
    Everything::setVars($test_user, $vars);

    # Verify infection was set
    $vars = Everything::getVars($test_user);
    is($vars->{infected}, 1, "Test user is now infected");

    my $request = MockRequest->new(
        node_id => $root->{node_id},
        title => $root->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { user_id => $test_user->{node_id} }
    );

    my $response = $api->cure_infection($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 1, "Success is true");
    like($response->[1]->{message}, qr/cured/i, "Message mentions infection cured");

    # Verify infection was cleared
    # Need to refresh the node from DB
    $DB->{cache}->removeNode($test_user) if $DB->{cache};
    $test_user = $DB->getNode($test_user->{node_id});
    $vars = Everything::getVars($test_user);
    ok(!$vars->{infected}, "Test user is no longer infected");
};

#############################################################################
# Cleanup: Ensure test_user is not infected after tests
#############################################################################
{
    my $vars = Everything::getVars($test_user);
    delete $vars->{infected};
    Everything::setVars($test_user, $vars);
}

done_testing();

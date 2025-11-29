#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::user;

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
# Test User API functionality
#
# These tests verify:
# 1. GET /api/user/sanctity?username=<name> - Lookup user sanctity
# 2. Authorization checks (admin-only)
# 3. User lookup with underscore-to-space conversion
#############################################################################

# Get test users
my $test_user = $DB->getNode("normaluser1", "user");
ok($test_user, "Got test user normaluser1");

my $root = $DB->getNode("root", "user");
ok($root, "Got root user");

# Helper: Create a mock request object
package MockRequest {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub user { return $_[0]->{user} }
    sub Vars { return $_[0]->{vars} || {} }
    sub request_method { return $_[0]->{method} || 'GET' }
}

# Helper: Create a mock user object
package MockUser {
    sub new {
        my ($class, %args) = @_;
        my $self = {
            node_id => $args{node_id},
            user_id => $args{user_id},
            title => $args{title},
            is_admin_flag => $args{is_admin_flag} // 0,
            is_guest_flag => $args{is_guest_flag} // 0,
        };
        return bless $self, $class;
    }
}

# Create API instance
my $api = Everything::API::user->new();
ok($api, "Created user API instance");

#############################################################################
# Test 1: Non-admin user blocked
#############################################################################
subtest "Non-admin blocked" => sub {
    plan tests => 2;

    my $user = MockUser->new(
        node_id => $test_user->{node_id},
        user_id => $test_user->{user_id},
        title => $test_user->{title},
        is_admin_flag => 0
    );

    my $request = MockRequest->new(
        user => $user,
        vars => { username => 'root' }
    );

    my $response = $api->sanctity($request);

    is($response->[0], 403, "Returns 403 Forbidden");
    ok($response->[1]->{error} =~ /Admin/, "Error mentions admin requirement");
};

#############################################################################
# Test 2: Missing username parameter
#############################################################################
subtest "Missing username parameter" => sub {
    plan tests => 2;

    my $user = MockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = MockRequest->new(
        user => $user,
        vars => {}  # No username
    );

    my $response = $api->sanctity($request);

    is($response->[0], 400, "Returns 400 Bad Request");
    ok($response->[1]->{error} =~ /Username parameter required/, "Error mentions missing parameter");
};

#############################################################################
# Test 3: User not found
#############################################################################
subtest "User not found" => sub {
    plan tests => 2;

    my $user = MockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = MockRequest->new(
        user => $user,
        vars => { username => 'nonexistent_user_12345' }
    );

    my $response = $api->sanctity($request);

    is($response->[0], 404, "Returns 404 Not Found");
    ok($response->[1]->{error} =~ /not found/, "Error mentions user not found");
};

#############################################################################
# Test 4: Successful lookup
#############################################################################
subtest "Successful lookup" => sub {
    plan tests => 4;

    my $user = MockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = MockRequest->new(
        user => $user,
        vars => { username => 'root' }
    );

    my $response = $api->sanctity($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 1, "Success is true");
    is($response->[1]->{username}, 'root', "Returns correct username");
    ok(defined $response->[1]->{sanctity}, "Returns sanctity value");
};

#############################################################################
# Test 5: Lookup with underscore-to-space conversion
#############################################################################
subtest "Underscore to space conversion" => sub {
    plan tests => 2;

    # Create a user with space in name if it doesn't exist
    my $spaced_user = $DB->getNode("Cool Man Eddie", "user");
    skip "Cool Man Eddie not in database", 2 unless $spaced_user;

    my $user = MockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = MockRequest->new(
        user => $user,
        vars => { username => 'Cool_Man_Eddie' }  # Using underscores
    );

    my $response = $api->sanctity($request);

    is($response->[0], 200, "Returns 200 OK with underscore conversion");
    is($response->[1]->{username}, 'Cool Man Eddie', "Returns name with spaces");
};

done_testing();

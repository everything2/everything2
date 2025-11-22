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
use Everything::API::developervars;
use JSON;
use Data::Dumper;

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Developer Variables API functionality
#
# These tests verify:
# 1. GET /api/developervars/ - Get user VARS (developer-only)
# 2. Authorization checks (developer vs non-developer)
# 3. Proper VARS data structure returned
# 4. Used in production by Everything Developer nodelet
#############################################################################

# Get a developer user for API operations
my $dev_user = $DB->getNode("root", "user");
if (!$dev_user) {
    $dev_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "in_group=1 LIMIT 1");
}
ok($dev_user, "Got developer user for tests");
diag("Developer user ID: " . ($dev_user ? $dev_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Get a non-developer user for authorization tests
my $normal_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id WHERE node_id != " . $dev_user->{node_id} . " LIMIT 1");
if (!$normal_user) {
    # No other users in database, will use mock user for auth tests
    $normal_user = { node_id => 999998, title => 'normaluser' };
}
ok($normal_user, "Got non-developer user for authorization tests");
diag("Normal user ID: " . ($normal_user ? $normal_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'VARS' => (is => 'rw', default => sub { {} });
    has 'is_developer_flag' => (is => 'rw', default => 0);
    has 'is_admin_flag' => (is => 'rw', default => 0);
    sub is_developer { return shift->is_developer_flag; }
    sub is_admin { return shift->is_admin_flag; }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::developervars->new();
ok($api, "Created developervars API instance");

#############################################################################
# Test 1: Successful VARS retrieval (developer user)
#############################################################################

subtest 'Successful VARS retrieval by developer' => sub {
    plan tests => 7;

    # Create mock developer user with some VARS
    my $test_vars = {
        vit_hidenodeinfo => "1",
        num_newwus => "25",
        collapsedNodelets => "epicenter!readthis!",
        custom_setting => "test_value",
    };

    my $mock_user = MockUser->new(
        node_id => $dev_user->{node_id},
        title => $dev_user->{title},
        is_developer_flag => 1,
        VARS => $test_vars,
        NODEDATA => $dev_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get VARS
    my $result = $api->get_vars($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1], "GET returns response data");
    is(ref($result->[1]), 'HASH', "GET returns hash of VARS");

    # Verify VARS content
    is($result->[1]{vit_hidenodeinfo}, "1", "VARS includes vit_hidenodeinfo");
    is($result->[1]{num_newwus}, "25", "VARS includes num_newwus");
    is($result->[1]{collapsedNodelets}, "epicenter!readthis!", "VARS includes collapsedNodelets");
    is($result->[1]{custom_setting}, "test_value", "VARS includes custom setting");
};

#############################################################################
# Test 2: Authorization - non-developer cannot access
#############################################################################

subtest 'Authorization: non-developer cannot access' => sub {
    plan tests => 2;

    # Create mock non-developer user
    my $mock_user = MockUser->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title} || 'normaluser',
        is_developer_flag => 0,  # Not a developer
        VARS => { some_var => "value" },
        NODEDATA => $normal_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to get VARS (should fail)
    my $result = $api->get_vars($mock_request);
    is($result->[0], 401, "Non-developer gets HTTP 401 Unauthorized");
    ok(!ref($result->[1]) || !exists($result->[1]{vit_hidenodeinfo}), "Non-developer doesn't get VARS data");
};

#############################################################################
# Test 3: Empty VARS
#############################################################################

subtest 'Empty VARS returns empty hash' => sub {
    plan tests => 3;

    # Create mock developer user with no VARS
    my $mock_user = MockUser->new(
        node_id => $dev_user->{node_id},
        title => $dev_user->{title},
        is_developer_flag => 1,
        VARS => {},  # Empty VARS
        NODEDATA => $dev_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get VARS
    my $result = $api->get_vars($mock_request);
    is($result->[0], 200, "GET returns HTTP 200 for empty VARS");
    is(ref($result->[1]), 'HASH', "GET returns hash");
    is(scalar(keys %{$result->[1]}), 0, "Hash is empty when user has no VARS");
};

#############################################################################
# Test 4: VARS with various data types
#############################################################################

subtest 'VARS with various data types' => sub {
    plan tests => 6;

    # Create mock developer user with various VARS types
    my $test_vars = {
        string_var => "string value",
        numeric_var => 42,
        boolean_true => 1,
        boolean_false => 0,
        empty_string => "",
    };

    my $mock_user = MockUser->new(
        node_id => $dev_user->{node_id},
        title => $dev_user->{title},
        is_developer_flag => 1,
        VARS => $test_vars,
        NODEDATA => $dev_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get VARS
    my $result = $api->get_vars($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");

    # Verify various data types are preserved
    is($result->[1]{string_var}, "string value", "String VARS preserved");
    is($result->[1]{numeric_var}, 42, "Numeric VARS preserved");
    is($result->[1]{boolean_true}, 1, "Boolean true VARS preserved");
    is($result->[1]{boolean_false}, 0, "Boolean false VARS preserved");
    is($result->[1]{empty_string}, "", "Empty string VARS preserved");
};

#############################################################################
# Test 5: Production usage - Everything Developer nodelet integration
#############################################################################

subtest 'Production usage verification' => sub {
    plan tests => 3;

    # This test verifies the API works for the production use case:
    # Everything Developer nodelet displays user VARS in a modal dialog

    my $test_vars = {
        vit_hidemaintenance => "0",
        vit_hidenodeinfo => "1",
        num_newwus => "15",
        collapsedNodelets => "epicenter!",
    };

    my $mock_user = MockUser->new(
        node_id => $dev_user->{node_id},
        title => $dev_user->{title},
        is_developer_flag => 1,
        VARS => $test_vars,
        NODEDATA => $dev_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    my $result = $api->get_vars($mock_request);
    is($result->[0], 200, "Production use case returns HTTP 200");
    is(ref($result->[1]), 'HASH', "Returns hash suitable for modal display");

    # Verify all expected preference keys are returned
    my $returned_keys = scalar(keys %{$result->[1]});
    is($returned_keys, 4, "All VARS keys returned for modal display");
};

done_testing();

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
use Everything::API::preferences;
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
# Test Preferences API functionality
#
# These tests verify:
# 1. GET /api/preferences/get - Get all preferences with defaults
# 2. POST /api/preferences/set - Set preferences with validation
# 3. Authorization checks (guest users blocked)
# 4. Validation (invalid keys and values rejected)
# 5. Default value handling and deletion
# 6. Critical for React UI state management
#############################################################################

# Get a normal user for API operations
my $test_user = $DB->getNode("normaluser1", "user");
if (!$test_user) {
    $test_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "node_id > 1 LIMIT 1");
}
ok($test_user, "Got test user for tests");
diag("Test user ID: " . ($test_user ? $test_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

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
    has 'is_guest_flag' => (is => 'rw', default => 0);
    sub is_guest { return shift->is_guest_flag; }
    sub set_vars {
        my ($self, $vars) = @_;
        $self->VARS($vars);
        return 1;
    }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    has '_postdata' => (is => 'rw', default => sub { {} });
    sub JSON_POSTDATA { return shift->_postdata; }
    sub is_guest { return shift->user->is_guest; }
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::preferences->new();
ok($api, "Created preferences API instance");

#############################################################################
# Test 1: Get preferences with defaults (logged in user)
#############################################################################

subtest 'Get preferences returns all allowed preferences with defaults' => sub {
    plan tests => 13;

    # Create mock user with no preferences set
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get preferences
    my $result = $api->get_preferences($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1], "GET returns response data");
    is(ref($result->[1]), 'HASH', "GET returns hash of preferences");

    # Verify all expected preference keys are present with defaults
    is($result->[1]{vit_hidemaintenance}, 0, "vit_hidemaintenance defaults to 0");
    is($result->[1]{vit_hidenodeinfo}, 0, "vit_hidenodeinfo defaults to 0");
    is($result->[1]{vit_hidenodeutil}, 0, "vit_hidenodeutil defaults to 0");
    is($result->[1]{vit_hidelist}, 0, "vit_hidelist defaults to 0");
    is($result->[1]{vit_hidemisc}, 0, "vit_hidemisc defaults to 0");
    is($result->[1]{edn_hideutil}, 0, "edn_hideutil defaults to 0");
    is($result->[1]{edn_hideedev}, 0, "edn_hideedev defaults to 0");
    is($result->[1]{nw_nojunk}, 0, "nw_nojunk defaults to 0");
    is($result->[1]{num_newwus}, 15, "num_newwus defaults to 15");
    is($result->[1]{collapsedNodelets}, '', "collapsedNodelets defaults to empty string");
};

#############################################################################
# Test 2: Get preferences with user-set values
#############################################################################

subtest 'Get preferences returns user-set values' => sub {
    plan tests => 6;

    # Create mock user with some preferences set
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {
            vit_hidenodeinfo => 1,
            num_newwus => 25,
            collapsedNodelets => "epicenter!readthis!",
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get preferences
    my $result = $api->get_preferences($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    is(ref($result->[1]), 'HASH', "GET returns hash");

    # Verify user-set values are returned
    is($result->[1]{vit_hidenodeinfo}, 1, "User-set vit_hidenodeinfo returned");
    is($result->[1]{num_newwus}, 25, "User-set num_newwus returned");
    is($result->[1]{collapsedNodelets}, "epicenter!readthis!", "User-set collapsedNodelets returned");

    # Verify unset preferences still return defaults
    is($result->[1]{vit_hidemaintenance}, 0, "Unset preference returns default");
};

#############################################################################
# Test 3: Set preferences successfully
#############################################################################

subtest 'Set preferences updates user VARS' => sub {
    plan tests => 6;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            vit_hidenodeinfo => 1,
            num_newwus => 30,
            collapsedNodelets => "test!",
        },
    );

    # Set preferences
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 200, "SET returns HTTP 200");
    is(ref($result->[1]), 'HASH', "SET returns hash of all preferences");

    # Verify set values are returned
    is($result->[1]{vit_hidenodeinfo}, 1, "Set value returned");
    is($result->[1]{num_newwus}, 30, "Set value returned");
    is($result->[1]{collapsedNodelets}, "test!", "Set value returned");

    # Verify VARS were updated
    is($mock_user->VARS->{vit_hidenodeinfo}, 1, "User VARS updated");
};

#############################################################################
# Test 4: Set preferences validation - invalid key
#############################################################################

subtest 'Set preferences rejects invalid keys' => sub {
    plan tests => 2;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            invalid_preference_key => 1,
        },
    );

    # Try to set invalid preference (should fail)
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 401, "SET returns HTTP 401 for invalid key");

    # Verify VARS not updated
    ok(!exists($mock_user->VARS->{invalid_preference_key}), "Invalid key not added to VARS");
};

#############################################################################
# Test 5: Set preferences validation - invalid value
#############################################################################

subtest 'Set preferences rejects invalid values' => sub {
    plan tests => 2;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            num_newwus => 999,  # Not in allowed values list
        },
    );

    # Try to set invalid value (should fail)
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 401, "SET returns HTTP 401 for invalid value");

    # Verify VARS not updated
    ok(!exists($mock_user->VARS->{num_newwus}), "Invalid value not added to VARS");
};

#############################################################################
# Test 6: Set preferences to default value deletes from VARS
#############################################################################

subtest 'Set preferences to default deletes from VARS' => sub {
    plan tests => 5;

    # Create mock user with preference set
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {
            num_newwus => 25,
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            num_newwus => 15,  # Default value
        },
    );

    # Verify preference exists before
    ok(exists($mock_user->VARS->{num_newwus}), "Preference exists before SET");

    # Set to default value
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 200, "SET returns HTTP 200");
    is($result->[1]{num_newwus}, 15, "Response shows default value");

    # Verify preference deleted from VARS
    ok(!exists($mock_user->VARS->{num_newwus}), "Preference deleted from VARS when set to default");

    # Verify GET still returns default
    my $get_result = $api->get_preferences($mock_request);
    is($get_result->[1]{num_newwus}, 15, "GET still returns default after deletion");
};

#############################################################################
# Test 7: Set empty string deletes String preference
#############################################################################

subtest 'Set empty string deletes String preference' => sub {
    plan tests => 5;

    # Create mock user with collapsedNodelets set
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {
            collapsedNodelets => "epicenter!readthis!",
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            collapsedNodelets => "",  # Empty string
        },
    );

    # Verify preference exists before
    ok(exists($mock_user->VARS->{collapsedNodelets}), "Preference exists before SET");

    # Set to empty string
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 200, "SET returns HTTP 200");
    is($result->[1]{collapsedNodelets}, '', "Response shows empty string");

    # Verify preference deleted from VARS
    ok(!exists($mock_user->VARS->{collapsedNodelets}), "Preference deleted from VARS when set to empty");

    # Verify GET still returns default (empty string)
    my $get_result = $api->get_preferences($mock_request);
    is($get_result->[1]{collapsedNodelets}, '', "GET still returns default after deletion");
};

#############################################################################
# Test 8: Authorization - guest user blocked from SET
#############################################################################

subtest 'Authorization: guest user cannot set preferences' => sub {
    plan tests => 2;

    # Create mock guest user
    my $mock_user = MockUser->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,  # Guest user
        VARS => {},
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            vit_hidenodeinfo => 1,
        },
    );

    # Try to set preferences (should fail)
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 401, "Guest user gets HTTP 401");

    # Verify VARS not updated
    ok(!exists($mock_user->VARS->{vit_hidenodeinfo}), "Guest user VARS not updated");
};

#############################################################################
# Test 9: Set multiple preferences at once
#############################################################################

subtest 'Set multiple preferences in single request' => sub {
    plan tests => 6;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            vit_hidenodeinfo => 1,
            vit_hidemaintenance => 1,
            num_newwus => 20,
        },
    );

    # Set multiple preferences
    my $result = $api->set_preferences($mock_request);
    is($result->[0], 200, "SET returns HTTP 200");

    # Verify all values are set and returned
    is($result->[1]{vit_hidenodeinfo}, 1, "First preference set");
    is($result->[1]{vit_hidemaintenance}, 1, "Second preference set");
    is($result->[1]{num_newwus}, 20, "Third preference set");

    # Verify VARS updated
    is($mock_user->VARS->{vit_hidenodeinfo}, 1, "First VARS updated");
    is($mock_user->VARS->{vit_hidemaintenance}, 1, "Second VARS updated");
};

#############################################################################
# Test 10: Bad request handling
#############################################################################

subtest 'Set preferences rejects bad requests' => sub {
    plan tests => 3;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );

    # Test empty request
    my $mock_request1 = MockRequest->new(
        user => $mock_user,
        _postdata => {},
    );
    my $result1 = $api->set_preferences($mock_request1);
    is($result1->[0], 400, "Empty POST data returns HTTP 400");

    # Test non-hash data
    my $mock_request2 = MockRequest->new(
        user => $mock_user,
        _postdata => "not a hash",
    );
    my $result2 = $api->set_preferences($mock_request2);
    is($result2->[0], 400, "Non-hash POST data returns HTTP 400");

    # Test array data
    my $mock_request3 = MockRequest->new(
        user => $mock_user,
        _postdata => [],
    );
    my $result3 = $api->set_preferences($mock_request3);
    is($result3->[0], 400, "Array POST data returns HTTP 400");
};

done_testing();

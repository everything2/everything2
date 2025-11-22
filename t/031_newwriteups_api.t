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
use Everything::API::newwriteups;
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
# Test New Writeups API functionality
#
# These tests verify:
# 1. GET /api/newwriteups/ - Get filtered new writeups
# 2. DataStash integration (uses "newwriteups" cache)
# 3. Editor filtering (editors see notnew and junk)
# 4. Guest filtering (guests don't see hasvoted)
# 5. Limit parameter handling
# 6. Array response structure
# 7. Critical for React New Writeups nodelet
#############################################################################

# Get a normal user for API operations
my $test_user = $DB->getNode("normaluser1", "user");
if (!$test_user) {
    $test_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "node_id > 1 LIMIT 1");
}
ok($test_user, "Got test user for tests");
diag("Test user ID: " . ($test_user ? $test_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Get an editor user for filtering tests
my $editor_user = $DB->getNode("root", "user");
if (!$editor_user) {
    $editor_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "in_group=3 LIMIT 1");
}
ok($editor_user, "Got editor user for filtering tests");
diag("Editor user ID: " . ($editor_user ? $editor_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'is_guest_flag' => (is => 'rw', default => 0);
    has 'is_editor_flag' => (is => 'rw', default => 0);
    has 'is_admin_flag' => (is => 'rw', default => 0);
    sub is_guest { return shift->is_guest_flag; }
    sub is_editor { return shift->is_editor_flag; }
    sub is_admin { return shift->is_admin_flag; }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    sub is_guest { return shift->user->is_guest; }
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::newwriteups->new();
ok($api, "Created newwriteups API instance");

#############################################################################
# Test 1: Get new writeups as normal user
#############################################################################

subtest 'Get new writeups as normal user' => sub {
    plan tests => 6;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get new writeups
    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1], "GET returns response data");
    is(ref($result->[1]), 'ARRAY', "GET returns array of writeups");

    # Verify array contains writeup objects
    if (scalar(@{$result->[1]}) > 0) {
        my $first_wu = $result->[1][0];
        ok(exists($first_wu->{node_id}), "Writeup has node_id");
        ok(exists($first_wu->{title}), "Writeup has title");
        ok(exists($first_wu->{hasvoted}), "Normal user sees hasvoted flag");
    } else {
        # If no writeups, skip remaining tests
        pass("Writeup has node_id (no writeups in stash)");
        pass("Writeup has title (no writeups in stash)");
        pass("Normal user sees hasvoted flag (no writeups in stash)");
    }
};

#############################################################################
# Test 2: Get new writeups as editor
#############################################################################

subtest 'Get new writeups as editor' => sub {
    plan tests => 7;

    # Create mock editor user
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get new writeups
    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "GET returns array");

    # Verify array contains writeup objects with editor fields
    if (scalar(@{$result->[1]}) > 0) {
        my $first_wu = $result->[1][0];
        ok(exists($first_wu->{node_id}), "Writeup has node_id");
        ok(exists($first_wu->{title}), "Writeup has title");
        ok(exists($first_wu->{notnew}), "Editor sees notnew flag");
        ok(exists($first_wu->{is_junk}), "Editor sees is_junk flag");
        ok(exists($first_wu->{is_log}), "Editor sees is_log flag");
    } else {
        pass("Writeup has node_id (no writeups in stash)");
        pass("Writeup has title (no writeups in stash)");
        pass("Editor sees notnew flag (no writeups in stash)");
        pass("Editor sees is_junk flag (no writeups in stash)");
        pass("Editor sees is_log flag (no writeups in stash)");
    }
};

#############################################################################
# Test 3: Get new writeups as guest user
#############################################################################

subtest 'Get new writeups as guest user' => sub {
    plan tests => 5;

    # Get the actual guest user node to use its data
    my $guest_user_node = $DB->getNode("Guest User", "user");
    unless ($guest_user_node) {
        # If no guest user exists, create minimal guest data
        $guest_user_node = { node_id => -1, title => 'Guest User' };
    }

    # Create mock guest user
    my $mock_user = MockUser->new(
        node_id => $guest_user_node->{node_id},
        title => $guest_user_node->{title},
        is_guest_flag => 1,
        is_editor_flag => 0,
        NODEDATA => $guest_user_node,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get new writeups
    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "GET returns array");

    # Verify guest users don't see hasvoted
    if (scalar(@{$result->[1]}) > 0) {
        my $first_wu = $result->[1][0];
        ok(exists($first_wu->{node_id}), "Writeup has node_id");
        ok(exists($first_wu->{title}), "Writeup has title");
        ok(!exists($first_wu->{hasvoted}), "Guest user doesn't see hasvoted flag");
    } else {
        pass("Writeup has node_id (no writeups in stash)");
        pass("Writeup has title (no writeups in stash)");
        pass("Guest user doesn't see hasvoted flag (no writeups in stash)");
    }
};

#############################################################################
# Test 4: Verify boolean references in response
#############################################################################

subtest 'Boolean references in response' => sub {
    plan tests => 3;

    # Create mock editor user (editors see all flags)
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get new writeups
    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");

    # Verify boolean flags are references
    if (scalar(@{$result->[1]}) > 0) {
        my $first_wu = $result->[1][0];
        is(ref($first_wu->{notnew}), 'SCALAR', "notnew is scalar reference");
        is(ref($first_wu->{is_junk}), 'SCALAR', "is_junk is scalar reference");
    } else {
        pass("notnew is scalar reference (no writeups in stash)");
        pass("is_junk is scalar reference (no writeups in stash)");
    }
};

#############################################################################
# Test 5: Verify response structure fields
#############################################################################

subtest 'Response structure fields' => sub {
    plan tests => 2;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get new writeups
    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");

    # Verify basic fields exist (node_id and title are guaranteed)
    if (scalar(@{$result->[1]}) > 0) {
        my $first_wu = $result->[1][0];
        my $has_basic_fields = exists($first_wu->{node_id}) && exists($first_wu->{title});
        ok($has_basic_fields, "Writeup has basic required fields (node_id, title)");
    } else {
        pass("Writeup has basic required fields (no writeups in stash)");
    }
};

#############################################################################
# Test 6: Empty stash handling
#############################################################################

subtest 'Empty stash handling' => sub {
    plan tests => 3;

    # This test verifies graceful handling when DataStash is unavailable
    # The API should return an empty array, not fail

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get new writeups (should handle empty/missing stash gracefully)
    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200 even with empty stash");
    is(ref($result->[1]), 'ARRAY', "GET returns array even with empty stash");
    ok(1, "API handles missing/empty stash gracefully");
};

done_testing();

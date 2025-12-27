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
use Everything::API::nodelets;
use JSON;

# Suppress expected warnings
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
# Test Nodelets API functionality
#
# These tests verify:
# 1. GET /api/nodelets - Get user's nodelet order
# 2. POST /api/nodelets - Update nodelet order
# 3. Authorization checks (guest users blocked)
# 4. Validation (nodelet IDs must be valid)
#############################################################################

# Get test user (use e2e_user instead of root to avoid modifying root's settings)
my $test_user = $DB->getNode("e2e_user", "user");
ok($test_user, "Got test user (e2e_user)");

# Get original nodelet order
my $VARS = Everything::getVars($test_user);
my $original_order = $VARS->{nodelets};
ok($original_order, "User has nodelet order configured");
diag("Original nodelet order: $original_order") if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw', default => 0);
    has 'title' => (is => 'rw', default => 'guest');
    has 'is_guest' => (is => 'rw', default => 1);
    has 'is_admin' => (is => 'rw', default => 0);

    sub new_from_node {
        my ($class, $node) = @_;
        return $class->new(
            NODEDATA => $node,
            node_id => $node->{node_id},
            title => $node->{title},
            is_guest => 0,
            is_admin => 0  # Not needed for nodelet tests
        );
    }
}

# Mock Request object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw');
    has 'POSTDATA' => (is => 'rw', default => '');
    has 'VARS' => (is => 'rw', default => sub { {} });
    has '_method' => (is => 'rw', default => 'GET');

    sub request_method { return shift->{_method}; }
}

package main;

#############################################################################
# Test GET /api/nodelets
#############################################################################

{
    my $api = Everything::API::nodelets->new(DB => $DB, APP => $APP);
    my $mock_user = MockUser->new_from_node($test_user);
    my $mock_request = MockRequest->new(
        user => $mock_user,
        VARS => $VARS,
        _method => 'GET'
    );

    my ($status, $data) = @{$api->get_nodelets($mock_request)};

    is($status, 200, 'GET /api/nodelets returns 200');
    ok($data->{success}, 'Response has success flag');
    ok(ref($data->{nodelets}) eq 'ARRAY', 'Returns array of nodelets');
    ok(scalar(@{$data->{nodelets}}) > 0, 'Returns at least one nodelet');

    # Verify structure of nodelet objects
    my $first_nodelet = $data->{nodelets}->[0];
    ok($first_nodelet->{node_id}, 'Nodelet has node_id');
    ok($first_nodelet->{title}, 'Nodelet has title');

    diag("GET returned " . scalar(@{$data->{nodelets}}) . " nodelets") if $ENV{TEST_VERBOSE};
}

#############################################################################
# Test POST /api/nodelets (update nodelet order)
#############################################################################

{
    my $api = Everything::API::nodelets->new(DB => $DB, APP => $APP);
    my $mock_user = MockUser->new_from_node($test_user);

    # Reverse the nodelet order as a test
    my @nodelet_ids = split(/,/, $original_order);
    my @reversed_ids = reverse @nodelet_ids;

    my $json_body = JSON::encode_json({ nodelet_ids => \@reversed_ids });
    my $mock_request = MockRequest->new(
        user => $mock_user,
        POSTDATA => $json_body,
        VARS => $VARS,
        _method => 'POST'
    );

    my ($status, $data) = @{$api->update_nodelets($mock_request)};

    is($status, 200, 'POST /api/nodelets returns 200');
    ok($data->{success}, 'Response has success flag');

    # Verify the order was updated in the database
    my $updated_user = $DB->getNode($test_user->{node_id});
    my $updated_VARS = Everything::getVars($updated_user);
    my $new_order = $updated_VARS->{nodelets};
    my $expected_order = join(',', @reversed_ids);

    is($new_order, $expected_order, 'Nodelet order was updated correctly');

    diag("Updated nodelet order: $new_order") if $ENV{TEST_VERBOSE};

    # Restore original order
    Everything::setVars($test_user, { nodelets => $original_order });
    $DB->updateNode($test_user, -1);

    # Verify restoration
    my $restored_user = $DB->getNode($test_user->{node_id});
    my $restored_VARS = Everything::getVars($restored_user);
    is($restored_VARS->{nodelets}, $original_order, 'Original nodelet order restored');
}

#############################################################################
# Test validation - invalid nodelet ID
#############################################################################

{
    my $api = Everything::API::nodelets->new(DB => $DB, APP => $APP);
    my $mock_user = MockUser->new_from_node($test_user);

    my $json_body = JSON::encode_json({ nodelet_ids => [999999999] });
    my $mock_request = MockRequest->new(
        user => $mock_user,
        POSTDATA => $json_body,
        VARS => $VARS,
        _method => 'POST'
    );

    my ($status, $data) = @{$api->update_nodelets($mock_request)};

    is($status, 404, 'POST with invalid nodelet ID returns 404');
    ok(!$data->{success}, 'Response has success=false');
    ok($data->{error}, 'Response has error message');
}

#############################################################################
# Test validation - invalid JSON
#############################################################################

{
    my $api = Everything::API::nodelets->new(DB => $DB, APP => $APP);
    my $mock_user = MockUser->new_from_node($test_user);

    my $mock_request = MockRequest->new(
        user => $mock_user,
        POSTDATA => 'invalid json{',
        VARS => $VARS,
        _method => 'POST'
    );

    my ($status, $data) = @{$api->update_nodelets($mock_request)};

    is($status, 400, 'POST with invalid JSON returns 400');
    ok(!$data->{success}, 'Response has success=false');
    is($data->{error}, 'invalid_json', 'Error code is invalid_json');
}

done_testing();

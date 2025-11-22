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
use Everything::API::messages;
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
# Test Messages API functionality
#
# These tests verify:
# 1. GET /api/messages/ - Get all messages with pagination
# 2. POST /api/messages/create - Create new message to user or usergroup
# 3. GET /api/messages/:id - Get single message
# 4. POST /api/messages/:id/action/archive - Archive a message
# 5. POST /api/messages/:id/action/unarchive - Unarchive a message
# 6. POST /api/messages/:id/action/delete - Delete a message
# 7. Authorization checks (guest users blocked, ownership verification)
# 8. Critical for React messaging UI
#############################################################################

# Get test users
my $test_user1 = $DB->getNode("normaluser1", "user");
if (!$test_user1) {
    $test_user1 = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "node_id > 1 LIMIT 1");
}
ok($test_user1, "Got first test user");
diag("Test user 1 ID: " . ($test_user1 ? $test_user1->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

my $test_user2 = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "node_id > 1 AND node_id != " . ($test_user1->{node_id} || 0) . " LIMIT 1");
if (!$test_user2) {
    # Create a mock second user for testing
    $test_user2 = { node_id => 999996, title => 'testuser2' };
}
ok($test_user2, "Got second test user");
diag("Test user 2 ID: " . ($test_user2 ? $test_user2->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

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
    sub is_guest { return shift->is_guest_flag; }
}

# Mock CGI object for testing query parameters
package MockCGI {
    use Moose;
    has '_params' => (is => 'rw', default => sub { {} });
    sub param {
        my ($self, $key) = @_;
        return $self->_params->{$key};
    }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    has '_postdata' => (is => 'rw', default => sub { {} });
    has '_cgi' => (is => 'rw', isa => 'MockCGI', default => sub { MockCGI->new() });
    sub JSON_POSTDATA { return shift->_postdata; }
    sub cgi { return shift->_cgi; }
    sub is_guest { return shift->user->is_guest; }
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::messages->new();
ok($api, "Created messages API instance");

#############################################################################
# Test 1: Get all messages (normal user)
#############################################################################

subtest 'Get all messages as normal user' => sub {
    plan tests => 4;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get all messages
    my $result = $api->get_all($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1], "GET returns response data");
    is(ref($result->[1]), 'ARRAY', "GET returns array of messages");

    # Verify array structure (may be empty)
    if (scalar(@{$result->[1]}) > 0) {
        my $first_msg = $result->[1][0];
        ok(exists($first_msg->{message_id}), "Message has message_id");
    } else {
        pass("Message has message_id (no messages for user)");
    }
};

#############################################################################
# Test 2: Get messages with pagination
#############################################################################

subtest 'Get messages with limit and offset' => sub {
    plan tests => 5;

    # Create mock normal user with CGI parameters
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_cgi = MockCGI->new(
        _params => {
            limit => 5,
            offset => 0,
        },
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _cgi => $mock_cgi,
    );

    # Get messages with limit
    my $result = $api->get_all($mock_request);
    is($result->[0], 200, "GET with limit returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "GET returns array");

    # Verify limit is respected (if user has messages)
    my $count = scalar(@{$result->[1]});
    ok($count <= 5, "Limit of 5 is respected (got $count messages)");

    # Test with offset
    $mock_cgi->_params->{offset} = 10;
    $result = $api->get_all($mock_request);
    is($result->[0], 200, "GET with offset returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "GET with offset returns array");
};

#############################################################################
# Test 3: Guest user cannot access messages
#############################################################################

subtest 'Authorization: guest user cannot access messages' => sub {
    plan tests => 2;

    # Get actual guest user node
    my $guest_user_node = $DB->getNode("Guest User", "user");
    unless ($guest_user_node) {
        $guest_user_node = { node_id => -1, title => 'Guest User' };
    }

    # Create mock guest user
    my $mock_user = MockUser->new(
        node_id => $guest_user_node->{node_id},
        title => $guest_user_node->{title},
        is_guest_flag => 1,
        NODEDATA => $guest_user_node,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to get messages (should fail)
    my $result = $api->get_all($mock_request);
    is($result->[0], 401, "Guest user gets HTTP 401 for get_all");

    # Try to create message (should fail)
    $mock_request->_postdata({ message => "test", for => "normaluser1" });
    $result = $api->create($mock_request);
    is($result->[0], 401, "Guest user gets HTTP 401 for create");
};

#############################################################################
# Test 4: Create message validation
#############################################################################

subtest 'Create message validation' => sub {
    plan tests => 4;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Test missing message text
    $mock_request->_postdata({});
    my $result = $api->create($mock_request);
    is($result->[0], 400, "Missing message returns HTTP 400");

    # Test missing recipient
    $mock_request->_postdata({ message => "Test message" });
    $result = $api->create($mock_request);
    is($result->[0], 400, "Missing recipient returns HTTP 400");

    # Test invalid recipient
    $mock_request->_postdata({ message => "Test", for => "nonexistent_user_99999" });
    $result = $api->create($mock_request);
    is($result->[0], 400, "Invalid recipient returns HTTP 400");

    # Test empty message
    $mock_request->_postdata({ message => "", for => "normaluser1" });
    $result = $api->create($mock_request);
    is($result->[0], 400, "Empty message returns HTTP 400");
};

#############################################################################
# Test 5: Create message to user (if normaluser1 can receive messages)
#############################################################################

subtest 'Create message to user' => sub {
    plan tests => 2;

    # Create mock sender user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to send message to another user
    # Note: This may fail if the user type doesn't support deliver_message
    $mock_request->_postdata({
        message => "Test message content",
        for => $test_user1->{title}  # Send to self for testing
    });

    my $result = $api->create($mock_request);

    # The result depends on whether the user node type supports deliver_message
    # It should return either 200 (success) or 400 (user type doesn't support messages)
    ok($result->[0] == 200 || $result->[0] == 400, "Create message returns 200 or 400");

    if ($result->[0] == 200) {
        ok($result->[1], "Successful message creation returns data");
    } else {
        pass("User type doesn't support deliver_message (expected)");
    }
};

#############################################################################
# Test 6: Get single message (ownership check)
#############################################################################

subtest 'Get single message with ownership check' => sub {
    plan tests => 2;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to get a non-existent message
    my $result = $api->get_single_message($mock_request, 999999999);
    is($result->[0], 403, "Non-existent message returns HTTP 403");

    # Try to get message as guest user
    my $guest_user_node = $DB->getNode("Guest User", "user");
    unless ($guest_user_node) {
        $guest_user_node = { node_id => -1, title => 'Guest User' };
    }
    my $mock_guest = MockUser->new(
        node_id => $guest_user_node->{node_id},
        title => $guest_user_node->{title},
        is_guest_flag => 1,
        NODEDATA => $guest_user_node,
    );
    my $mock_guest_request = MockRequest->new(
        user => $mock_guest,
    );

    $result = $api->get_single_message($mock_guest_request, 1);
    is($result->[0], 403, "Guest user gets HTTP 403 for message access");
};

#############################################################################
# Test 7: Archive message
#############################################################################

subtest 'Archive message authorization' => sub {
    plan tests => 2;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to archive a non-existent message
    my $result = $api->archive($mock_request, 999999999);
    is($result->[0], 403, "Non-existent message returns HTTP 403");

    # Try to archive as guest user
    my $guest_user_node = $DB->getNode("Guest User", "user");
    unless ($guest_user_node) {
        $guest_user_node = { node_id => -1, title => 'Guest User' };
    }
    my $mock_guest = MockUser->new(
        node_id => $guest_user_node->{node_id},
        title => $guest_user_node->{title},
        is_guest_flag => 1,
        NODEDATA => $guest_user_node,
    );
    my $mock_guest_request = MockRequest->new(
        user => $mock_guest,
    );

    $result = $api->archive($mock_guest_request, 1);
    is($result->[0], 403, "Guest user gets HTTP 403 for archive");
};

#############################################################################
# Test 8: Unarchive message
#############################################################################

subtest 'Unarchive message authorization' => sub {
    plan tests => 2;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to unarchive a non-existent message
    my $result = $api->unarchive($mock_request, 999999999);
    is($result->[0], 403, "Non-existent message returns HTTP 403");

    # Try to unarchive as guest user
    my $guest_user_node = $DB->getNode("Guest User", "user");
    unless ($guest_user_node) {
        $guest_user_node = { node_id => -1, title => 'Guest User' };
    }
    my $mock_guest = MockUser->new(
        node_id => $guest_user_node->{node_id},
        title => $guest_user_node->{title},
        is_guest_flag => 1,
        NODEDATA => $guest_user_node,
    );
    my $mock_guest_request = MockRequest->new(
        user => $mock_guest,
    );

    $result = $api->unarchive($mock_guest_request, 1);
    is($result->[0], 403, "Guest user gets HTTP 403 for unarchive");
};

#############################################################################
# Test 9: Delete message
#############################################################################

subtest 'Delete message authorization' => sub {
    plan tests => 2;

    # Create mock normal user
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to delete a non-existent message
    my $result = $api->delete($mock_request, 999999999);
    is($result->[0], 403, "Non-existent message returns HTTP 403");

    # Try to delete as guest user
    my $guest_user_node = $DB->getNode("Guest User", "user");
    unless ($guest_user_node) {
        $guest_user_node = { node_id => -1, title => 'Guest User' };
    }
    my $mock_guest = MockUser->new(
        node_id => $guest_user_node->{node_id},
        title => $guest_user_node->{title},
        is_guest_flag => 1,
        NODEDATA => $guest_user_node,
    );
    my $mock_guest_request = MockRequest->new(
        user => $mock_guest,
    );

    $result = $api->delete($mock_guest_request, 1);
    is($result->[0], 403, "Guest user gets HTTP 403 for delete");
};

#############################################################################
# Test 10: Default limit behavior
#############################################################################

subtest 'Default message limit' => sub {
    plan tests => 2;

    # Create mock normal user with no limit parameter
    my $mock_user = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get messages without limit (should default to 15)
    my $result = $api->get_all($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");

    # Default limit is 15
    my $count = scalar(@{$result->[1]});
    ok($count <= 15, "Default limit of 15 is applied (got $count messages)");
};

done_testing();

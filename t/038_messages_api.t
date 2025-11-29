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

# Get test users - use known existing users for reliable testing
my $test_user1 = $DB->getNode("root", "user");
ok($test_user1, "Got first test user (root)");
diag("Test user 1 ID: " . ($test_user1 ? $test_user1->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

my $test_user2 = $DB->getNode("guest user", "user");
ok($test_user2, "Got second test user (guest user)");
diag("Test user 2 ID: " . ($test_user2 ? $test_user2->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Verify both users exist in node table
my $user1_node = $DB->getNodeById($test_user1->{node_id});
my $user2_node = $DB->getNodeById($test_user2->{node_id});
ok($user1_node, "User 1 exists in node table");
ok($user2_node, "User 2 exists in node table");

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

#############################################################################
# Test 11: Cross-user message permissions (CRITICAL SECURITY TEST)
#############################################################################

subtest 'User cannot delete/archive messages sent to other users' => sub {
    plan tests => 14;  # 2 create + 8 checks (4 ops × 2 each) + 2 verify + 2 recipient

    # Create an actual message in the database from user1 to user2
    my $insert_ok = $DB->sqlInsert('message', {
        author_user => $test_user1->{node_id},
        for_user => $test_user2->{node_id},
        msgtext => 'Test message for permission check',
        '-tstamp' => 'NOW()',  # Leading dash means raw SQL, not quoted
        archive => 0
    });
    ok($insert_ok, 'Message insert successful');

    # Get the actual message ID
    my ($message_id) = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($message_id, 'Got message ID');

    # Create mock request for sender (user1)
    my $mock_sender = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );
    my $mock_sender_request = MockRequest->new(
        user => $mock_sender,
    );

    # TEST: Sender (user1) cannot delete message sent to user2
    my $result = $api->delete($mock_sender_request, $message_id);
    is($result->[0], 403, "Sender cannot delete message sent to another user");
    my $check = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    ok($check, "Message still exists after delete attempt");

    # TEST: Sender (user1) cannot archive message sent to user2
    $result = $api->archive($mock_sender_request, $message_id);
    is($result->[0], 403, "Sender cannot archive message sent to another user");
    $check = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    ok($check, "Message still exists after archive attempt");

    # TEST: Sender (user1) cannot unarchive message sent to user2
    $result = $api->unarchive($mock_sender_request, $message_id);
    is($result->[0], 403, "Sender cannot unarchive message sent to another user");
    $check = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    ok($check, "Message still exists after unarchive attempt");

    # TEST: Sender (user1) cannot get message sent to user2
    $result = $api->get_single_message($mock_sender_request, $message_id);
    is($result->[0], 403, "Sender cannot view message sent to another user");
    $check = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    ok($check, "Message still exists after get attempt");

    # Verify message still exists and is not archived
    my $message = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    ok($message, 'Message still exists after unauthorized operations');
    is($message->{archive}, 0, 'Message is still not archived');

    # Create mock request for recipient (user2)
    my $mock_recipient = MockUser->new(
        node_id => $test_user2->{node_id},
        title => $test_user2->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user2,
    );
    my $mock_recipient_request = MockRequest->new(
        user => $mock_recipient,
    );

    # TEST: Recipient (user2) CAN delete the message
    $result = $api->delete($mock_recipient_request, $message_id);
    is($result->[0], 200, "Recipient can delete message sent to them");

    # Cleanup - verify message was deleted
    $message = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    ok(!$message, 'Message was successfully deleted by recipient');
};

#############################################################################
# Test 12: Archive operation permissions
#############################################################################

subtest 'Archive/unarchive permissions enforced' => sub {
    plan tests => 7;  # 2 create + 4 operations + 1 cleanup

    # Create a message from user1 to user2
    my $insert_ok = $DB->sqlInsert('message', {
        author_user => $test_user1->{node_id},
        for_user => $test_user2->{node_id},
        msgtext => 'Test message for archive permissions',
        '-tstamp' => 'NOW()',  # Leading dash means raw SQL, not quoted
        archive => 0
    });
    ok($insert_ok, 'Message insert successful');

    # Get the actual message ID
    my ($message_id) = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($message_id, 'Got message ID');

    # Create mock recipient
    my $mock_recipient = MockUser->new(
        node_id => $test_user2->{node_id},
        title => $test_user2->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user2,
    );
    my $mock_recipient_request = MockRequest->new(
        user => $mock_recipient,
    );

    # TEST: Recipient can archive their own message
    my $result = $api->archive($mock_recipient_request, $message_id);
    is($result->[0], 200, "Recipient can archive message");

    # Verify message is archived
    my $message = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    is($message->{archive}, 1, 'Message is now archived');

    # TEST: Recipient can unarchive their own message
    $result = $api->unarchive($mock_recipient_request, $message_id);
    is($result->[0], 200, "Recipient can unarchive message");

    # Verify message is unarchived
    $message = $DB->sqlSelectHashref('*', 'message', "message_id=$message_id");
    is($message->{archive}, 0, 'Message is now unarchived');

    # Cleanup
    $DB->sqlDelete('message', "message_id=$message_id");
    pass('Test cleanup complete');
};

#############################################################################
# Test 13: Outbox functionality - get sent messages
#############################################################################

subtest 'Outbox: Get sent messages' => sub {
    plan tests => 11;

    # Create an inbox message from user1 to user2
    my $insert_ok = $DB->sqlInsert('message', {
        author_user => $test_user1->{node_id},
        for_user => $test_user2->{node_id},
        msgtext => 'Test outbox message',
        '-tstamp' => 'NOW()',
        archive => 0
    });
    ok($insert_ok, 'Message insert successful');

    my ($inbox_message_id) = $DB->sqlSelect('LAST_INSERT_ID()');

    # Create corresponding outbox message in message_outbox table
    $DB->sqlInsert('message_outbox', {
        author_user => $test_user1->{node_id},
        msgtext => 'Test outbox message',
        '-tstamp' => 'NOW()',
        archive => 0
    });

    my ($message_id) = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($message_id, 'Got outbox message ID');

    # Create mock sender (user1)
    my $mock_sender = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );

    # Test 1: Get inbox (should NOT include sent message)
    my $mock_cgi_inbox = MockCGI->new(
        _params => {
            limit => 100,
            offset => 0,
            archive => 0,
            outbox => 0,
        },
    );
    my $mock_request_inbox = MockRequest->new(
        user => $mock_sender,
        _cgi => $mock_cgi_inbox,
    );

    my $result = $api->get_all($mock_request_inbox);
    is($result->[0], 200, "Inbox GET returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "Inbox returns array");

    # Verify outbox message is NOT in inbox
    my $found_in_inbox = 0;
    for my $msg (@{$result->[1]}) {
        $found_in_inbox = 1 if $msg->{message_id} == $inbox_message_id;
    }
    is($found_in_inbox, 0, "Sent message NOT in sender's inbox");

    # Test 2: Get outbox (should include sent message)
    my $mock_cgi_outbox = MockCGI->new(
        _params => {
            limit => 100,
            offset => 0,
            archive => 0,
            outbox => 1,
        },
    );
    my $mock_request_outbox = MockRequest->new(
        user => $mock_sender,
        _cgi => $mock_cgi_outbox,
    );

    $result = $api->get_all($mock_request_outbox);
    is($result->[0], 200, "Outbox GET returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "Outbox returns array");

    # Verify sent message IS in outbox
    my $found_in_outbox = 0;
    my $outbox_msg;
    for my $msg (@{$result->[1]}) {
        if ($msg->{message_id} == $message_id) {
            $found_in_outbox = 1;
            $outbox_msg = $msg;
            last;
        }
    }
    is($found_in_outbox, 1, "Sent message IS in sender's outbox");
    ok($outbox_msg, "Found message in outbox");
    is($outbox_msg->{msgtext}, 'Test outbox message', "Outbox message has correct text");

    # Cleanup
    $DB->sqlDelete('message', "message_id=$inbox_message_id");
    $DB->sqlDelete('message_outbox', "message_id=$message_id");
    pass('Test cleanup complete');
};

#############################################################################
# Test 14: Outbox pagination and limits
#############################################################################

subtest 'Outbox: Pagination and limits' => sub {
    plan tests => 7;

    # Create 3 test outbox messages in message_outbox table
    my @message_ids;
    for my $i (1..3) {
        $DB->sqlInsert('message_outbox', {
            author_user => $test_user1->{node_id},
            msgtext => "Outbox test message $i",
            '-tstamp' => 'NOW()',
            archive => 0
        });
        my ($msg_id) = $DB->sqlSelect('LAST_INSERT_ID()');
        push @message_ids, $msg_id;
    }

    ok(scalar(@message_ids) == 3, 'Created 3 test messages');

    # Create mock sender
    my $mock_sender = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );

    # Test limit parameter
    my $mock_cgi = MockCGI->new(
        _params => {
            limit => 2,
            offset => 0,
            outbox => 1,
        },
    );
    my $mock_request = MockRequest->new(
        user => $mock_sender,
        _cgi => $mock_cgi,
    );

    my $result = $api->get_all($mock_request);
    is($result->[0], 200, "Outbox with limit returns HTTP 200");

    # Count how many of our test messages appear in first page
    my $count_on_page = 0;
    for my $msg (@{$result->[1]}) {
        $count_on_page++ if grep { $_ == $msg->{message_id} } @message_ids;
    }
    ok($count_on_page <= 2, "Limit of 2 is respected (got $count_on_page of our messages)");

    # Test offset parameter
    $mock_cgi->_params->{limit} = 1;
    $mock_cgi->_params->{offset} = 1;

    $result = $api->get_all($mock_request);
    is($result->[0], 200, "Outbox with offset returns HTTP 200");
    is(ref($result->[1]), 'ARRAY', "Outbox with offset returns array");

    # Test default limit (should be 15)
    $mock_cgi->_params->{limit} = undef;
    $mock_cgi->_params->{offset} = 0;

    $result = $api->get_all($mock_request);
    my $count_total = scalar(@{$result->[1]});
    ok($count_total <= 15, "Default limit of 15 respected (got $count_total messages)");

    # Cleanup
    for my $msg_id (@message_ids) {
        $DB->sqlDelete('message_outbox', "message_id=$msg_id");
    }
    pass('Test cleanup complete');
};

#############################################################################
# Test 15: Outbox archive functionality
#############################################################################

subtest 'Outbox: Archive parameter' => sub {
    plan tests => 7;

    # Create archived and non-archived outbox messages in message_outbox table
    $DB->sqlInsert('message_outbox', {
        author_user => $test_user1->{node_id},
        msgtext => 'Outbox non-archived message',
        '-tstamp' => 'NOW()',
        archive => 0
    });
    my ($non_archived_id) = $DB->sqlSelect('LAST_INSERT_ID()');

    $DB->sqlInsert('message_outbox', {
        author_user => $test_user1->{node_id},
        msgtext => 'Outbox archived message',
        '-tstamp' => 'NOW()',
        archive => 1
    });
    my ($archived_id) = $DB->sqlSelect('LAST_INSERT_ID()');

    ok($non_archived_id && $archived_id, 'Created test messages');

    # Create mock sender
    my $mock_sender = MockUser->new(
        node_id => $test_user1->{node_id},
        title => $test_user1->{title},
        is_guest_flag => 0,
        NODEDATA => $test_user1,
    );

    # Test: Get non-archived outbox (archive=0)
    my $mock_cgi = MockCGI->new(
        _params => {
            limit => 100,
            archive => 0,
            outbox => 1,
        },
    );
    my $mock_request = MockRequest->new(
        user => $mock_sender,
        _cgi => $mock_cgi,
    );

    my $result = $api->get_all($mock_request);
    is($result->[0], 200, "Non-archived outbox returns HTTP 200");

    my $found_non_archived = 0;
    my $found_archived = 0;
    for my $msg (@{$result->[1]}) {
        $found_non_archived = 1 if $msg->{message_id} == $non_archived_id;
        $found_archived = 1 if $msg->{message_id} == $archived_id;
    }
    is($found_non_archived, 1, "Non-archived message IS in non-archived outbox");
    is($found_archived, 0, "Archived message NOT in non-archived outbox");

    # Test: Get archived outbox (archive=1)
    $mock_cgi->_params->{archive} = 1;

    $result = $api->get_all($mock_request);
    is($result->[0], 200, "Archived outbox returns HTTP 200");

    $found_non_archived = 0;
    $found_archived = 0;
    for my $msg (@{$result->[1]}) {
        $found_non_archived = 1 if $msg->{message_id} == $non_archived_id;
        $found_archived = 1 if $msg->{message_id} == $archived_id;
    }
    is($found_non_archived, 0, "Non-archived message NOT in archived outbox");
    is($found_archived, 1, "Archived message IS in archived outbox");

    # Cleanup
    $DB->sqlDelete('message_outbox', "message_id IN ($non_archived_id, $archived_id)");
};

done_testing();

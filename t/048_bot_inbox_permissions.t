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
# Test Bot Inbox Permissions
#
# These tests verify that admin/editor users can manage messages in bot inboxes:
# 1. Archive messages in bot inboxes
# 2. Unarchive messages in bot inboxes
# 3. Delete messages in bot inboxes
# 4. Permission checks for bot inbox access
#############################################################################

# Mock User objects
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'is_guest_flag' => (is => 'rw', default => 0);
    has 'is_admin_flag' => (is => 'rw', default => 0);
    has 'is_editor_flag' => (is => 'rw', default => 0);
    sub is_guest { return shift->is_guest_flag; }
    sub is_admin { return shift->is_admin_flag; }
    sub is_editor { return shift->is_editor_flag; }
}

package MockRequest {
    use Moose;
    has 'user' => (is => 'rw');
    has 'cgi' => (is => 'rw');
}

package MockCGI {
    use Moose;
    has '_params' => (is => 'rw', default => sub { {} });
    sub param {
        my ($self, $key, $value) = @_;
        return $self->_params->{$key} if @_ == 2;
        $self->_params->{$key} = $value if @_ == 3;
        return undef;
    }
}

package main;

# Get Virgil bot user (commonly used bot for testing)
my $bot_user = $DB->getNode("Virgil", "user");
ok($bot_user, "Got Virgil bot user");

# Create mock admin user based on real root user
my $root_node_data = $DB->getNodeById(113);
my $admin_user = MockUser->new(
    node_id => $root_node_data->{node_id},
    title => $root_node_data->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    is_editor_flag => 1,
    NODEDATA => $root_node_data
);
ok($admin_user->is_admin, "Admin user has is_admin flag");

# Create mock editor user based on real e2e_admin user
my $e2e_admin_node_data = $DB->getNodeById(2212892);
my $editor_user = MockUser->new(
    node_id => $e2e_admin_node_data->{node_id},
    title => $e2e_admin_node_data->{title},
    is_guest_flag => 0,
    is_admin_flag => 0,
    is_editor_flag => 1,
    NODEDATA => $e2e_admin_node_data
);
ok($editor_user->is_editor, "Editor user has is_editor flag");

# Create test message for bot
my $insert_ok = $DB->sqlInsert("message", {
    for_user => $bot_user->{node_id},
    author_user => 113,  # from root
    msgtext => "Test message for bot inbox permissions",
    archive => 0,
    '-tstamp' => 'NOW()'
});
ok($insert_ok, "Message insert successful");

my ($message_id) = $DB->sqlSelect('LAST_INSERT_ID()');
ok($message_id, "Got message ID: $message_id");

# Create API instance
my $api = Everything::API::messages->new(
    APP => $APP,
    DB => $DB,
    devLog => sub {},
    HTTP_OK => 200,
    HTTP_FORBIDDEN => 403,
    HTTP_BAD_REQUEST => 400
);

#############################################################################
# Test 1: Admin can archive bot message
#############################################################################
{
    my $request = MockRequest->new(
        user => $admin_user,
        cgi => MockCGI->new()
    );

    # Archive the message
    my ($status, $response) = @{$api->archive($request, $message_id)};
    is($status, 200, "Admin can archive bot inbox message");
    is($response->{id}, $message_id, "Archive returns correct message ID");

    # Verify message is archived
    my $msg = $DB->sqlSelectHashref("*", "message", "message_id=$message_id");
    is($msg->{archive}, 1, "Message is marked as archived in database");
}

#############################################################################
# Test 2: Admin can unarchive bot message
#############################################################################
{
    my $request = MockRequest->new(
        user => $admin_user,
        cgi => MockCGI->new()
    );

    # Unarchive the message
    my ($status, $response) = @{$api->unarchive($request, $message_id)};
    is($status, 200, "Admin can unarchive bot inbox message");
    is($response->{id}, $message_id, "Unarchive returns correct message ID");

    # Verify message is unarchived
    my $msg = $DB->sqlSelectHashref("*", "message", "message_id=$message_id");
    is($msg->{archive}, 0, "Message is marked as unarchived in database");
}

#############################################################################
# Test 3: Editor with permission can archive bot message
#############################################################################
{
    my $request = MockRequest->new(
        user => $editor_user,
        cgi => MockCGI->new()
    );

    # Archive the message
    my ($status, $response) = @{$api->archive($request, $message_id)};
    is($status, 200, "Editor can archive bot inbox message (has Content Editors permission)");
    is($response->{id}, $message_id, "Archive returns correct message ID");
}

#############################################################################
# Test 4: Admin can delete bot message
#############################################################################
{
    my $request = MockRequest->new(
        user => $admin_user,
        cgi => MockCGI->new()
    );

    # Delete the message
    my ($status, $response) = @{$api->delete($request, $message_id)};
    is($status, 200, "Admin can delete bot inbox message");

    # Verify message is deleted
    my $msg = $DB->sqlSelectHashref("*", "message", "message_id=$message_id");
    ok(!$msg, "Message is deleted from database");
}

#############################################################################
# Test 5: Non-editor user cannot access bot inbox operations
#############################################################################
{
    # Create test message for bot
    my $insert_ok2 = $DB->sqlInsert("message", {
        for_user => $bot_user->{node_id},
        author_user => 113,
        msgtext => "Test message for permission check",
        archive => 0,
        '-tstamp' => 'NOW()'
    });
    my ($test_msg_id) = $DB->sqlSelect('LAST_INSERT_ID()');

    # Create regular user (not editor, not admin)
    my $regular_user_node_data = $DB->getNodeById(2212896);  # e2e_user
    my $regular_user = MockUser->new(
        node_id => $regular_user_node_data->{node_id},
        title => $regular_user_node_data->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        NODEDATA => $regular_user_node_data
    );
    ok($regular_user, "Got regular user");
    ok(!$regular_user->is_admin, "Regular user is not admin");
    ok(!$regular_user->is_editor, "Regular user is not editor");

    my $request = MockRequest->new(
        user => $regular_user,
        cgi => MockCGI->new()
    );

    # Try to archive - should fail
    my ($status, $response) = @{$api->archive($request, $test_msg_id)};
    is($status, 403, "Regular user cannot archive bot inbox message");

    # Clean up
    $DB->sqlDelete("message", "message_id=$test_msg_id");
}

#############################################################################
# Clean up
#############################################################################
done_testing();

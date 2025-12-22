#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::weblog;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::weblog->new();
ok($api, "Created weblog API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $other_user = $DB->getNode("normaluser2", "user");
ok($other_user, "Got other user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Check for News for Noders weblog (the primary weblog in E2)
my $news_weblog = $DB->getNode('News for Noders', 'superdoc');
my $can_test_weblog = defined($news_weblog);

# Create test target node for weblog entry
my $target_title = "Test Weblog Target " . time();
my $target_id = $DB->insertNode(
    $target_title,
    'superdoc',
    $admin_user,
    { title => $target_title, doctext => 'Test target content' }
);
ok($target_id, "Created target node for weblog tests");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/:weblog_id/:to_node'}, 'handle_entry', "handle_entry route exists");

#############################################################################
# Test: handle_entry - invalid method (GET)
#############################################################################

my $request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'GET'
);

my $result = $api->handle_entry($request, 1, 1);
is($result->[0], $api->HTTP_OK, "Invalid method returns HTTP 200");
is($result->[1]{success}, 0, "Invalid method fails");
like($result->[1]{error}, qr/method not allowed/i, "Error mentions method not allowed");

#############################################################################
# Test: remove_entry - invalid IDs
#############################################################################

$request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'DELETE'
);

$result = $api->handle_entry($request, 0, 0);
is($result->[0], $api->HTTP_OK, "Invalid IDs returns HTTP 200");
is($result->[1]{success}, 0, "Invalid IDs fails");
like($result->[1]{error}, qr/invalid/i, "Error mentions invalid");

$result = $api->handle_entry($request, undef, undef);
is($result->[0], $api->HTTP_OK, "Null IDs returns HTTP 200");
is($result->[1]{success}, 0, "Null IDs fails");

#############################################################################
# Test: remove_entry - guest user denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    request_method => 'DELETE'
);

$result = $api->handle_entry($guest_request, 12345, 67890);
is($result->[0], $api->HTTP_OK, "Guest returns HTTP 200");
is($result->[1]{success}, 0, "Guest fails");
like($result->[1]{error}, qr/logged in/i, "Error mentions must be logged in");

#############################################################################
# Test: remove_entry - non-existent weblog
#############################################################################

$result = $api->handle_entry($request, 999999999, 1);
is($result->[0], $api->HTTP_OK, "Non-existent weblog returns HTTP 200");
is($result->[1]{success}, 0, "Non-existent weblog fails");
like($result->[1]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: remove_entry - entry not found
#############################################################################

SKIP: {
    skip "News for Noders weblog not available", 3 unless $can_test_weblog;

    # Try to remove entry that doesn't exist
    $result = $api->handle_entry($request, $news_weblog->{node_id}, 999999999);
    is($result->[0], $api->HTTP_OK, "Non-existent entry returns HTTP 200");
    is($result->[1]{success}, 0, "Non-existent entry fails");
    like($result->[1]{error}, qr/not found|permission/i,
         "Error mentions not found or permission denied");
}

#############################################################################
# Test: Full workflow with real weblog entry
#############################################################################

SKIP: {
    skip "News for Noders weblog not available", 10 unless $can_test_weblog;

    my $weblog_id = $news_weblog->{node_id};

    # Create a weblog entry using admin (who should have permission)
    $DB->sqlInsert('weblog', {
        weblog_id => $weblog_id,
        to_node => $target_id,
        linkedby_user => $admin_user->{node_id},
        linkedtime => \'NOW()',
        removedby_user => 0
    });

    # Verify entry was created
    my $entry = $DB->sqlSelectHashref(
        '*',
        'weblog',
        "weblog_id=$weblog_id AND to_node=$target_id AND removedby_user=0"
    );
    ok($entry, "Weblog entry created in database");

    # Non-linker user cannot remove
    my $other_request = MockRequest->new(
        node_id => $other_user->{node_id},
        title => $other_user->{title},
        is_guest_flag => 0,
        nodedata => $other_user,
        request_method => 'DELETE'
    );

    $result = $api->handle_entry($other_request, $weblog_id, $target_id);
    is($result->[0], $api->HTTP_OK, "Non-linker returns HTTP 200");
    is($result->[1]{success}, 0, "Non-linker fails");
    like($result->[1]{error}, qr/permission denied/i, "Error mentions permission denied");

    # Original linker (admin) can remove
    my $admin_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'DELETE'
    );

    $result = $api->handle_entry($admin_request, $weblog_id, $target_id);
    is($result->[0], $api->HTTP_OK, "Linker remove returns HTTP 200");
    is($result->[1]{success}, 1, "Linker remove succeeds");
    like($result->[1]{message}, qr/removed/i, "Message mentions removed");

    # Verify entry is soft-deleted (removedby_user set)
    my $removed_entry = $DB->sqlSelectHashref(
        '*',
        'weblog',
        "weblog_id=$weblog_id AND to_node=$target_id"
    );
    ok($removed_entry, "Entry still exists in database");
    is($removed_entry->{removedby_user}, $admin_user->{node_id},
       "removedby_user set to removing user");

    # Try to remove again (should fail - already removed)
    $result = $api->handle_entry($admin_request, $weblog_id, $target_id);
    is($result->[0], $api->HTTP_OK, "Double remove returns HTTP 200");
    is($result->[1]{success}, 0, "Double remove fails");
    like($result->[1]{error}, qr/not found|already removed/i,
         "Error mentions already removed");

    # Cleanup - actually delete the weblog entry
    $DB->sqlDelete('weblog', "weblog_id=$weblog_id AND to_node=$target_id");
}

#############################################################################
# Test: Admin can remove any entry
#############################################################################

SKIP: {
    skip "News for Noders weblog not available", 5 unless $can_test_weblog;

    my $weblog_id = $news_weblog->{node_id};

    # Create an entry by normal_user
    $DB->sqlInsert('weblog', {
        weblog_id => $weblog_id,
        to_node => $target_id,
        linkedby_user => $normal_user->{node_id},
        linkedtime => \'NOW()',
        removedby_user => 0
    });

    # Admin can remove even though they didn't create it
    my $admin_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'DELETE'
    );

    $result = $api->handle_entry($admin_request, $weblog_id, $target_id);
    is($result->[0], $api->HTTP_OK, "Admin remove others' entry returns HTTP 200");
    is($result->[1]{success}, 1, "Admin remove others' entry succeeds");

    # Verify it was removed
    my $entry = $DB->sqlSelectHashref(
        '*',
        'weblog',
        "weblog_id=$weblog_id AND to_node=$target_id AND removedby_user=0"
    );
    ok(!$entry, "Entry is no longer active");

    # Cleanup
    $DB->sqlDelete('weblog', "weblog_id=$weblog_id AND to_node=$target_id");
}

#############################################################################
# Cleanup
#############################################################################

# Delete target node
my $target = $DB->getNodeById($target_id);
$DB->nukeNode($target, $admin_user) if $target;

done_testing();

=head1 NAME

t/073_weblog_api.t - Tests for Everything::API::weblog

=head1 DESCRIPTION

Tests for the weblog entry management API covering:
- Invalid HTTP method handling
- Invalid IDs validation
- Guest user denied
- Non-existent weblog handling
- Non-existent entry handling
- Permission checks (original linker, admin, owner)
- Successful entry removal (soft delete)
- Double removal prevention
- Admin override capability

=head1 AUTHOR

Everything2 Development Team

=cut

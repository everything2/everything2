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
ok(exists $routes->{'/available'}, "available route exists");
ok(exists $routes->{'/:id'}, "weblog route exists");
ok(exists $routes->{'/:id/:to_node'}, "entry route exists");

#############################################################################
# Test: list_entries - invalid weblog_id
#############################################################################

my $request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'GET'
);

my $result = $api->list_entries($request, 0);
is($result->[0], $api->HTTP_OK, "Invalid weblog_id returns HTTP 200");
is($result->[1]{success}, 0, "Invalid weblog_id fails");
like($result->[1]{error}, qr/invalid/i, "Error mentions invalid");

#############################################################################
# Test: list_entries - non-existent weblog
#############################################################################

$result = $api->list_entries($request, 999999999);
is($result->[0], $api->HTTP_OK, "Non-existent weblog returns HTTP 200");
is($result->[1]{success}, 0, "Non-existent weblog fails");
like($result->[1]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: list_entries - valid weblog with entries
#############################################################################

SKIP: {
    skip "News for Noders weblog not available", 12 unless $can_test_weblog;

    my $weblog_id = $news_weblog->{node_id};

    # Create a couple test entries
    my @test_targets;
    for my $i (1..3) {
        my $test_title = "Weblog List Test Target $i " . time();
        my $test_id = $DB->insertNode(
            $test_title,
            'superdoc',
            $admin_user,
            { title => $test_title, doctext => "Test content $i" }
        );
        push @test_targets, $test_id;

        $DB->sqlInsert('weblog', {
            weblog_id => $weblog_id,
            to_node => $test_id,
            linkedby_user => $admin_user->{node_id},
            linkedtime => \'NOW()',
            removedby_user => 0
        });
    }

    # List entries - should return our test entries
    $result = $api->list_entries($request, $weblog_id);
    is($result->[0], $api->HTTP_OK, "List entries returns HTTP 200");
    is($result->[1]{success}, 1, "List entries succeeds");
    ok(exists $result->[1]{entries}, "Response includes entries array");
    ok(ref($result->[1]{entries}) eq 'ARRAY', "entries is an array");
    ok(scalar(@{$result->[1]{entries}}) >= 3, "At least 3 entries returned");
    ok(exists $result->[1]{has_more}, "Response includes has_more flag");
    ok(exists $result->[1]{limit}, "Response includes limit");
    ok(exists $result->[1]{offset}, "Response includes offset");
    ok(exists $result->[1]{can_remove}, "Response includes can_remove flag");

    # Check entry structure
    my $first_entry = $result->[1]{entries}[0];
    ok(exists $first_entry->{to_node}, "Entry has to_node");
    ok(exists $first_entry->{title}, "Entry has title");
    ok(exists $first_entry->{linkedtime}, "Entry has linkedtime");

    # Cleanup test entries
    for my $test_id (@test_targets) {
        $DB->sqlDelete('weblog', "weblog_id=$weblog_id AND to_node=$test_id");
        my $test_node = $DB->getNodeById($test_id);
        $DB->nukeNode($test_node, $admin_user) if $test_node;
    }
}

#############################################################################
# Test: list_entries - pagination
#############################################################################

SKIP: {
    skip "News for Noders weblog not available", 6 unless $can_test_weblog;

    my $weblog_id = $news_weblog->{node_id};

    # Create 6 test entries for pagination testing
    my @test_targets;
    for my $i (1..6) {
        my $test_title = "Weblog Pagination Test $i " . time() . rand();
        my $test_id = $DB->insertNode(
            $test_title,
            'superdoc',
            $admin_user,
            { title => $test_title, doctext => "Test content $i" }
        );
        push @test_targets, $test_id;

        $DB->sqlInsert('weblog', {
            weblog_id => $weblog_id,
            to_node => $test_id,
            linkedby_user => $admin_user->{node_id},
            linkedtime => \'NOW()',
            removedby_user => 0
        });
    }

    # Request with limit=3
    my $paginated_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'GET',
        params => { limit => 3, offset => 0 }
    );

    $result = $api->list_entries($paginated_request, $weblog_id);
    is($result->[0], $api->HTTP_OK, "Paginated list returns HTTP 200");
    is($result->[1]{success}, 1, "Paginated list succeeds");
    is($result->[1]{limit}, 3, "Limit is respected");
    is($result->[1]{offset}, 0, "Offset is correct");
    is($result->[1]{has_more}, 1, "has_more is true when more entries exist");
    ok(scalar(@{$result->[1]{entries}}) <= 3, "Returned entries respect limit");

    # Cleanup test entries
    for my $test_id (@test_targets) {
        $DB->sqlDelete('weblog', "weblog_id=$weblog_id AND to_node=$test_id");
        my $test_node = $DB->getNodeById($test_id);
        $DB->nukeNode($test_node, $admin_user) if $test_node;
    }
}

#############################################################################
# Test: list_entries - can_remove for admin
#############################################################################

SKIP: {
    skip "News for Noders weblog not available", 2 unless $can_test_weblog;

    my $weblog_id = $news_weblog->{node_id};

    my $admin_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'GET'
    );

    $result = $api->list_entries($admin_request, $weblog_id);
    is($result->[0], $api->HTTP_OK, "Admin list returns HTTP 200");
    is($result->[1]{can_remove}, 1, "Admin can_remove is true");
}

#############################################################################
# Test: handle_entry - invalid method (GET on entry endpoint)
#############################################################################

$request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'GET'
);

$result = $api->handle_entry($request, 1, 1);
is($result->[0], $api->HTTP_OK, "Invalid method on entry returns HTTP 200");
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
# Test: get_available_groups - guest user gets empty list
#############################################################################

my $guest_groups_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    request_method => 'GET'
);

$result = $api->get_available_groups($guest_groups_request);
is($result->[0], $api->HTTP_OK, "Guest available groups returns HTTP 200");
is($result->[1]{success}, 1, "Guest available groups succeeds");
ok(ref($result->[1]{groups}) eq 'ARRAY', "Guest groups is an array");
is(scalar(@{$result->[1]{groups}}), 0, "Guest has no available groups");

#############################################################################
# Test: get_available_groups - logged-in user with usergroup membership
#############################################################################

# Create a usergroup and add normal_user as member
my $test_group_title = "Test Usergroup " . time();
my $test_group_id = $DB->insertNode(
    $test_group_title,
    'usergroup',
    $admin_user,
    { title => $test_group_title }
);
ok($test_group_id, "Created test usergroup");

# Add normal_user as a member of the usergroup
$DB->getDatabaseHandle()->do("INSERT INTO nodegroup (nodegroup_id, node_id, nodegroup_rank) VALUES (?, ?, 0)",
    undef, $test_group_id, $normal_user->{node_id});

# Get available groups for normal_user
my $user_groups_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'GET'
);

$result = $api->get_available_groups($user_groups_request);
is($result->[0], $api->HTTP_OK, "User available groups returns HTTP 200");
is($result->[1]{success}, 1, "User available groups succeeds");
ok(ref($result->[1]{groups}) eq 'ARRAY', "User groups is an array");
ok(scalar(@{$result->[1]{groups}}) >= 1, "User has at least one available group");

# Check that test usergroup is in the list
my $found_test_group = grep { $_->{node_id} == $test_group_id } @{$result->[1]{groups}};
ok($found_test_group, "Test usergroup is in available groups");

# Check group structure
if ($found_test_group) {
    my ($group) = grep { $_->{node_id} == $test_group_id } @{$result->[1]{groups}};
    ok(exists $group->{node_id}, "Group has node_id");
    ok(exists $group->{title}, "Group has title");
    is($group->{title}, $test_group_title, "Group title matches");
}

# Cleanup test usergroup
$DB->sqlDelete('nodegroup', "nodegroup_id=$test_group_id AND node_id=" . $normal_user->{node_id});
my $test_group_node = $DB->getNodeById($test_group_id);
$DB->nukeNode($test_group_node, $admin_user) if $test_group_node;

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

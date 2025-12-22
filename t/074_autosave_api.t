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
use Everything::API::autosave;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::autosave->new();
ok($api, "Created autosave API instance");

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

# Create a test document node that the user can edit
# Use admin to create, then transfer ownership to normal_user
my $test_node_title = "Test Autosave Node " . time();
my $test_node_id = $DB->insertNode(
    $test_node_title,
    'document',
    $admin_user,
    {
        doctext => 'Initial content for autosave testing.',
        author_user => $normal_user->{node_id}
    }
);

# Update author_user to normal_user so they can edit it
if ($test_node_id) {
    $DB->sqlUpdate('node', { author_user => $normal_user->{node_id} }, "node_id = $test_node_id");
}
ok($test_node_id, "Created test document node");

# Create autosave table entries for cleanup later
my @autosave_ids;

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/'}, 'create', "create route exists");
is($routes->{'/:id'}, 'get_or_delete', "get_or_delete route exists");
is($routes->{'/:id/history'}, 'get_version_history', "get_version_history route exists");
is($routes->{'/:id/restore'}, 'restore_version', "restore_version route exists");

#############################################################################
# Test: create - guest user denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    request_method => 'POST'
);

{
    no warnings 'redefine';
    *MockRequest::POSTDATA = sub {
        return JSON::encode_json({ node_id => $test_node_id, doctext => 'test content' });
    };
}

# Note: unauthorized_if_guest wrapper returns 401 UNAUTHORIZED with no body
my $result = $api->create($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest create returns 401");

#############################################################################
# Test: create - invalid JSON
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'POST'
);

{
    no warnings 'redefine';
    *MockRequest::POSTDATA = sub { return "not valid json"; };
}

$result = $api->create($normal_request);
is($result->[0], $api->HTTP_BAD_REQUEST, "Invalid JSON returns 400");
is($result->[1]{error}, 'invalid_json', "Error code is invalid_json");

#############################################################################
# Test: create - missing node_id
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::POSTDATA = sub {
        return JSON::encode_json({ doctext => 'test content' });
    };
}

$result = $api->create($normal_request);
is($result->[0], $api->HTTP_BAD_REQUEST, "Missing node_id returns 400");
is($result->[1]{error}, 'invalid_node_id', "Error code is invalid_node_id");

#############################################################################
# Test: create - non-existent node
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::POSTDATA = sub {
        return JSON::encode_json({ node_id => 999999999, doctext => 'test content' });
    };
}

$result = $api->create($normal_request);
is($result->[0], $api->HTTP_NOT_FOUND, "Non-existent node returns 404");
is($result->[1]{error}, 'node_not_found', "Error code is node_not_found");

#############################################################################
# Test: create - permission denied (other user's node)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::POSTDATA = sub {
        return JSON::encode_json({ node_id => $test_node_id, doctext => 'unauthorized edit' });
    };
}

my $other_request = MockRequest->new(
    node_id => $other_user->{node_id},
    title => $other_user->{title},
    is_guest_flag => 0,
    nodedata => $other_user,
    request_method => 'POST'
);

$result = $api->create($other_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Other user edit returns 403");
is($result->[1]{error}, 'permission_denied', "Error code is permission_denied");

#############################################################################
# Test: create - successful autosave
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::POSTDATA = sub {
        return JSON::encode_json({ node_id => $test_node_id, doctext => 'Updated content via autosave' });
    };
}

$result = $api->create($normal_request);
is($result->[0], $api->HTTP_OK, "Successful autosave returns 200");
is($result->[1]{success}, 1, "Success flag is true");
is($result->[1]{saved}, 1, "Saved flag is true");
ok($result->[1]{autosave_id}, "Autosave ID returned");
push @autosave_ids, $result->[1]{autosave_id} if $result->[1]{autosave_id};

#############################################################################
# Test: create - no changes (same content)
#############################################################################

$result = $api->create($normal_request);
is($result->[0], $api->HTTP_OK, "No changes returns 200");
is($result->[1]{success}, 1, "Success flag is true");
is($result->[1]{saved}, 0, "Saved flag is false (no changes)");
is($result->[1]{message}, 'no_changes', "Message indicates no changes");

#############################################################################
# Test: get_autosaves - invalid node_id
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::request_method = sub { return 'GET'; };
}

$result = $api->get_or_delete($normal_request, 0);
is($result->[0], $api->HTTP_BAD_REQUEST, "Invalid node_id returns 400");
is($result->[1]{error}, 'invalid_node_id', "Error code is invalid_node_id");

#############################################################################
# Test: get_autosaves - success
#############################################################################

$result = $api->get_or_delete($normal_request, $test_node_id);
is($result->[0], $api->HTTP_OK, "Get autosaves returns 200");
is($result->[1]{success}, 1, "Success flag is true");
is($result->[1]{node_id}, $test_node_id, "Node ID in response");
ok(ref($result->[1]{autosaves}) eq 'ARRAY', "Autosaves is an array");

#############################################################################
# Test: get_version_history - permission denied
#############################################################################

$result = $api->get_version_history($other_request, $test_node_id);
is($result->[0], $api->HTTP_FORBIDDEN, "Other user history returns 403");
is($result->[1]{error}, 'permission_denied', "Error code is permission_denied");

#############################################################################
# Test: get_version_history - success
#############################################################################

$result = $api->get_version_history($normal_request, $test_node_id);
is($result->[0], $api->HTTP_OK, "Get version history returns 200");
is($result->[1]{success}, 1, "Success flag is true");
ok(ref($result->[1]{versions}) eq 'ARRAY', "Versions is an array");

# Check version structure if we have any
if (scalar(@{$result->[1]{versions}}) > 0) {
    my $version = $result->[1]{versions}[0];
    ok(defined($version->{autosave_id}), "Version has autosave_id");
    ok(defined($version->{createtime}), "Version has createtime");
    ok(defined($version->{content_length}), "Version has content_length");
    ok(defined($version->{preview}), "Version has preview");
}

#############################################################################
# Test: restore_version - wrong method
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::request_method = sub { return 'GET'; };
}

# Note: HTTP_UNIMPLEMENTED is 405 (Method Not Allowed)
$result = $api->restore_version($normal_request, 1);
is($result->[0], $api->HTTP_UNIMPLEMENTED, "GET restore returns 405");
is($result->[1]{error}, 'method_not_allowed', "Error code is method_not_allowed");

#############################################################################
# Test: restore_version - invalid ID
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::request_method = sub { return 'POST'; };
}

$result = $api->restore_version($normal_request, 0);
is($result->[0], $api->HTTP_BAD_REQUEST, "Invalid ID returns 400");
is($result->[1]{error}, 'invalid_id', "Error code is invalid_id");

#############################################################################
# Test: restore_version - not found
#############################################################################

$result = $api->restore_version($normal_request, 999999999);
is($result->[0], $api->HTTP_NOT_FOUND, "Non-existent version returns 404");
is($result->[1]{error}, 'not_found', "Error code is not_found");

#############################################################################
# Test: restore_version - permission denied
#############################################################################

SKIP: {
    skip "No autosave entries to test restore", 2 unless @autosave_ids;

    $result = $api->restore_version($other_request, $autosave_ids[0]);
    is($result->[0], $api->HTTP_FORBIDDEN, "Other user restore returns 403");
    is($result->[1]{error}, 'permission_denied', "Error code is permission_denied");
}

#############################################################################
# Test: restore_version - success
#############################################################################

SKIP: {
    skip "No autosave entries to test restore", 3 unless @autosave_ids;

    $result = $api->restore_version($normal_request, $autosave_ids[0]);
    is($result->[0], $api->HTTP_OK, "Restore version returns 200");
    is($result->[1]{success}, 1, "Success flag is true");
    is($result->[1]{restored_from}, $autosave_ids[0], "Restored from correct ID");
}

#############################################################################
# Test: delete_autosave - invalid ID
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::request_method = sub { return 'DELETE'; };
}

$result = $api->get_or_delete($normal_request, 0);
is($result->[0], $api->HTTP_BAD_REQUEST, "Invalid ID delete returns 400");
is($result->[1]{error}, 'invalid_id', "Error code is invalid_id");

#############################################################################
# Test: delete_autosave - not found
#############################################################################

$result = $api->get_or_delete($normal_request, 999999999);
is($result->[0], $api->HTTP_NOT_FOUND, "Non-existent delete returns 404");
is($result->[1]{error}, 'not_found', "Error code is not_found");

#############################################################################
# Test: delete_autosave - permission denied
#############################################################################

# Create an autosave entry for normal_user to test deletion
$DB->{dbh}->do(
    "INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type) VALUES (?, ?, ?, NOW(), 'auto')",
    {}, $normal_user->{node_id}, $test_node_id, 'Test content for deletion'
);
my $delete_test_id = $DB->{dbh}->last_insert_id(undef, undef, 'autosave', 'autosave_id');
push @autosave_ids, $delete_test_id if $delete_test_id;

SKIP: {
    skip "Could not create autosave entry for delete test", 2 unless $delete_test_id;

    $result = $api->get_or_delete($other_request, $delete_test_id);
    is($result->[0], $api->HTTP_FORBIDDEN, "Other user delete returns 403");
    is($result->[1]{error}, 'permission_denied', "Error code is permission_denied");
}

#############################################################################
# Test: delete_autosave - success
#############################################################################

SKIP: {
    skip "Could not create autosave entry for delete test", 3 unless $delete_test_id;

    $result = $api->get_or_delete($normal_request, $delete_test_id);
    is($result->[0], $api->HTTP_OK, "Delete returns 200");
    is($result->[1]{success}, 1, "Success flag is true");
    is($result->[1]{deleted}, $delete_test_id, "Deleted correct ID");

    # Remove from cleanup list since it's already deleted
    @autosave_ids = grep { $_ != $delete_test_id } @autosave_ids;
}

#############################################################################
# Test: Admin can delete any autosave
#############################################################################

# Create another autosave entry for admin deletion test
$DB->{dbh}->do(
    "INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type) VALUES (?, ?, ?, NOW(), 'auto')",
    {}, $normal_user->{node_id}, $test_node_id, 'Test content for admin deletion'
);
my $admin_delete_id = $DB->{dbh}->last_insert_id(undef, undef, 'autosave', 'autosave_id');
push @autosave_ids, $admin_delete_id if $admin_delete_id;

SKIP: {
    skip "Could not create autosave entry for admin delete test", 2 unless $admin_delete_id;

    my $admin_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'DELETE'
    );

    $result = $api->get_or_delete($admin_request, $admin_delete_id);
    is($result->[0], $api->HTTP_OK, "Admin delete returns 200");
    is($result->[1]{success}, 1, "Admin delete succeeds");

    # Remove from cleanup list since it's already deleted
    @autosave_ids = grep { $_ != $admin_delete_id } @autosave_ids;
}

#############################################################################
# Test: Invalid method on get_or_delete
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::request_method = sub { return 'PUT'; };
}

$result = $api->get_or_delete($normal_request, $test_node_id);
is($result->[0], $api->HTTP_UNIMPLEMENTED, "PUT returns 405");
is($result->[1]{error}, 'method_not_allowed', "Error code is method_not_allowed");

#############################################################################
# Cleanup
#############################################################################

# Delete remaining autosave entries
foreach my $id (@autosave_ids) {
    $DB->{dbh}->do("DELETE FROM autosave WHERE autosave_id = ?", {}, $id);
}

# Clean up any autosaves created during tests
$DB->{dbh}->do("DELETE FROM autosave WHERE node_id = ?", {}, $test_node_id);

# Delete test node
my $test_node = $DB->getNodeById($test_node_id);
$DB->nukeNode($test_node, $admin_user) if $test_node;

done_testing();

=head1 NAME

t/074_autosave_api.t - Tests for Everything::API::autosave

=head1 DESCRIPTION

Tests for the autosave API covering:
- Guest user denied
- Invalid JSON handling
- Missing/invalid node_id validation
- Permission checks (owner, admin)
- Successful autosave creation
- No-changes detection
- Get autosaves for a node
- Get version history
- Restore version
- Delete autosave
- Admin override for deletion
- Invalid method handling

=head1 AUTHOR

Everything2 Development Team

=cut

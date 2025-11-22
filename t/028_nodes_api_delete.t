#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::nodes;

# Suppress expected warnings
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log|Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Node Delete API - Admin-only access
#
# This test verifies:
# 1. DELETE /api/nodes/:node_id/action/delete works for admin users
# 2. Node is properly deleted from database
# 3. Deleted node is moved to tomb for resurrection
# 4. Authorization is enforced (admin-only - tested via can_delete_node)
#############################################################################

# Get admin user
my $admin_user = $DB->getNode("root", "user") || 
                 $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "in_group=1 LIMIT 1");
ok($admin_user, "Got admin user for tests");

# Helper to create test node
sub create_test_node {
    my ($title) = @_;
    my $type = $DB->getNode("document", "nodetype");
    return unless $type;
    my $node_id = $DB->insertNode($title, $type, $admin_user, { doctext => "Test content" });
    return $DB->getNodeById($node_id);
}

# Helper to cleanup
sub cleanup_node {
    my ($node_id) = @_;
    return unless $node_id;
    my $node = $DB->getNodeById($node_id);
    $DB->nukeNode($node, $admin_user, 1) if ($node && !$node->is_null);
    $DB->sqlDelete("tomb", "node_id=" . $DB->quote($node_id));
}

# Mock objects
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw');
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'is_admin_flag' => (is => 'rw', default => 1);
    sub is_admin { return shift->is_admin_flag; }
}
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
}
package main;

my $api = Everything::API::nodes->new();
ok($api, "Created nodes API instance");

#############################################################################
# Test: Successful node deletion by admin
#############################################################################

my $cleanup = $DB->getNode("API Delete Test Node", "document");
cleanup_node($cleanup->{node_id}) if $cleanup;

my $test_node = create_test_node("API Delete Test Node");
ok($test_node, "Created test node");
my $test_node_id = $test_node->{node_id};

my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    NODEDATA => $admin_user,
);
my $mock_request = MockRequest->new(user => $mock_user);

# Delete the node
my $result = $api->delete($mock_request, $test_node_id);
is($result->[0], 200, "Delete returns HTTP 200");
ok($result->[1], "Delete returns response data");
is($result->[1]{deleted}, $test_node_id, "Response includes deleted node ID");

# Verify deletion
my $deleted_node = $DB->getNodeById($test_node_id);
ok(!$deleted_node || $deleted_node->is_null, "Deleted node no longer exists in database");

my $tomb_entry = $DB->sqlSelectHashref("*", "tomb", "node_id=" . $DB->quote($test_node_id));
ok($tomb_entry, "Deleted node exists in tomb for resurrection");

# Cleanup
$DB->sqlDelete("tomb", "node_id=" . $DB->quote($test_node_id));

#############################################################################
# Note: Authorization testing
#
# The delete API enforces admin-only access via the _can_delete_okay around
# modifier, which calls can_delete_node() on the node object. This permission
# check returns false for non-admin users, resulting in HTTP 403 Forbidden.
#
# The can_delete_node permission method is tested in other test files.
#############################################################################

done_testing();

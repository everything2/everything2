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
use Everything::API::hidewriteups;
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
# Test Hide Writeups API functionality
#
# These tests verify:
# 1. POST /api/hidewriteups/:id/action/hide - Hide writeup from New Writeups
# 2. POST /api/hidewriteups/:id/action/show - Show writeup in New Writeups
# 3. Authorization checks (editor-only access)
# 4. Only works on writeup type nodes
# 5. Updates notnew flag correctly
# 6. Updates New Writeups cache
#############################################################################

# Get an editor user for API operations
my $editor_user = $DB->getNode("root", "user");
if (!$editor_user) {
    $editor_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "in_group=3 LIMIT 1");
}
ok($editor_user, "Got editor user for tests");
diag("Editor user ID: " . ($editor_user ? $editor_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Get a non-editor user for authorization tests
my $normal_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id WHERE node_id != " . $editor_user->{node_id} . " LIMIT 1");
if (!$normal_user) {
    # No other users in database, will use mock user for auth tests
    $normal_user = { node_id => 999997, title => 'normaluser' };
}
ok($normal_user, "Got non-editor user for authorization tests");
diag("Normal user ID: " . ($normal_user ? $normal_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

sub create_test_e2node {
    my ($title) = @_;

    my $type = $DB->getNode("e2node", "nodetype");
    return unless $type;

    my $node_id = $DB->insertNode($title, $type, $editor_user, {});
    return unless $node_id;

    return $DB->getNodeById($node_id);
}

sub create_test_writeup {
    my ($parent_title, $writeup_title) = @_;

    # Create parent e2node
    my $parent = create_test_e2node($parent_title);
    return unless $parent;

    # Create writeup
    my $type = $DB->getNode("writeup", "nodetype");
    return unless $type;

    my $writeup_id = $DB->insertNode($writeup_title, $type, $editor_user, {
        doctext => "Test writeup content",
        parent_e2node => $parent->{node_id},
        notnew => 0,  # Start visible in New Writeups
    });
    return unless $writeup_id;

    return $DB->getNodeById($writeup_id);
}

sub create_test_document {
    my ($title) = @_;

    my $type = $DB->getNode("document", "nodetype");
    return unless $type;

    my $node_id = $DB->insertNode($title, $type, $editor_user, {
        doctext => "Test document content",
    });
    return unless $node_id;

    return $DB->getNodeById($node_id);
}

sub cleanup_node {
    my ($node_id) = @_;
    return unless $node_id;
    eval {
        my $node = $DB->getNodeById($node_id);
        $DB->nukeNode($node, $editor_user, 1) if $node;  # 1 = NOTOMB
        # Clean tomb if exists
        $DB->sqlDelete("tomb", "node_id=" . $DB->quote($node_id));
    };
    # Silently ignore cleanup errors
    return 1;
}

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'is_editor_flag' => (is => 'rw', default => 1);
    has 'is_admin_flag' => (is => 'rw', default => 0);
    sub is_editor { return shift->is_editor_flag; }
    sub is_admin { return shift->is_admin_flag; }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::hidewriteups->new();
ok($api, "Created hidewriteups API instance");

#############################################################################
# Test 1: Hide writeup successfully (editor user)
#############################################################################

subtest 'Successfully hide writeup by editor' => sub {
    plan tests => 7;

    # Cleanup any existing test nodes
    my $cleanup_parent = $DB->getNode("Test Parent for Hide", "e2node");
    cleanup_node($cleanup_parent->{node_id}) if $cleanup_parent;

    # Create a test writeup
    my $writeup = create_test_writeup("Test Parent for Hide", "Test Writeup for Hide");
    ok($writeup, "Created test writeup");
    my $writeup_id = $writeup->{node_id};

    # Verify writeup starts visible (notnew = 0)
    is($writeup->{notnew}, 0, "Writeup starts visible in New Writeups");

    # Create mock editor user
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Hide the writeup
    my $result = $api->hide_writeup($mock_request, $writeup_id);
    is($result->[0], 200, "Hide returns HTTP 200");
    ok($result->[1], "Hide returns response data");

    # Verify response structure
    is($result->[1]{node_id}, $writeup_id, "Response includes correct node_id");
    # The API returns boolean reference (\1 for true)
    ok(${$result->[1]{notnew}}, "Response shows notnew is true");

    # Verify writeup is now hidden in database
    my $updated_writeup = $DB->getNodeById($writeup_id);
    is($updated_writeup->{notnew}, 1, "Writeup is now hidden in database");
};

#############################################################################
# Test 2: Show writeup successfully (editor user)
#############################################################################

subtest 'Successfully show writeup by editor' => sub {
    plan tests => 7;

    # Cleanup any existing test nodes
    my $cleanup_parent = $DB->getNode("Test Parent for Show", "e2node");
    cleanup_node($cleanup_parent->{node_id}) if $cleanup_parent;

    # Create a test writeup
    my $writeup = create_test_writeup("Test Parent for Show", "Test Writeup for Show");
    ok($writeup, "Created test writeup");
    my $writeup_id = $writeup->{node_id};

    # Create mock editor user
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # First hide it using the API
    my $hide_result = $api->hide_writeup($mock_request, $writeup_id);
    my $hidden_writeup = $DB->getNodeById($writeup_id);
    is($hidden_writeup->{notnew}, 1, "Writeup starts hidden in New Writeups");

    # Show the writeup
    my $result = $api->show_writeup($mock_request, $writeup_id);
    is($result->[0], 200, "Show returns HTTP 200");
    ok($result->[1], "Show returns response data");

    # Verify response structure
    is($result->[1]{node_id}, $writeup_id, "Response includes correct node_id");
    # The API returns boolean reference (\0 for false)
    ok(!${$result->[1]{notnew}}, "Response shows notnew is false");

    # Verify writeup is now visible in database
    my $updated_writeup = $DB->getNodeById($writeup_id);
    is($updated_writeup->{notnew}, 0, "Writeup is now visible in database");
};

#############################################################################
# Test 3: Authorization - non-editor cannot hide/show
#############################################################################

subtest 'Authorization: non-editor cannot hide or show' => sub {
    plan tests => 4;

    # Create a test writeup with unique title
    my $timestamp = time();
    my $writeup = create_test_writeup("Test Parent for Auth $timestamp", "Test Writeup for Auth $timestamp");
    ok($writeup, "Created test writeup");

    # Create mock non-editor user
    my $mock_user = MockUser->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title} || 'normaluser',
        is_editor_flag => 0,  # Not an editor
        NODEDATA => $normal_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to hide (should fail)
    my $result = $api->hide_writeup($mock_request, $writeup->{node_id});
    is($result->[0], 401, "Non-editor gets HTTP 401 when trying to hide");

    # Try to show (should fail)
    $result = $api->show_writeup($mock_request, $writeup->{node_id});
    is($result->[0], 401, "Non-editor gets HTTP 401 when trying to show");

    # Verify writeup unchanged
    my $unchanged = $DB->getNodeById($writeup->{node_id});
    is($unchanged->{notnew}, 0, "Writeup notnew flag unchanged");
};

#############################################################################
# Test 4: Only works on writeup nodes
#############################################################################

subtest 'Only works on writeup type nodes' => sub {
    plan tests => 4;

    # Create a non-writeup node (document) with unique title
    my $timestamp = time();
    my $document = create_test_document("Test Document for Type Check $timestamp");
    ok($document, "Created test document");

    # Create mock editor user
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Try to hide document (should fail - not a writeup)
    my $result = $api->hide_writeup($mock_request, $document->{node_id});
    is($result->[0], 401, "Hide returns HTTP 401 for non-writeup node");

    # Try to show document (should fail - not a writeup)
    $result = $api->show_writeup($mock_request, $document->{node_id});
    is($result->[0], 401, "Show returns HTTP 401 for non-writeup node");

    # Try with non-existent node
    $result = $api->hide_writeup($mock_request, 999999999);
    is($result->[0], 401, "Hide returns HTTP 401 for non-existent node");
};

#############################################################################
# Test 5: Toggle writeup multiple times
#############################################################################

subtest 'Toggle writeup between hidden and visible' => sub {
    plan tests => 10;

    # Create a test writeup with unique title
    my $timestamp = time();
    my $writeup = create_test_writeup("Test Parent for Toggle $timestamp", "Test Writeup for Toggle $timestamp");
    ok($writeup, "Created test writeup");
    my $writeup_id = $writeup->{node_id};

    # Create mock editor user
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Initial state: visible
    is($writeup->{notnew}, 0, "Writeup starts visible");

    # Hide it
    my $result = $api->hide_writeup($mock_request, $writeup_id);
    is($result->[0], 200, "First hide succeeds");
    my $check1 = $DB->getNodeById($writeup_id);
    is($check1->{notnew}, 1, "Writeup is hidden after first hide");

    # Hide it again (should still work, just redundant)
    $result = $api->hide_writeup($mock_request, $writeup_id);
    is($result->[0], 200, "Second hide succeeds");
    my $check2 = $DB->getNodeById($writeup_id);
    is($check2->{notnew}, 1, "Writeup still hidden after second hide");

    # Show it
    $result = $api->show_writeup($mock_request, $writeup_id);
    is($result->[0], 200, "First show succeeds");
    my $check3 = $DB->getNodeById($writeup_id);
    is($check3->{notnew}, 0, "Writeup is visible after first show");

    # Show it again (should still work, just redundant)
    $result = $api->show_writeup($mock_request, $writeup_id);
    is($result->[0], 200, "Second show succeeds");
    my $check4 = $DB->getNodeById($writeup_id);
    is($check4->{notnew}, 0, "Writeup still visible after second show");
};

done_testing();

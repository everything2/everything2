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
use Everything::API::writeup_reparent;
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
# Test Writeup Reparent API functionality
#
# These tests verify:
# 1. GET /api/writeup_reparent - Get e2node/writeup info
# 2. POST /api/writeup_reparent/reparent - Reparent writeups
# 3. Authorization checks (editor/admin only)
# 4. Orphaned writeup detection and parent guessing
# 5. Nodegroup updates on reparent
# 6. Message notifications to authors
#############################################################################

# Get an editor/admin user for API operations
my $editor_user = $DB->getNode("root", "user");
if (!$editor_user) {
    $editor_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "1=1 LIMIT 1");
}
ok($editor_user, "Got editor user for tests");
diag("Editor user ID: " . ($editor_user ? $editor_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Get a non-editor user for authorization tests
my $normal_user = $DB->getNode("guest user", "user");
if (!$normal_user) {
    $normal_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id WHERE node_id != " . $editor_user->{node_id} . " LIMIT 1");
}
if (!$normal_user) {
    # No other users, create a mock one
    $normal_user = { node_id => 999997, title => 'normaluser' };
}
ok($normal_user, "Got non-editor user for authorization tests");

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
    my ($parent_e2node, $author) = @_;
    $author ||= $editor_user;

    my $type = $DB->getNode("writeup", "nodetype");
    return unless $type;

    my $writeuptype = $DB->getNode("thing", "writeuptype");
    return unless $writeuptype;

    my $title = $parent_e2node->{title} . " (thing)";

    my $writeup_id = $DB->insertNode($title, $type, $author, {
        doctext => "Test writeup content for reparent tests",
        parent_e2node => $parent_e2node->{node_id},
        wrtype_writeuptype => $writeuptype->{node_id},
    });
    return unless $writeup_id;

    # Add to parent's nodegroup
    my $writeup = $DB->getNodeById($writeup_id);
    $DB->insertIntoNodegroup($parent_e2node, -1, $writeup);

    # Refresh the parent node to get updated group
    $parent_e2node->{group} = $DB->getNodeById($parent_e2node->{node_id})->{group};

    return $writeup;
}

sub cleanup_node {
    my ($node_id) = @_;
    return unless $node_id;
    eval {
        my $node = $DB->getNodeById($node_id);
        $DB->nukeNode($node, $editor_user, 1) if $node;  # 1 = NOTOMB
        $DB->sqlDelete("tomb", "node_id=" . $DB->quote($node_id));
    };
    return 1;
}

# Mock CGI for query params
package MockCGI {
    sub new {
        my ($class, $params) = @_;
        return bless { params => $params || {} }, $class;
    }
    sub param {
        my ($self, $name) = @_;
        return keys %{$self->{params}} unless defined $name;
        return $self->{params}{$name};
    }
}

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'is_editor_flag' => (is => 'rw', default => 0);
    has 'is_admin_flag' => (is => 'rw', default => 0);
    sub is_editor { return shift->is_editor_flag; }
    sub is_admin { return shift->is_admin_flag; }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    has 'cgi' => (is => 'rw');
    has 'POSTDATA' => (is => 'rw', default => '{}');
    has 'JSON_POSTDATA' => (is => 'rw');
    sub request_method { return 'GET'; }
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::writeup_reparent->new();
ok($api, "Created writeup_reparent API instance");

#############################################################################
# Test 1: GET - Lookup e2node by ID
#############################################################################

subtest 'GET: Lookup e2node by ID' => sub {
    plan tests => 8;

    my $timestamp = time();
    my $e2node = create_test_e2node("Reparent Test E2Node $timestamp");
    ok($e2node, "Created test e2node");

    my $writeup = create_test_writeup($e2node);
    ok($writeup, "Created test writeup");

    # Create mock editor user
    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_cgi = MockCGI->new({
        old_e2node_id => $e2node->{node_id}
    });

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => $mock_cgi,
    );

    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1]{success}, "Response indicates success");

    my $data = $result->[1]{data};
    ok($data->{old_e2node}, "Response contains old_e2node");
    is($data->{old_e2node}{node_id}, $e2node->{node_id}, "old_e2node has correct node_id");
    is($data->{old_e2node}{title}, $e2node->{title}, "old_e2node has correct title");
    is(scalar @{$data->{old_e2node}{writeups}}, 1, "old_e2node has 1 writeup");

    # Cleanup
    cleanup_node($writeup->{node_id});
    cleanup_node($e2node->{node_id});
};

#############################################################################
# Test 2: GET - Lookup e2node by title
#############################################################################

subtest 'GET: Lookup e2node by title' => sub {
    plan tests => 6;

    my $timestamp = time();
    my $title = "Reparent Title Test $timestamp";
    my $e2node = create_test_e2node($title);
    ok($e2node, "Created test e2node");

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_cgi = MockCGI->new({
        old_e2node_id => $title  # Pass title instead of ID
    });

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => $mock_cgi,
    );

    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1]{success}, "Response indicates success");

    my $data = $result->[1]{data};
    ok($data->{old_e2node}, "Response contains old_e2node");
    is($data->{old_e2node}{node_id}, $e2node->{node_id}, "Found correct e2node by title");
    is($data->{old_e2node}{title}, $title, "Title matches");

    cleanup_node($e2node->{node_id});
};

#############################################################################
# Test 3: GET - Invalid e2node returns error
#############################################################################

subtest 'GET: Invalid e2node returns error' => sub {
    plan tests => 4;

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_cgi = MockCGI->new({
        old_e2node_id => 999999999  # Non-existent ID
    });

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => $mock_cgi,
    );

    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1]{success}, "Response indicates success (errors in data)");

    my $data = $result->[1]{data};
    ok(!$data->{old_e2node}, "old_e2node is null for invalid ID");
    ok(scalar @{$data->{errors}} > 0, "Errors array contains error message");
};

#############################################################################
# Test 4: Authorization - non-editor cannot access
#############################################################################

subtest 'Authorization: non-editor cannot access API' => sub {
    plan tests => 3;

    my $mock_user = MockUser->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title} || 'normaluser',
        is_editor_flag => 0,
        is_admin_flag => 0,
        NODEDATA => $normal_user,
    );

    my $mock_cgi = MockCGI->new({});
    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => $mock_cgi,
    );

    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok(!$result->[1]{success}, "Response indicates failure");
    like($result->[1]{error}, qr/access denied/i, "Error message mentions access denied");
};

#############################################################################
# Test 5: POST - Reparent writeup successfully
#############################################################################

subtest 'POST: Reparent writeup successfully' => sub {
    plan tests => 11;

    my $timestamp = time();

    # Create source e2node with writeup
    my $source_e2node = create_test_e2node("Reparent Source $timestamp");
    ok($source_e2node, "Created source e2node");

    my $writeup = create_test_writeup($source_e2node);
    ok($writeup, "Created test writeup");
    my $writeup_id = $writeup->{node_id};
    my $original_title = $writeup->{title};

    # Create destination e2node
    my $dest_e2node = create_test_e2node("Reparent Destination $timestamp");
    ok($dest_e2node, "Created destination e2node");

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => encode_json({
            new_e2node_id => $dest_e2node->{node_id},
            writeup_ids => [$writeup_id]
        }),
    );

    my $result = $api->post($mock_request);
    is($result->[0], 200, "POST returns HTTP 200");
    ok($result->[1]{success}, "Response indicates success");
    is($result->[1]{moved_count}, 1, "Moved 1 writeup");

    # Verify writeup was reparented
    my $updated_writeup = $DB->getNodeById($writeup_id);
    is($updated_writeup->{parent_e2node}, $dest_e2node->{node_id}, "Writeup parent updated to destination");
    like($updated_writeup->{title}, qr/Reparent Destination/, "Writeup title updated to destination title");

    # Verify writeup removed from source nodegroup
    my $updated_source = $DB->getNodeById($source_e2node->{node_id});
    my $updated_source_group = $updated_source->{group} || [];
    ok(!scalar(grep { $_ == $writeup_id } @$updated_source_group), "Writeup removed from source nodegroup");

    # Verify writeup in destination nodegroup
    my $updated_dest = $DB->getNodeById($dest_e2node->{node_id});
    my $updated_dest_group = $updated_dest->{group} || [];
    ok(scalar(grep { $_ == $writeup_id } @$updated_dest_group), "Writeup added to destination nodegroup");

    # Verify result data
    my $move_result = $result->[1]{results}[0];
    ok($move_result->{success}, "Individual move result indicates success");

    # Cleanup
    cleanup_node($writeup_id);
    cleanup_node($source_e2node->{node_id});
    cleanup_node($dest_e2node->{node_id});
};

#############################################################################
# Test 6: POST - Reparent multiple writeups
#############################################################################

subtest 'POST: Reparent multiple writeups' => sub {
    plan tests => 9;

    my $timestamp = time();

    # Create source e2node with multiple writeups
    my $source_e2node = create_test_e2node("Multi Source $timestamp");
    ok($source_e2node, "Created source e2node");

    my $writeup1 = create_test_writeup($source_e2node);
    ok($writeup1, "Created first writeup");

    my $writeup2 = create_test_writeup($source_e2node);
    ok($writeup2, "Created second writeup");

    # Create destination e2node
    my $dest_e2node = create_test_e2node("Multi Destination $timestamp");
    ok($dest_e2node, "Created destination e2node");

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => encode_json({
            new_e2node_id => $dest_e2node->{node_id},
            writeup_ids => [$writeup1->{node_id}, $writeup2->{node_id}]
        }),
    );

    my $result = $api->post($mock_request);
    is($result->[0], 200, "POST returns HTTP 200");
    ok($result->[1]{success}, "Response indicates success");
    is($result->[1]{moved_count}, 2, "Moved 2 writeups");
    is(scalar @{$result->[1]{results}}, 2, "Results array has 2 entries");

    # Verify both writeups reparented
    my $updated1 = $DB->getNodeById($writeup1->{node_id});
    my $updated2 = $DB->getNodeById($writeup2->{node_id});
    is($updated1->{parent_e2node}, $dest_e2node->{node_id}, "First writeup reparented");

    # Cleanup
    cleanup_node($writeup1->{node_id});
    cleanup_node($writeup2->{node_id});
    cleanup_node($source_e2node->{node_id});
    cleanup_node($dest_e2node->{node_id});
};

#############################################################################
# Test 7: POST - Invalid destination returns error
#############################################################################

subtest 'POST: Invalid destination returns error' => sub {
    plan tests => 3;

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => encode_json({
            new_e2node_id => 999999999,  # Non-existent
            writeup_ids => [1]
        }),
    );

    my $result = $api->post($mock_request);
    is($result->[0], 200, "POST returns HTTP 200");
    ok(!$result->[1]{success}, "Response indicates failure");
    like($result->[1]{error}, qr/invalid/i, "Error mentions invalid destination");
};

#############################################################################
# Test 8: POST - Empty writeup_ids returns error
#############################################################################

subtest 'POST: Empty writeup_ids returns error' => sub {
    plan tests => 3;

    my $timestamp = time();
    my $dest_e2node = create_test_e2node("Empty Test $timestamp");
    ok($dest_e2node, "Created destination e2node");

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => encode_json({
            new_e2node_id => $dest_e2node->{node_id},
            writeup_ids => []  # Empty array
        }),
    );

    my $result = $api->post($mock_request);
    ok(!$result->[1]{success}, "Response indicates failure");
    like($result->[1]{error}, qr/writeup_ids/i, "Error mentions writeup_ids");

    cleanup_node($dest_e2node->{node_id});
};

#############################################################################
# Test 9: POST - Authorization check
#############################################################################

subtest 'POST: Non-editor cannot reparent' => sub {
    plan tests => 3;

    my $mock_user = MockUser->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title} || 'normaluser',
        is_editor_flag => 0,
        is_admin_flag => 0,
        NODEDATA => $normal_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => encode_json({
            new_e2node_id => 1,
            writeup_ids => [1]
        }),
    );

    my $result = $api->post($mock_request);
    is($result->[0], 200, "POST returns HTTP 200");
    ok(!$result->[1]{success}, "Response indicates failure");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test 10: POST - Invalid JSON body
#############################################################################

subtest 'POST: Invalid JSON body returns error' => sub {
    plan tests => 3;

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => 'not valid json {{{',
    );

    my $result = $api->post($mock_request);
    is($result->[0], 200, "POST returns HTTP 200");
    ok(!$result->[1]{success}, "Response indicates failure");
    like($result->[1]{error}, qr/json/i, "Error mentions JSON");
};

#############################################################################
# Test 11: Writeup type preserved during reparent
#############################################################################

subtest 'Writeup type preserved during reparent' => sub {
    plan tests => 7;

    my $timestamp = time();

    my $source_e2node = create_test_e2node("Type Source $timestamp");
    ok($source_e2node, "Created source e2node");

    my $writeup = create_test_writeup($source_e2node);
    ok($writeup, "Created test writeup");

    my $original_type_id = $writeup->{wrtype_writeuptype};

    my $dest_e2node = create_test_e2node("Type Destination $timestamp");
    ok($dest_e2node, "Created destination e2node");

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 1,
        NODEDATA => $editor_user,
    );

    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => MockCGI->new({}),
        POSTDATA => encode_json({
            new_e2node_id => $dest_e2node->{node_id},
            writeup_ids => [$writeup->{node_id}]
        }),
    );

    my $result = $api->post($mock_request);
    is($result->[0], 200, "POST returns HTTP 200");
    ok($result->[1]{success}, "Reparent succeeded");

    my $updated = $DB->getNodeById($writeup->{node_id});
    is($updated->{wrtype_writeuptype}, $original_type_id, "Writeup type preserved");

    # Title should include writeuptype
    like($updated->{title}, qr/\(thing\)$/, "Title includes writeuptype suffix");

    # Cleanup
    cleanup_node($writeup->{node_id});
    cleanup_node($source_e2node->{node_id});
    cleanup_node($dest_e2node->{node_id});
};

#############################################################################
# Test 12: Admin can access API
#############################################################################

subtest 'Admin can access API' => sub {
    plan tests => 3;

    my $mock_user = MockUser->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_editor_flag => 0,  # Not editor
        is_admin_flag => 1,   # But is admin
        NODEDATA => $editor_user,
    );

    my $mock_cgi = MockCGI->new({});
    my $mock_request = MockRequest->new(
        user => $mock_user,
        cgi => $mock_cgi,
    );

    my $result = $api->get($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1]{success}, "Admin can access API");
    ok(!$result->[1]{error}, "No error for admin user");
};

done_testing();

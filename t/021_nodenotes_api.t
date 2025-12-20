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
use Everything::API::nodenotes;
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
# Test Node Notes API functionality
#
# These tests verify:
# 1. GET /api/nodenotes/:node_id - Get notes for a node
# 2. POST /api/nodenotes/:node_id/create - Add a note to a node
# 3. DELETE /api/nodenotes/:node_id/:note_id/delete - Delete a note
# 4. Proper error handling for all endpoints
# 5. Authorization checks
# 6. Both operations return updated notes list
#############################################################################

# Get an editor user for API operations
my $editor_user = $DB->getNode("root", "user");
if (!$editor_user) {
    $editor_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "in_group=3 LIMIT 1");
}
ok($editor_user, "Got editor user for tests");
diag("Editor user ID: " . ($editor_user ? $editor_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

sub create_test_node {
    my ($title, $type_name) = @_;

    my $type = $DB->getNode($type_name, "nodetype");
    return unless $type;

    my $node_id = $DB->insertNode($title, $type, $editor_user, {
        doctext => "Test content for API tests",
    });
    return unless $node_id;

    return $DB->getNodeById($node_id);
}

sub cleanup_node {
    my ($node_id) = @_;
    # Delete any notes
    $DB->sqlDelete("nodenote", "nodenote_nodeid=" . $DB->quote($node_id));
    # Try to nuke if exists
    my $node = $DB->getNodeById($node_id);
    $DB->nukeNode($node, $editor_user, 1) if $node;  # 1 = NOTOMB
    # Clean tomb if exists
    $DB->sqlDelete("tomb", "node_id=" . $DB->quote($node_id));
}

# Mock User object for testing
package MockUser {
    use Moose;
    has 'node_id' => (is => 'rw');
    has 'is_editor_flag' => (is => 'rw', default => 1);
    has 'is_admin_flag' => (is => 'rw', default => 0);
    sub is_editor { return shift->is_editor_flag; }
    sub is_admin { return shift->is_admin_flag; }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    has '_postdata' => (is => 'rw', default => sub { {} });
    sub JSON_POSTDATA { return shift->_postdata; }
}
package main;

# Create API instance
my $api = Everything::API::nodenotes->new();
ok($api, "Created API instance");

#############################################################################
# Test 1: GET /api/nodenotes/:node_id - Existing functionality
#############################################################################

my $test_node = create_test_node("Test Node Notes API " . time(), "document");
ok($test_node, "Created test node");
my $node_id = $test_node->{node_id};

# Get notes for node with no notes
my $mock_user = MockUser->new(
    node_id => $editor_user->{node_id},
    is_editor_flag => 1  # Set to 1 since we're testing with an editor
);
my $mock_request = MockRequest->new(user => $mock_user);
my $result = $api->get_node_notes($mock_request, $node_id);
is($result->[0], 200, "GET returns 200 for node with no notes");
is(ref($result->[1]), 'HASH', "GET returns hash response");
is($result->[1]{count}, 0, "GET shows 0 notes for new node");
is($result->[1]{node_id}, $node_id, "GET response includes node_id");
ok(exists $result->[1]{notes}, "GET response includes notes array");

# GET with invalid node_id
$result = $api->get_node_notes($mock_request, "invalid");
is($result->[0], 400, "GET returns 400 for invalid node_id");
like($result->[1]{error}, qr/Invalid node_id/, "GET error message mentions invalid node_id");

# GET with non-existent node
$result = $api->get_node_notes($mock_request, 999999999);
is($result->[0], 404, "GET returns 404 for non-existent node");
like($result->[1]{error}, qr/Node not found/, "GET error message mentions not found");

#############################################################################
# Test 2: POST /api/nodenotes/:node_id/create - Add note
#############################################################################

# Add a note successfully
$mock_request->_postdata({ notetext => "First test note via API" });
my $add_result = $api->add_note($mock_request, $node_id);
is($add_result->[0], 200, "POST returns 200 for successful note creation");
is(ref($add_result->[1]), 'HASH', "POST returns hash response");
is($add_result->[1]{count}, 1, "POST response shows 1 note after creation");
ok(ref($add_result->[1]{notes}) eq 'ARRAY', "POST response includes notes array");
is(scalar(@{$add_result->[1]{notes}}), 1, "POST response notes array has 1 note");
like($add_result->[1]{notes}[0]{notetext}, qr/First test note/, "POST created note has correct text");
is($add_result->[1]{notes}[0]{noter_user}, $editor_user->{node_id}, "POST note has correct noter_user");
ok($add_result->[1]{notes}[0]{noter_username}, "POST note includes noter_username");
is($add_result->[1]{notes}[0]{noter_username}, $editor_user->{title}, "POST note has correct noter_username");

my $note_id_1 = $add_result->[1]{notes}[0]{nodenote_id};
ok($note_id_1, "Got note_id from POST response");

# Add a second note
$mock_request->_postdata({ notetext => "Second test note via API" });
my $add_result2 = $api->add_note($mock_request, $node_id);
is($add_result2->[0], 200, "POST returns 200 for second note");
is($add_result2->[1]{count}, 2, "POST response shows 2 notes after second creation");

my $note_id_2 = $add_result2->[1]{notes}[1]{nodenote_id};
ok($note_id_2, "Got note_id from second POST response");
ok($note_id_2 != $note_id_1, "Second note has different ID");

# Verify notes are ordered by timestamp
my $check_order = $api->get_node_notes($mock_request, $node_id);
like($check_order->[1]{notes}[0]{notetext}, qr/First/, "First note appears first");
like($check_order->[1]{notes}[1]{notetext}, qr/Second/, "Second note appears second");

#############################################################################
# Test 3: POST Error Cases
#############################################################################

# POST with missing notetext
$mock_request->_postdata({});
my $bad_result = $api->add_note($mock_request, $node_id);
is($bad_result->[0], 400, "POST returns 400 for missing notetext");
like($bad_result->[1]{error}, qr/Missing notetext/, "POST error message mentions missing notetext");

# POST with empty notetext
$mock_request->_postdata({ notetext => "" });
my $empty_result = $api->add_note($mock_request, $node_id);
is($empty_result->[0], 400, "POST returns 400 for empty notetext");
like($empty_result->[1]{error}, qr/cannot be empty/, "POST error message mentions empty text");

# POST to non-existent node
$mock_request->_postdata({ notetext => "Note to nowhere" });
my $notfound_result = $api->add_note($mock_request, 999999999);
is($notfound_result->[0], 404, "POST returns 404 for non-existent node");
like($notfound_result->[1]{error}, qr/Node not found/, "POST error message mentions not found");

# POST with invalid node_id
$mock_request->_postdata({ notetext => "Note to invalid" });
my $invalid_result = $api->add_note($mock_request, "abc");
is($invalid_result->[0], 400, "POST returns 400 for invalid node_id");
like($invalid_result->[1]{error}, qr/Invalid node_id/, "POST error message mentions invalid node_id");

#############################################################################
# Test 4: DELETE /api/nodenotes/:node_id/:note_id/delete
#############################################################################

# Delete first note successfully
my $delete_result = $api->delete_note($mock_request, $node_id, $note_id_1);
is($delete_result->[0], 200, "DELETE returns 200 for successful deletion");
is($delete_result->[1]{count}, 1, "DELETE response shows 1 note remaining");
is($delete_result->[1]{notes}[0]{nodenote_id}, $note_id_2, "DELETE response shows correct remaining note");

# Verify GET shows updated list
my $after_delete = $api->get_node_notes($mock_request, $node_id);
is($after_delete->[1]{count}, 1, "GET after DELETE shows 1 note");
is($after_delete->[1]{notes}[0]{nodenote_id}, $note_id_2, "GET after DELETE shows correct note");

# Delete second note
my $delete_result2 = $api->delete_note($mock_request, $node_id, $note_id_2);
is($delete_result2->[0], 200, "DELETE returns 200 for second deletion");
is($delete_result2->[1]{count}, 0, "DELETE response shows 0 notes after deleting all");

# Verify empty state
my $final_check = $api->get_node_notes($mock_request, $node_id);
is($final_check->[1]{count}, 0, "GET after all DELETEs shows 0 notes");

#############################################################################
# Test 5: DELETE Error Cases
#############################################################################

# DELETE non-existent note
my $delete_notfound = $api->delete_note($mock_request, $node_id, 999999999);
is($delete_notfound->[0], 404, "DELETE returns 404 for non-existent note");
like($delete_notfound->[1]{error}, qr/Note not found/, "DELETE error message mentions not found");

# DELETE with invalid note_id
my $delete_invalid = $api->delete_note($mock_request, $node_id, "abc");
is($delete_invalid->[0], 400, "DELETE returns 400 for invalid note_id");
like($delete_invalid->[1]{error}, qr/Invalid note_id/, "DELETE error message mentions invalid note_id");

# DELETE with invalid node_id
my $delete_badnode = $api->delete_note($mock_request, "abc", 123);
is($delete_badnode->[0], 400, "DELETE returns 400 for invalid node_id");
like($delete_badnode->[1]{error}, qr/Invalid node_id/, "DELETE error message mentions invalid node_id");

# DELETE from non-existent node
my $delete_nonode = $api->delete_note($mock_request, 999999999, 999999999);
is($delete_nonode->[0], 404, "DELETE returns 404 for non-existent node");

#############################################################################
# Test 6: Integration - Full workflow
#############################################################################

# Create node, add notes, delete some, verify state
my $workflow_node = create_test_node("Workflow Test " . time(), "document");
if ($workflow_node) {
    my $wf_id = $workflow_node->{node_id};

    # Add 3 notes
    $mock_request->_postdata({ notetext => "Workflow Note 1" });
    my $wf_add1 = $api->add_note($mock_request, $wf_id);

    $mock_request->_postdata({ notetext => "Workflow Note 2" });
    my $wf_add2 = $api->add_note($mock_request, $wf_id);

    $mock_request->_postdata({ notetext => "Workflow Note 3" });
    my $wf_add3 = $api->add_note($mock_request, $wf_id);

    is($wf_add3->[1]{count}, 3, "Workflow: Added 3 notes successfully");

    # Delete middle note
    my $wf_note2_id = $wf_add2->[1]{notes}[1]{nodenote_id};
    my $wf_del = $api->delete_note($mock_request, $wf_id, $wf_note2_id);
    is($wf_del->[1]{count}, 2, "Workflow: 2 notes remain after deleting one");

    # Verify final state
    my $wf_final = $api->get_node_notes($mock_request, $wf_id);
    is($wf_final->[1]{count}, 2, "Workflow: Final GET shows 2 notes");
    like($wf_final->[1]{notes}[0]{notetext}, qr/Note 1/, "Workflow: First note still present");
    like($wf_final->[1]{notes}[1]{notetext}, qr/Note 3/, "Workflow: Third note still present");

    cleanup_node($wf_id);
} else {
    pass("Skipped workflow test (could not create node)");
    pass("");
    pass("");
    pass("");
    pass("");
}

#############################################################################
# Test 7: Note association with node (can't delete note from wrong node)
#############################################################################

# Create another test node for cross-node testing
my $other_node = create_test_node("Other Node " . time(), "document");
if ($other_node) {
    my $other_id = $other_node->{node_id};

    # Add note to first node
    $mock_request->_postdata({ notetext => "Note on first node" });
    my $cross_add = $api->add_note($mock_request, $node_id);
    my $cross_note_id = $cross_add->[1]{notes}[0]{nodenote_id};

    # Try to delete note using wrong node_id
    my $cross_delete = $api->delete_note($mock_request, $other_id, $cross_note_id);
    is($cross_delete->[0], 404, "DELETE returns 404 when note doesn't belong to node");
    like($cross_delete->[1]{error}, qr/not associated/, "DELETE error mentions association");

    # Verify note still exists on original node
    my $cross_check = $api->get_node_notes($mock_request, $node_id);
    is($cross_check->[1]{count}, 1, "Note still exists on correct node after failed delete");

    cleanup_node($other_id);
} else {
    pass("Skipped cross-node test (could not create second node)");
    pass("");
    pass("");
}

#############################################################################
# Test Legacy Format Handling (noter_user = 1)
#############################################################################

subtest 'Legacy format note handling' => sub {
    plan tests => 12;

    # Create a test node for legacy notes
    my $legacy_node = create_test_node("Legacy Note Test Node", "document");
    ok($legacy_node, "Created test node for legacy notes");
    my $legacy_node_id = $legacy_node->{node_id};

    # Manually insert a legacy format note (noter_user = 1)
    my $legacy_note_id = $DB->sqlInsert("nodenote", {
        nodenote_nodeid => $legacy_node_id,
        notetext => "[root[user]]: This is an old-style note with author in text",
        noter_user => 1,  # Legacy format marker
        timestamp => "2020-01-01 12:00:00",
    });
    ok($legacy_note_id, "Inserted legacy format note");

    # Insert a modern format note for comparison
    my $modern_note_id = $DB->sqlInsert("nodenote", {
        nodenote_nodeid => $legacy_node_id,
        notetext => "This is a modern note",
        noter_user => $editor_user->{node_id},
        timestamp => "2025-01-01 12:00:00",
    });
    ok($modern_note_id, "Inserted modern format note");

    # GET notes and check legacy_format flag
    my $result = $api->get_node_notes($mock_request, $legacy_node_id);
    is($result->[0], 200, "GET returns 200");
    is(scalar(@{$result->[1]{notes}}), 2, "GET returns 2 notes");

    # Find and verify the legacy note (match by notetext since sqlInsert doesn't return the ID)
    my $legacy_note = (grep { $_->{notetext} =~ /old-style note/ } @{$result->[1]{notes}})[0];
    ok($legacy_note, "Found legacy note in results");
    ok($legacy_note->{legacy_format}, "Legacy note has legacy_format flag set");
    ok(!exists $legacy_note->{noter_username}, "Legacy note does not have noter_username");

    # Find and verify the modern note
    my $modern_note = (grep { $_->{notetext} eq 'This is a modern note' } @{$result->[1]{notes}})[0];
    ok($modern_note, "Found modern note in results");
    ok(!$modern_note->{legacy_format}, "Modern note does not have legacy_format flag");
    ok($modern_note->{noter_username}, "Modern note has noter_username");
    is($modern_note->{noter_username}, $editor_user->{title}, "Modern note has correct noter_username");

    cleanup_node($legacy_node_id);
};

#############################################################################
# Cleanup
#############################################################################

cleanup_node($node_id);

done_testing;

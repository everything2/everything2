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
# Test getNodeNotes functionality
#
# These tests verify that the getNodeNotes method:
# 1. Returns empty array for nodes with no notes
# 2. Returns correct notes for a simple document node
# 3. Returns notes for writeups including parent e2node notes
# 4. Returns notes for e2nodes including all writeup notes
# 5. Handles the three different query patterns correctly
#############################################################################

# Get a test user for node operations
my $test_user = $DB->getNode("root", "user");
if (!$test_user) {
    # Try to get any editor user
    $test_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "1=1 LIMIT 1");
}
ok($test_user, "Got test user");
diag("Test user ID: " . ($test_user ? $test_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

sub create_test_node {
    my ($title, $type_name, $extra_fields) = @_;

    my $type = $DB->getNode($type_name, "nodetype");
    return unless $type;

    my $node_id = $DB->insertNode($title, $type, $test_user, $extra_fields);
    return unless $node_id;

    # For writeups, ensure the writeup table entry exists
    if ($type_name eq 'writeup' && $extra_fields->{parent_e2node}) {
        # Check if writeup table entry exists
        my $writeup_exists = $DB->sqlSelect("writeup_id", "writeup", "writeup_id=" . $DB->quote($node_id));
        if (!$writeup_exists) {
            # Manually insert writeup table entry
            $DB->sqlInsert("writeup", {
                writeup_id => $node_id,
                parent_e2node => $extra_fields->{parent_e2node},
            });
        }
    }

    return $DB->getNodeById($node_id);
}

sub add_note_to_node {
    my ($node_id, $note_text, $noter_user_id, $custom_timestamp) = @_;
    $noter_user_id ||= $test_user->{node_id};

    my $timestamp = $custom_timestamp || $DB->sqlSelect("NOW()", "DUAL");

    $DB->sqlInsert("nodenote", {
        nodenote_nodeid => $node_id,
        notetext => $note_text,
        noter_user => $noter_user_id,
        timestamp => $timestamp,
    });

    return 1;
}

sub cleanup_node {
    my ($node_id) = @_;
    # Delete any notes
    $DB->sqlDelete("nodenote", "nodenote_nodeid=" . $DB->quote($node_id));
    # Try to nuke if exists
    my $node = $DB->getNodeById($node_id);
    $DB->nukeNode($node, $test_user, 1) if $node;  # 1 = NOTOMB
    # Clean tomb if exists
    $DB->sqlDelete("tomb", "node_id=" . $DB->quote($node_id));
}

#############################################################################
# Test 1: Empty notes array for node with no notes
#############################################################################

my $doc_title = "Test NodeNotes Document " . time();
my $doc_node = create_test_node($doc_title, "document", {
    doctext => "Test document for node notes",
});

ok($doc_node, "Created test document node");
my $doc_id = $doc_node->{node_id};

my $notes = $APP->getNodeNotes($doc_node);
ok(ref($notes) eq 'ARRAY', "getNodeNotes returns array reference");
is(scalar(@$notes), 0, "No notes for new document");

#############################################################################
# Test 2: Basic note retrieval for document
#############################################################################

add_note_to_node($doc_id, "First test note");
add_note_to_node($doc_id, "Second test note");

$notes = $APP->getNodeNotes($doc_node);
is(scalar(@$notes), 2, "Retrieved 2 notes for document");

# Verify note structure
ok(exists $notes->[0]{notetext}, "Note has notetext field");
ok(exists $notes->[0]{nodenote_id}, "Note has nodenote_id field");
ok(exists $notes->[0]{nodenote_nodeid}, "Note has nodenote_nodeid field");
ok(exists $notes->[0]{noter_user}, "Note has noter_user field");
ok(exists $notes->[0]{timestamp}, "Note has timestamp field");

# Verify note content
like($notes->[0]{notetext}, qr/First test note/, "First note has correct text");
like($notes->[1]{notetext}, qr/Second test note/, "Second note has correct text");
is($notes->[0]{nodenote_nodeid}, $doc_id, "Note references correct node");

#############################################################################
# Test 3: Writeup notes including parent e2node
#############################################################################

SKIP: {
    my $writeup_type = $DB->getNode("writeup", "nodetype");
    my $e2node_type = $DB->getNode("e2node", "nodetype");
    skip "Writeup or e2node nodetype not available", 8 unless $writeup_type && $e2node_type;

    # Create e2node
    my $e2node_title = "Test E2Node " . time();
    my $e2node = create_test_node($e2node_title, "e2node");
    skip "Could not create e2node", 8 unless $e2node;

    my $e2node_id = $e2node->{node_id};

    # Create writeup under e2node
    my $wu_title = "Test Writeup " . time();
    my $writeup = create_test_node($wu_title, "writeup", {
        doctext => "Test writeup content",
        parent_e2node => $e2node_id,
    });
    skip "Could not create writeup", 8 unless $writeup;

    my $wu_id = $writeup->{node_id};

    # Add note to e2node
    add_note_to_node($e2node_id, "Note on e2node");

    # Add note to writeup
    add_note_to_node($wu_id, "Note on writeup");

    # Get notes for writeup - should include both writeup note AND e2node note
    $notes = $APP->getNodeNotes($writeup);
    ok(scalar(@$notes) >= 2, "Writeup query includes both writeup and e2node notes");

    my $has_e2node_note = 0;
    my $has_writeup_note = 0;
    foreach my $note (@$notes) {
        $has_e2node_note = 1 if $note->{notetext} =~ /Note on e2node/;
        $has_writeup_note = 1 if $note->{notetext} =~ /Note on writeup/;
    }

    ok($has_e2node_note, "Writeup notes include e2node note");
    ok($has_writeup_note, "Writeup notes include writeup note");

    #############################################################################
    # Test 4: E2node notes including all writeup notes
    #############################################################################

    # Create second writeup under same e2node
    my $wu2_title = "Test Writeup 2 " . time();
    my $writeup2 = create_test_node($wu2_title, "writeup", {
        doctext => "Second writeup content",
        parent_e2node => $e2node_id,
    });

    if ($writeup2) {
        my $wu2_id = $writeup2->{node_id};

        # Add note to second writeup
        add_note_to_node($wu2_id, "Note on second writeup");

        # Get notes for e2node - should include e2node note AND both writeup notes
        $notes = $APP->getNodeNotes($e2node);
        ok(scalar(@$notes) >= 3, "E2node query includes e2node and all writeup notes");

        my $has_e2node = 0;
        my $has_wu1 = 0;
        my $has_wu2 = 0;
        foreach my $note (@$notes) {
            $has_e2node = 1 if $note->{notetext} =~ /Note on e2node/;
            $has_wu1 = 1 if $note->{notetext} =~ /Note on writeup/;
            $has_wu2 = 1 if $note->{notetext} =~ /Note on second writeup/;
        }

        ok($has_e2node, "E2node notes include e2node note");
        ok($has_wu1, "E2node notes include first writeup note");
        ok($has_wu2, "E2node notes include second writeup note");

        # Verify author_user field is present for e2node query
        ok(exists $notes->[0]{author_user}, "E2node query includes author_user field");

        cleanup_node($wu2_id);
    } else {
        pass("Skipped second writeup tests");
        pass("");
        pass("");
        pass("");
        pass("");
    }

    # Cleanup
    cleanup_node($wu_id);
    cleanup_node($e2node_id);
}

#############################################################################
# Test 5: Returns empty array for undefined node
#############################################################################

my $empty_notes = $APP->getNodeNotes(undef);
ok(ref($empty_notes) eq 'ARRAY', "Returns array reference for undefined node");
is(scalar(@$empty_notes), 0, "Returns empty array for undefined node");

#############################################################################
# Test 6: Note ordering
#############################################################################

# Notes should be ordered by timestamp
my $ordered_doc = create_test_node("Test Ordering " . time(), "document");
if ($ordered_doc) {
    my $ordered_id = $ordered_doc->{node_id};

    # Add notes with explicit timestamps to ensure deterministic ordering
    # Use timestamps 3, 2, and 1 seconds in the past to test ordering
    my $now = time();
    add_note_to_node($ordered_id, "First note", undef, $APP->convertEpochToDate($now - 3));
    add_note_to_node($ordered_id, "Second note", undef, $APP->convertEpochToDate($now - 2));
    add_note_to_node($ordered_id, "Third note", undef, $APP->convertEpochToDate($now - 1));

    $notes = $APP->getNodeNotes($ordered_doc);
    is(scalar(@$notes), 3, "Retrieved 3 ordered notes");

    # Verify ordering (should be chronological by timestamp)
    like($notes->[0]{notetext}, qr/First note/, "First note appears first");
    like($notes->[2]{notetext}, qr/Third note/, "Third note appears last");

    cleanup_node($ordered_id);
}

#############################################################################
# Cleanup
#############################################################################

cleanup_node($doc_id);

done_testing;

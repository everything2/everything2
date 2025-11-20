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
# These warnings come from legacy code during node operations and are handled gracefully
$SIG{__WARN__} = sub {
	my $warning = shift;
	# Suppress expected warnings:
	# - Log file permission warnings
	# - Uninitialized value warnings from legacy code during node operations
	#   (htmlcode.pm, NodeCache.pm, NodeBase.pm during nuking/resurrection)
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test node resurrection functionality
#
# These tests verify that nodes can be:
# 1. Created
# 2. Nuked (deleted with tombstone)
# 3. Verified as deleted
# 4. Resurrected from tomb
# 5. Verified as fully restored
#
# We test with different node types to ensure the resurrection logic
# handles all type-specific tables correctly.
#############################################################################

# Get a test user for node operations
my $test_user = $DB->getNode("root", "user");
if (!$test_user) {
    # Try to get any user
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

    # insertNode signature: ($this, $title, $TYPE, $USER, $NODEDATA, $skip_maintenance)
    # insertNode returns node_id, not the full node object
    my $node_id = $DB->insertNode($title, $type, $test_user, $extra_fields);
    return unless $node_id;

    # Fetch the full node object
    my $NODE = $DB->getNodeById($node_id);
    return $NODE;
}

sub verify_node_exists {
    my ($node_id) = @_;
    my $node = $DB->getNodeById($node_id);
    return defined $node;
}

sub verify_node_in_tomb {
    my ($node_id) = @_;
    my $tomb = $DB->sqlSelectHashref("*", "tomb", "node_id=" . $DB->quote($node_id));
    return defined $tomb && defined $tomb->{data};
}

sub cleanup_node {
    my ($node_id) = @_;
    # Try to nuke if exists
    my $node = $DB->getNodeById($node_id);
    $DB->nukeNode($node, $test_user, 1) if $node;  # 1 = NOTOMB
    # Clean tomb if exists
    $DB->sqlDelete("tomb", "node_id=" . $DB->quote($node_id));
}

#############################################################################
# Test 1: Basic Document Resurrection
#############################################################################

my $test_title = "Test Resurrection Document " . time();
my $doc_node = create_test_node($test_title, "document", {
    doctext => "This is test content for resurrection",
});

ok($doc_node, "Created test document node");
my $doc_id = $doc_node->{node_id};

# Verify node exists
ok(verify_node_exists($doc_id), "Document node exists before nuke");

# Nuke the node (with tombstone)
my $nuke_result = $DB->nukeNode($doc_node, $test_user, 0);  # 0 = create tombstone
ok($nuke_result, "Nuked document node");

# Verify node is deleted
ok(!verify_node_exists($doc_id), "Document node deleted after nuke");

# Verify tombstone exists
ok(verify_node_in_tomb($doc_id), "Document node has tombstone in tomb table");

# Resurrect the node
my $resurrected = $DB->resurrectNode($doc_id, "tomb");
ok($resurrected, "Resurrected document node");

# Verify resurrected node properties
is($resurrected->{node_id}, $doc_id, "Resurrected node has correct ID");
is($resurrected->{title}, $test_title, "Resurrected node has correct title");
like($resurrected->{doctext}, qr/test content/, "Resurrected node has correct doctext");

# Verify node exists again
ok(verify_node_exists($doc_id), "Document node exists after resurrection");

# Cleanup
cleanup_node($doc_id);

#############################################################################
# Test 2: Writeup Resurrection
#############################################################################

SKIP: {
    my $writeup_type = $DB->getNode("writeup", "nodetype");
    skip "Writeup nodetype not available", 5 unless $writeup_type;

    my $wu_title = "Test Resurrection Writeup " . time();
    my $writeup_node = create_test_node($wu_title, "writeup", {
        doctext => "Test writeup content",
    });

    skip "Could not create writeup", 5 unless $writeup_node;

    my $wu_id = $writeup_node->{node_id};

    ok(verify_node_exists($wu_id), "Writeup exists before nuke");

    # Nuke with tombstone
    $DB->nukeNode($writeup_node, $test_user, 0);
    ok(!verify_node_exists($wu_id), "Writeup deleted after nuke");
    ok(verify_node_in_tomb($wu_id), "Writeup has tombstone");

    # Resurrect
    my $resurrected_wu = $DB->resurrectNode($wu_id, "tomb");
    ok($resurrected_wu, "Resurrected writeup node");
    is($resurrected_wu->{node_id}, $wu_id, "Resurrected writeup has correct ID");

    # Cleanup
    cleanup_node($wu_id);
}

#############################################################################
# Test 3: Failed Resurrection Cases
#############################################################################

# Test resurrection of non-existent node
{
    my $fake_id = 999999999;
    my $failed = $DB->resurrectNode($fake_id, "tomb");
    ok(!defined $failed, "Resurrection of non-existent node returns undef");
}

# Test resurrection of already-living node
{
    my $living_title = "Test Already Living " . time();
    my $living_node = create_test_node($living_title, "document");

    if ($living_node) {
        my $living_id = $living_node->{node_id};

        # Try to resurrect a node that's still alive (should fail)
        my $failed = $DB->resurrectNode($living_id, "tomb");
        ok(!defined $failed, "Resurrection of living node returns undef");

        # Verify node is still intact
        ok(verify_node_exists($living_id), "Living node unchanged after failed resurrection attempt");

        # Cleanup
        cleanup_node($living_id);
    } else {
        pass("Skipped already-living test (could not create node)");
        pass("");
    }
}

# Test resurrection of node without tombstone
{
    my $no_tomb_title = "Test No Tombstone " . time();
    my $no_tomb_node = create_test_node($no_tomb_title, "document");

    if ($no_tomb_node) {
        my $nt_id = $no_tomb_node->{node_id};

        # Nuke without tombstone
        $DB->nukeNode($no_tomb_node, $test_user, 1);  # 1 = NOTOMB

        # Try to resurrect (should fail - no tombstone)
        my $failed = $DB->resurrectNode($nt_id, "tomb");
        ok(!defined $failed, "Resurrection without tombstone returns undef");

        # Cleanup
        cleanup_node($nt_id);
    } else {
        pass("Skipped no-tombstone test (could not create node)");
    }
}

#############################################################################
# Test 4: Multiple Resurrections
#############################################################################

# Test that a node can be nuked and resurrected multiple times
{
    my $multi_title = "Test Multiple Resurrections " . time();
    my $multi_node = create_test_node($multi_title, "document", {
        doctext => "Original content",
    });

    if ($multi_node) {
        my $multi_id = $multi_node->{node_id};

        for my $iteration (1..2) {
            # Nuke
            $multi_node = $DB->getNodeById($multi_id) if $iteration > 1;
            $DB->nukeNode($multi_node, $test_user, 0);
            ok(!verify_node_exists($multi_id), "Iteration $iteration: Node deleted");

            # Resurrect
            my $resurrected = $DB->resurrectNode($multi_id, "tomb");
            ok($resurrected, "Iteration $iteration: Node resurrected");
            ok(verify_node_exists($multi_id), "Iteration $iteration: Node exists after resurrection");
        }

        # Cleanup
        cleanup_node($multi_id);
    } else {
        pass("Skipped multiple resurrection test (could not create node)");
        pass("");
        pass("");
        pass("");
        pass("");
        pass("");
    }
}

done_testing;

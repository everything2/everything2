#!/usr/bin/env perl
#
# Test script to verify NodeCache eviction doesn't break node retrieval
# This tests the circular reference cleanup on cache eviction
#
use strict;
use warnings;
use lib '/var/everything/ecore';
use lib '/var/libraries/lib/perl5';

use Everything;
use Everything::NodeBase;

Everything::initEverything();

my $cache = $DB->{cache};
my $cache_size = $cache->{maxSize};

print "=== NodeCache Eviction Test ===\n\n";
print "Cache max size: $cache_size\n";

# We'll fetch 2.5x the cache size worth of nodes to force evictions
my $nodes_to_fetch = int($cache_size * 2.5);
print "Will fetch $nodes_to_fetch nodes to force evictions\n\n";

# Get a list of node IDs to test with (skip permanently cached nodes like nodetype=1)
my $sql = "SELECT node_id FROM node WHERE node_id > 1 ORDER BY node_id LIMIT ?";
my $node_ids = $DB->{dbh}->selectcol_arrayref($sql, undef, $nodes_to_fetch);

print "Found " . scalar(@$node_ids) . " nodes to test\n\n";

my $pass = 0;
my $fail = 0;
my $errors = [];

# First pass: fetch all nodes
print "Pass 1: Fetching all nodes (forcing evictions)...\n";
for my $node_id (@$node_ids) {
    my $node = $DB->getNodeById($node_id);
    if ($node && $node->{node_id} == $node_id && $node->{type} && $node->{type}{title}) {
        $pass++;
    } else {
        $fail++;
        push @$errors, "First fetch failed for node_id $node_id";
    }
}
print "  Pass: $pass, Fail: $fail\n";
print "  Cache size after first pass: " . $cache->getCacheSize() . "\n\n";

# Second pass: fetch all nodes again (some from cache, some re-fetched)
print "Pass 2: Re-fetching all nodes...\n";
$pass = 0;
$fail = 0;
for my $node_id (@$node_ids) {
    my $node = $DB->getNodeById($node_id);
    if ($node && $node->{node_id} == $node_id && $node->{type} && $node->{type}{title}) {
        $pass++;
    } else {
        $fail++;
        push @$errors, "Second fetch failed for node_id $node_id";
    }
}
print "  Pass: $pass, Fail: $fail\n";
print "  Cache size after second pass: " . $cache->getCacheSize() . "\n\n";

# Third pass: specifically test nodetype nodes (they have self-references)
print "Pass 3: Testing nodetype nodes specifically...\n";
my $type_sql = "SELECT node_id FROM node WHERE type_nodetype = 1 AND node_id > 1 LIMIT 50";
my $type_ids = $DB->{dbh}->selectcol_arrayref($type_sql);
$pass = 0;
$fail = 0;

for my $type_id (@$type_ids) {
    # Fetch, evict, fetch again
    my $type1 = $DB->getNodeById($type_id);
    $cache->removeNode($type1) if $type1;
    my $type2 = $DB->getNodeById($type_id);

    if ($type2 && $type2->{node_id} == $type_id && $type2->{type} && $type2->{type}{title}) {
        $pass++;
    } else {
        $fail++;
        push @$errors, "Nodetype re-fetch failed for node_id $type_id";
    }
}
print "  Nodetype tests - Pass: $pass, Fail: $fail\n\n";

# Report
if (@$errors) {
    print "=== ERRORS ===\n";
    for my $i (0..9) {
        last unless defined $errors->[$i];
        print "  $errors->[$i]\n";
    }
    print "  ... and " . (scalar(@$errors) - 10) . " more\n" if @$errors > 10;
}

my $total_fail = scalar(@$errors);
if ($total_fail == 0) {
    print "=== ALL TESTS PASSED ===\n";
    exit 0;
} else {
    print "=== $total_fail TESTS FAILED ===\n";
    exit 1;
}

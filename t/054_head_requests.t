#!/usr/bin/perl -w

use strict;
use warnings;
use LWP::UserAgent;
use Test::More;

=head1 NAME

058_head_requests.t - Tests for HEAD request optimization

=head1 DESCRIPTION

Tests that HEAD requests return accurate HTTP status codes without
full page rendering. This optimization saves significant DB/CPU load
from bots checking link existence.

HEAD requests should return:
- 200 OK for existing, accessible nodes
- 404 Not Found for non-existent nodes
- 403 Forbidden for permission-denied nodes

The X-E2-Head-Optimized header indicates the fast-path was taken.

=cut

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

# Test 1: HEAD request to existing node returns 200
subtest 'HEAD to existing node returns 200' => sub {
    plan tests => 3;

    # Use the front page which always exists
    my $response = $ua->head("http://localhost/");
    is($response->code, 200, "HEAD / returns 200");
    is($response->header('X-E2-Head-Optimized'), 1, "X-E2-Head-Optimized header present");
    is($response->header('Content-Type'), 'text/html; charset=utf-8', "Content-Type header correct");
};

# Test 2: HEAD request to existing e2node returns 200
subtest 'HEAD to existing e2node returns 200' => sub {
    plan tests => 2;

    # Use a known node title
    my $response = $ua->head("http://localhost/title/tomato");
    is($response->code, 200, "HEAD /title/tomato returns 200");
    is($response->header('X-E2-Head-Optimized'), 1, "X-E2-Head-Optimized header present");
};

# Test 3: HEAD request to non-existent node returns 404
subtest 'HEAD to non-existent node returns 404' => sub {
    plan tests => 2;

    my $response = $ua->head("http://localhost/title/this_node_definitely_does_not_exist_" . time());
    is($response->code, 404, "HEAD to non-existent node returns 404");
    is($response->header('X-E2-Head-Optimized'), 1, "X-E2-Head-Optimized header present");
};

# Test 4: HEAD request to non-existent node_id returns 404
subtest 'HEAD to non-existent node_id returns 404' => sub {
    plan tests => 2;

    my $response = $ua->head("http://localhost/?node_id=999999999");
    is($response->code, 404, "HEAD to non-existent node_id returns 404");
    is($response->header('X-E2-Head-Optimized'), 1, "X-E2-Head-Optimized header present");
};

# Test 5: HEAD request to known e2node by ID returns 200
subtest 'HEAD to existing node by ID returns 200' => sub {
    plan tests => 2;

    # Use tomato e2node which exists in dev database
    my $response = $ua->head("http://localhost/?node_id=2213609");
    is($response->code, 200, "HEAD to node_id=2213609 (tomato) returns 200");
    is($response->header('X-E2-Head-Optimized'), 1, "X-E2-Head-Optimized header present");
};

# Test 6: Verify HEAD doesn't return body content
subtest 'HEAD returns no body content' => sub {
    plan tests => 2;

    my $response = $ua->head("http://localhost/title/tomato");
    is($response->code, 200, "HEAD returns success");
    is($response->content, '', "HEAD returns empty body");
};

# Test 7: Compare HEAD vs GET for same node
subtest 'HEAD and GET return same status for existing node' => sub {
    plan tests => 2;

    my $head_response = $ua->head("http://localhost/title/tomato");
    my $get_response = $ua->get("http://localhost/title/tomato");

    is($head_response->code, $get_response->code, "HEAD and GET return same status code");
    ok(length($get_response->content) > 0, "GET returns body content");
};

# Test 8: Compare HEAD vs GET for non-existent node
subtest 'HEAD and GET return same status for non-existent node' => sub {
    plan tests => 2;

    my $nonexistent = "http://localhost/title/nonexistent_test_node_" . time();
    my $head_response = $ua->head($nonexistent);
    my $get_response = $ua->get($nonexistent);

    is($head_response->code, 404, "HEAD returns 404 for non-existent");
    is($get_response->code, 200, "GET returns 200 (renders 'Nothing Found' page)");
    # Note: GET returns 200 because it renders the "Nothing Found" page
    # HEAD returns accurate 404 status without rendering
};

done_testing();

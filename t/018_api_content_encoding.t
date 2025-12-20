#!/usr/bin/perl -w

# Test for GitHub Issue #3391
# Verifies that Content-Encoding headers are only set when there's actual body content
# Error responses (403, 404, 405, etc.) should NOT have Content-Encoding headers
# Success responses (200) with body content SHOULD have Content-Encoding headers

use strict;
use LWP::UserAgent;
use HTTP::Request;
use Test::More;
use JSON;

my $json = JSON->new;
my $ua = LWP::UserAgent->new;

# Test various compression types
my @encodings = ('br', 'gzip', 'deflate');

foreach my $encoding (@encodings) {
    # Test 405 Method Not Allowed (no body)
    my $request = HTTP::Request->new("GET", "http://localhost/api/");
    $request->header('Accept-Encoding' => $encoding);
    my $response = $ua->request($request);

    ok($response->code == 405, "API root returns 405 Method Not Allowed");
    ok(!defined($response->header('content-encoding')),
       "405 response has NO Content-Encoding header (requested $encoding)");

    # Test 404 Not Found (no body)
    $request = HTTP::Request->new("GET", "http://localhost/api/badroute/12345");
    $request->header('Accept-Encoding' => $encoding);
    $response = $ua->request($request);

    ok($response->code == 405, "Bad route returns 405 Method Not Allowed");
    ok(!defined($response->header('content-encoding')),
       "405 response has NO Content-Encoding header (requested $encoding)");

    # Test 403 Forbidden (attempting to access restricted node without auth)
    $request = HTTP::Request->new("POST", "http://localhost/api/sessions/create");
    $request->header('Accept-Encoding' => $encoding);
    $request->header('Content-Type' => 'application/json');
    $request->content($json->encode({"username" => "root", "passwd" => "wrongpassword"}));
    $response = $ua->request($request);

    ok($response->code == 403, "Invalid credentials return 403 Forbidden");
    ok(!defined($response->header('content-encoding')),
       "403 response has NO Content-Encoding header (requested $encoding)");
}

# Test 200 OK with body content - SHOULD have Content-Encoding
foreach my $encoding (@encodings) {
    my $request = HTTP::Request->new("GET", "http://localhost/api/sessions");
    $request->header('Accept-Encoding' => $encoding);
    my $response = $ua->request($request);

    ok($response->code == 200, "Sessions endpoint returns 200 OK");
    ok($response->content, "Response has body content");

    # Should have Content-Encoding header when we have actual body content
    ok(defined($response->header('content-encoding')),
       "200 response with body DOES have Content-Encoding header (requested $encoding)");
    ok($response->header('content-encoding') eq $encoding,
       "Content-Encoding header matches requested encoding: $encoding");
}

# Test without Accept-Encoding header - should work without compression
my $request = HTTP::Request->new("GET", "http://localhost/api/sessions");
my $response = $ua->request($request);

ok($response->code == 200, "Sessions endpoint returns 200 OK without Accept-Encoding");
ok(!defined($response->header('content-encoding')),
   "Response without Accept-Encoding has NO Content-Encoding header");

done_testing();

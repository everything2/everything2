#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);

use LWP::UserAgent;
use HTTP::Request;
use Test::More;
use Everything;
use JSON;

use HTTP::Cookies;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
        plan skip_all => "Not in the development environment";
        exit;
}

my $endpoint = "http://localhost/api/sessions";
my $json = JSON->new;

ok(my $ua = LWP::UserAgent->new, "Make a new LWP::UserAgent object");
ok(my $response = $ua->get($endpoint), "Get the default sessions endpoint");
ok($response->code == 200, "Default sessions endpoint always returns 200");
ok(my $session = $json->decode($response->content), "Content accurately decodes");
ok($session->{username} eq "Guest User", "Username says 'Guest User'");
ok($session->{user_id} eq $Everything::CONF->guest_user, "User id is present and is that of Guest User");
ok($session->{is_guest} == 1, "is_guest should be on");
ok($response->header('content-type') =~ /^application\/json/i, "Returns JSON");

# Development credentials
ok(my $request = HTTP::Request->new("POST","$endpoint/create"), "Construct HTTP::Request object");
$request->header('Content-Type' => 'application/json');
$request->content($json->encode({"username" => "root","passwd" => "blah"}));
ok($response = $ua->request($request), "Good root credential POST to /create");
ok($response->code == 200, "Response code is 200");
ok($response->header('content-type') =~ /^application\/json/i, "Returns JSON");
ok(defined($response->header('set-cookie')), "Properly sets cookie header");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{is_guest} == 0, "Accurately is not guest");
ok($session->{username} eq "root", "Logged in as root");
ok(exists $session->{powers}, "Root has special powers");
ok(grep("ed", @{$session->{powers}}), "Root is an editor");

# Bad post without password gives 400 Bad Request
$request->content($json->encode({"username" => "root"}));
ok($response = $ua->request($request), "Bad Request credential POST returns");
ok($response->code == 400, "Bad request is bad");

# Bad post without username gives 400 Bad Request 
$request->content($json->encode({"passwd" => "baaad"}));
ok($response = $ua->request($request), "Bad Request credential POST returns");
ok($response->code == 400, "Bad request still is bad");

# Bad post with incorrect password gives 403
$request->content($json->encode({"username" => "root", "passwd" => "notmypasswd"}));
ok($response = $ua->request($request), "Invalid password comes back just fine");
ok($response->code == 403, "Return code is 403");

# Normal user credentials
my $cookie_jar = HTTP::Cookies->new();
ok($ua = LWP::UserAgent->new());
$ua->cookie_jar($cookie_jar);

$request->content($json->encode({"username" => "normaluser1", "passwd" => "blah"}));
ok($response = $ua->request($request), "Good normaluser1 credential POST to /create");
ok($response->code == 200, "Response code is 200");
ok($response->header('content-type') =~ /^application\/json/i, "Returns JSON");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{is_guest} == 0, "Accurately is not guest");
ok($session->{username} eq "normaluser1", "Logged in as normaluser1");
ok(!exists($session->{powers}), "Normal user doesn't have any special powers");
ok(defined($response->header('set-cookie')), "Properly sets cookie header");

# With cookies
ok($response = $ua->get($endpoint), "Get repeat connection with cookie_jar");
ok($response->code == 200, "Return code is 200");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{is_guest} == 0, "Non-guest due to cookies being saved");

# Session destruction
ok($response = $ua->get("$endpoint/destroy"));
ok($response->code == 200, "Session destroys ok");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{is_guest} == 1, "Guest due to destroyed session");
my $cookiestring = $ua->cookie_jar->as_string;
my $cookiename = $Everything::CONF->cookiepass;
ok($cookiestring =~ /$cookiename=""/, "Cookie destroyed");

# Destroying session again
ok($response = $ua->get("$endpoint/destroy"));
ok($response->code == 200, "Session destroys ok");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{is_guest} == 1, "Still guest due to destroyed session");

# Alternate form post method
ok($response = $ua->post("$endpoint/create", {data => $json->encode({"username" => "root","passwd" => "blah"})}));
ok($response->code == 200, "Session is ok");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{is_guest} == 0, "Not guest anymore due to successful login");

done_testing();

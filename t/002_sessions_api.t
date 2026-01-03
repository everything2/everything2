#!/usr/bin/perl -w

use strict;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use LWP::UserAgent;
use HTTP::Request;
use Test::More;
use JSON;
use HTTP::Cookies;
use Everything;

# Initialize database to reset test user password
initEverything('development-docker');

# Reset normaluser1 password to 'blah' before running tests
# This ensures test idempotency even if password was changed by other tests
my $test_user = $DB->getNode("normaluser1", "user");
if ($test_user) {
    my ($pwhash, $salt) = $APP->saltNewPassword("blah");
    $test_user->{passwd} = $pwhash;
    $test_user->{salt} = $salt;
    $DB->updateNode($test_user, -1);
}

my $endpoint = "http://localhost/api/sessions";
my $json = JSON->new;

ok(my $ua = LWP::UserAgent->new, "Make a new LWP::UserAgent object");
ok(my $response = $ua->get($endpoint), "Get the default sessions endpoint");
ok($response->code == 200, "Default sessions endpoint always returns 200");
ok(my $session = $json->decode($response->content), "Content accurately decodes");
ok($session->{display}->{is_guest} == 1, "is_guest should be on");
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
ok($session->{display}->{is_guest} == 0, "Accurately is not guest");
ok($session->{user}->{title} eq "root", "Logged in as root");
ok(exists $session->{display}->{powers}, "Root has special powers");
ok(grep("ed", @{$session->{display}->{powers}}), "Root is an editor");

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
ok($session->{display}->{is_guest} == 0, "Accurately is not guest");
ok($session->{user}->{title} eq "normaluser1", "Logged in as normaluser1");
ok(!exists($session->{display}->{powers}), "Normal user doesn't have any special powers");
ok(defined($response->header('set-cookie')), "Properly sets cookie header");

# With cookies
ok($response = $ua->get($endpoint), "Get repeat connection with cookie_jar");
ok($response->code == 200, "Return code is 200");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{display}->{is_guest} == 0, "Non-guest due to cookies being saved");

# Session delete
ok($response = $ua->get("$endpoint/delete"));
ok($response->code == 200, "Session deletes ok");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{display}->{is_guest} == 1, "Guest due to deleted session");
my $cookiestring = $ua->cookie_jar->as_string;
my $cookiename = "userpass"; #Taken from Everything::Configuration;
ok($cookiestring =~ /$cookiename=""/, "Cookie deleted");

# Deleting session again
ok($response = $ua->get("$endpoint/delete"));
ok($response->code == 200, "Session deletes ok");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{display}->{is_guest} == 1, "Still guest due to deleted session");

# Alternate form post method
ok($response = $ua->post("$endpoint/create", {data => $json->encode({"username" => "root","passwd" => "blah"})}));
ok($response->code == 200, "Session is ok");
ok($session = $json->decode($response->content), "Content accurately decodes");
ok($session->{display}->{is_guest} == 0, "Not guest anymore due to successful login");

done_testing();

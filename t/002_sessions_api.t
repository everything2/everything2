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

# =============================================================================
# "Remember me" cookie expiration tests
# =============================================================================

subtest "Remember me (expires parameter) functionality" => sub {
    # Test 1: Login WITHOUT expires - should get session cookie (no expires attribute)
    my $ua_session = LWP::UserAgent->new();
    my $jar_session = HTTP::Cookies->new();
    $ua_session->cookie_jar($jar_session);

    my $req = HTTP::Request->new("POST", "$endpoint/create");
    $req->header('Content-Type' => 'application/json');
    $req->content($json->encode({
        "username" => "normaluser1",
        "passwd" => "blah"
    }));

    my $resp = $ua_session->request($req);
    is($resp->code, 200, "Login without expires succeeds");

    my $set_cookie_header = $resp->header('set-cookie') || '';
    ok($set_cookie_header =~ /userpass=/, "Cookie is set");
    ok($set_cookie_header !~ /expires=/i, "Session cookie has no expires attribute (session-only)");

    # Test 2: Login WITH expires=+1y - should get persistent cookie with future expiration
    my $ua_remember = LWP::UserAgent->new();
    my $jar_remember = HTTP::Cookies->new();
    $ua_remember->cookie_jar($jar_remember);

    $req = HTTP::Request->new("POST", "$endpoint/create");
    $req->header('Content-Type' => 'application/json');
    $req->content($json->encode({
        "username" => "normaluser1",
        "passwd" => "blah",
        "expires" => "+1y"
    }));

    $resp = $ua_remember->request($req);
    is($resp->code, 200, "Login with expires=+1y succeeds");

    $set_cookie_header = $resp->header('set-cookie') || '';
    ok($set_cookie_header =~ /userpass=/, "Cookie is set with remember me");
    ok($set_cookie_header =~ /expires=/i, "Persistent cookie has expires attribute");

    # Verify the expiration is roughly 1 year in the future
    if ($set_cookie_header =~ /expires=([^;]+)/i) {
        my $expires_str = $1;
        # Parse the date - should be approximately 1 year from now
        # Format: "Thu, 14 Jan 2027 00:14:18 GMT"
        ok($expires_str =~ /\d{4}/, "Expires contains a year");

        # Extract year from expires string
        my ($exp_year) = $expires_str =~ /(\d{4})/;
        my @now = localtime();
        my $current_year = $now[5] + 1900;

        # The expires year should be current year or current year + 1
        ok($exp_year >= $current_year && $exp_year <= $current_year + 1,
           "Expires year ($exp_year) is approximately 1 year from now ($current_year)");
    }

    # Test 3: Login with expires=+30d - should get 30-day cookie
    $req = HTTP::Request->new("POST", "$endpoint/create");
    $req->header('Content-Type' => 'application/json');
    $req->content($json->encode({
        "username" => "normaluser1",
        "passwd" => "blah",
        "expires" => "+30d"
    }));

    $resp = $ua_remember->request($req);
    is($resp->code, 200, "Login with expires=+30d succeeds");

    $set_cookie_header = $resp->header('set-cookie') || '';
    ok($set_cookie_header =~ /expires=/i, "30-day cookie has expires attribute");

    # Test 4: Login with empty expires string - should be session cookie
    $req = HTTP::Request->new("POST", "$endpoint/create");
    $req->header('Content-Type' => 'application/json');
    $req->content($json->encode({
        "username" => "normaluser1",
        "passwd" => "blah",
        "expires" => ""
    }));

    $resp = $ua_remember->request($req);
    is($resp->code, 200, "Login with empty expires succeeds");

    $set_cookie_header = $resp->header('set-cookie') || '';
    ok($set_cookie_header !~ /expires=/i, "Empty expires string results in session cookie");

    # Test 5: Invalid credentials with expires should still fail
    $req = HTTP::Request->new("POST", "$endpoint/create");
    $req->header('Content-Type' => 'application/json');
    $req->content($json->encode({
        "username" => "normaluser1",
        "passwd" => "wrongpassword",
        "expires" => "+1y"
    }));

    $resp = $ua_remember->request($req);
    is($resp->code, 403, "Invalid password with expires still returns 403");

    # Test 6: Verify cookie with expires works for subsequent requests
    my $ua_persistent = LWP::UserAgent->new();
    my $jar_persistent = HTTP::Cookies->new();
    $ua_persistent->cookie_jar($jar_persistent);

    $req = HTTP::Request->new("POST", "$endpoint/create");
    $req->header('Content-Type' => 'application/json');
    $req->content($json->encode({
        "username" => "normaluser1",
        "passwd" => "blah",
        "expires" => "+1y"
    }));

    $resp = $ua_persistent->request($req);
    is($resp->code, 200, "Login with remember me succeeds");

    # Make a subsequent request - should still be logged in
    $resp = $ua_persistent->get($endpoint);
    is($resp->code, 200, "Subsequent request succeeds");
    my $sess = $json->decode($resp->content);
    is($sess->{display}->{is_guest}, 0, "Still logged in with persistent cookie");
    is($sess->{user}->{title}, "normaluser1", "Correct user with persistent cookie");

    # Test 7: Logout should clear the persistent cookie
    $resp = $ua_persistent->get("$endpoint/delete");
    is($resp->code, 200, "Logout succeeds");

    $resp = $ua_persistent->get($endpoint);
    $sess = $json->decode($resp->content);
    is($sess->{display}->{is_guest}, 1, "Logged out after session delete");
};

subtest "Cookie expiration edge cases" => sub {
    # Test with various CGI-style expiration formats
    my @expiry_formats = (
        { expires => "+1h", desc => "1 hour" },
        { expires => "+7d", desc => "7 days" },
        { expires => "+1M", desc => "1 month" },
        { expires => "+1y", desc => "1 year" },
    );

    for my $test (@expiry_formats) {
        my $ua_test = LWP::UserAgent->new();
        my $req = HTTP::Request->new("POST", "$endpoint/create");
        $req->header('Content-Type' => 'application/json');
        $req->content($json->encode({
            "username" => "normaluser1",
            "passwd" => "blah",
            "expires" => $test->{expires}
        }));

        my $resp = $ua_test->request($req);
        is($resp->code, 200, "Login with expires=$test->{expires} ($test->{desc}) succeeds");

        my $cookie_header = $resp->header('set-cookie') || '';
        ok($cookie_header =~ /expires=/i, "Cookie with $test->{desc} expiration has expires attribute");
    }
};

done_testing();

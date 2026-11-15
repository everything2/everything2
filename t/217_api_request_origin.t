#!/usr/bin/perl -w
#
# The API only answers requests the site itself makes.
#
# Browsers send Fetch Metadata (Sec-Fetch-Site/-Mode/-Dest) with every request. The site's
# pages call the API with fetch()/XHR or sendBeacon from the same origin; following a link,
# submitting a form, loading an image, or calling from another origin is refused. Requests
# with no Fetch Metadata (scripts, API clients, older browsers) are unaffected. Also pins the
# HTTP method allowlist.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use JSON;
use URI::Escape qw(uri_escape_utf8);
use Everything;

initEverything 'everything';

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request;
my $test = Plack::Test->create($app);

my $root   = $DB->getNode( 'root', 'user' );
my $cookie = $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$root->{title}|$root->{passwd}");

sub api {
    my ( $method, $path, %fetch ) = @_;
    my $req = HTTP::Request->new( $method => $path );
    $req->header( Cookie => $cookie );
    $req->header( "Sec-Fetch-\u$_" => $fetch{$_} ) for keys %fetch;
    my $res  = $test->request($req);
    my $json = eval { JSON->new->decode( $res->content ) };
    return ( $res, $json );
}

my $refused = qr/must be made by the site itself/;

# --- what the site's own pages send: allowed -------------------------------------
for my $case (
    [ 'no Fetch Metadata (script / API client)', {} ],
    [ 'fetch() from the site',                   { site => 'same-origin', mode => 'cors',        dest => 'empty' } ],
    [ 'same-origin-mode fetch',                  { site => 'same-origin', mode => 'same-origin', dest => 'empty' } ],
    [ 'sendBeacon from the site',                { site => 'same-origin', mode => 'no-cors',     dest => 'empty' } ],
    )
{
    my ( $desc, $fetch ) = @$case;
    my ( $res, $json ) = api( 'GET', '/api/sessions', %$fetch );
    is( $res->code, 200, "$desc: 200" );
    is( $json && $json->{user} && $json->{user}{title}, 'root', "$desc: answered" );
}

# --- anything else a browser sends: refused --------------------------------------
for my $case (
    [ 'link followed on the site',       { site => 'same-origin', mode => 'navigate', dest => 'document' } ],
    [ 'URL typed into the address bar',  { site => 'none',        mode => 'navigate', dest => 'document' } ],
    [ 'page in an iframe',               { site => 'same-origin', mode => 'navigate', dest => 'iframe' } ],
    [ 'image tag on the site',           { site => 'same-origin', mode => 'no-cors',  dest => 'image' } ],
    [ 'script tag on the site',          { site => 'same-origin', mode => 'no-cors',  dest => 'script' } ],
    [ 'fetch() from another site',       { site => 'cross-site',  mode => 'cors',     dest => 'empty' } ],
    [ 'fetch() from another e2 host',    { site => 'same-site',   mode => 'cors',     dest => 'empty' } ],
    [ 'form posted from another site',   { site => 'cross-site',  mode => 'navigate', dest => 'document' } ],
    )
{
    my ( $desc, $fetch ) = @$case;
    my ( $res, $json ) = api( 'GET', '/api/sessions', %$fetch );
    is( $res->code, 200, "$desc: 200 (API errors are always 200)" );
    is( $json && $json->{success}, 0, "$desc: refused" );
    like( $json && $json->{error} // '', $refused, "$desc: says why" );
    ok( !( $json && $json->{user} ), "$desc: no user data" );
}

# --- a refused request has no effect -------------------------------------------
{
    my ( $res, $json ) = api( 'GET', '/api/sessions/delete', site => 'same-origin', mode => 'navigate', dest => 'document' );
    is( $json && $json->{success}, 0, 'logout via a followed link is refused' );
    my $name = $Everything::CONF->cookiepass;
    ok( !grep( { /\Q$name\E=;|expires=.*1970|Max-Age=0/i } $res->header('Set-Cookie') ),
        'and the login cookie is not cleared' );
}

# --- HTTP method allowlist ---------------------------------------------------------
for my $method (qw(DUMP OPTIONS TRACE EDIT_PROFILE)) {
    my ( $res, $json ) = api( $method, '/api/user/edit' );
    is( $res->code, 405, "$method is not allowed" );
    unlike( $res->content, qr{/var/everything|line \d+}, "$method: no internals in the response" );
}

done_testing();

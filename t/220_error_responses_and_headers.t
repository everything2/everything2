#!/usr/bin/perl -w
#
# 1. A request that dies gets a generic 500 outside development (no error text, file paths
#    or line numbers); development keeps the details.
# 2. Apache adds the framing and HSTS headers to everything it serves.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use JSON;
use Everything;

initEverything 'everything';

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);

# A request that reliably dies: malformed JSON to the login endpoint.
sub failing_request {
    return $test->request( HTTP::Request::Common::POST(
        '/api/sessions/create', 'Content-Type' => 'application/json', Content => '{"username": "x", ' ) );
}

subtest 'outside development: generic body, nothing about the code' => sub {
    local $Everything::CONF->{environment} = 'production';
    my $res = failing_request();
    is( $res->code, 500, 'still a 500' );
    my $json = eval { decode_json( $res->content ) };
    is( $json && $json->{error}, 'Internal server error', 'API body is generic JSON' );
    ok( $json && !exists $json->{detail}, 'no detail field' );
    unlike( $res->content, qr{/var/everything|\.pm line \d+|caught a die}, 'no paths, line numbers or internals' );

    my ( $code, $headers, $body ) = @{ main::error_response( 0, "boom at /var/everything/ecore/X.pm line 9.\n" ) };
    is( $code, 500, 'page error is a 500' );
    unlike( join( '', @$body ), qr{/var/everything|line 9}, 'page body is generic too' );
};

subtest 'development keeps the details' => sub {
    local $Everything::CONF->{environment} = 'development';
    my $json = eval { decode_json( failing_request()->content ) } || {};
    is( $json->{error}, 'Internal server error', 'same error field' );
    ok( length( $json->{detail} // '' ), 'plus the underlying error as detail' );
};

# --- Apache response headers (live, through the dev container's Apache) ---------------
SKIP: {
    eval { require LWP::UserAgent; 1 } or skip 'LWP::UserAgent unavailable', 1;
    my $ua = LWP::UserAgent->new( timeout => 20, max_redirect => 0 );
    my $probe = $ua->get('http://localhost/');
    skip 'Apache not reachable on localhost', 1 unless $probe && $probe->code;

    for my $path ( '/', '/api/sessions', '/react/main.bundle.js', '/no/such/path/at/all' ) {
        my $res = $ua->get("http://localhost$path");
        is( $res->header('X-Frame-Options'), 'DENY', "$path: X-Frame-Options DENY" );
        is( $res->header('Content-Security-Policy'), "frame-ancestors 'none'", "$path: frame-ancestors 'none'" );
        like( $res->header('Strict-Transport-Security') // '', qr/^max-age=\d+$/, "$path: HSTS without includeSubDomains" );
    }
}

done_testing();

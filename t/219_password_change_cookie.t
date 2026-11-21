#!/usr/bin/perl -w
#
# Changing your own password reissues the login cookie. It must be the same cookie login
# issues (Request::make_login_cookie): path=/, SameSite=Lax, HttpOnly, and Secure outside
# development. And it must keep the user logged in.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use JSON;
use URI::Escape qw(uri_escape_utf8);
use Everything;
use TestSeed;

initEverything 'everything';

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);

# Never signed in before: this request is their first (the case #4709 broke).
my $user = TestSeed::make_user( $DB, $APP, label => 'pwchange', password => 'blah' );
END { TestSeed::cleanup($DB) }
my $name = $user->{title};
my $cookie_name = $Everything::CONF->cookiepass;

my $old_cookie = "$cookie_name=" . uri_escape_utf8("$user->{title}|$user->{passwd}");

my $res = $test->request( HTTP::Request::Common::POST(
    '/api/user/edit',
    Cookie         => $old_cookie,
    'Content-Type' => 'application/json',
    Content        => encode_json( { node_id => $user->{node_id}, passwd => 'changed-pass-219', current_password => 'blah' } ),
) );
my $json = eval { decode_json( $res->content ) } || {};
is( $json->{success}, 1, 'password change accepted' ) or diag explain $json;

my ($set) = grep { /^\Q$cookie_name\E=/ } $res->header('Set-Cookie');
ok( $set, 'a new login cookie is issued' );

SKIP: {
    skip 'no cookie to inspect', 6 unless $set;
    like( $set, qr/;\s*path=\//i,         'path=/' );
    like( $set, qr/;\s*SameSite=Lax/i,    'SameSite=Lax' );
    like( $set, qr/;\s*HttpOnly/i,        'HttpOnly' );
    if ( $Everything::CONF->environment eq 'development' ) {
        unlike( $set, qr/;\s*Secure/i, 'not Secure in development (plain HTTP)' );
    }
    else {
        like( $set, qr/;\s*Secure/i, 'Secure' );
    }

    # The new cookie keeps the user logged in.
    my ($pair) = $set =~ /^([^;]+)/;
    my $who = $test->request( HTTP::Request::Common::GET( '/api/sessions', Cookie => $pair ) );
    my $session = eval { decode_json( $who->content ) } || {};
    is( $session->{user} && $session->{user}{title}, $name, 'the new cookie is still logged in' );

    # And the old one no longer is.
    my $stale = $test->request( HTTP::Request::Common::GET( '/api/sessions', Cookie => $old_cookie ) );
    my $stale_session = eval { decode_json( $stale->content ) } || {};
    ok( !$stale_session->{user}, 'the old cookie no longer logs in' );
}

done_testing();

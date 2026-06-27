#!/usr/bin/perl -w
# memoized_build + stash_last_update (#4391 guest-front-page blob cache engine).
#
# memoized_build is a per-worker cache of a derived, non-personalized value keyed by a
# version string; it rebuilds on COLD START or when the version CHANGES (a source feed's
# last_update advances). The guest front page keys it on its two feeds' last_update.
# This pins the cold-start + invalidation mechanics the user asked for, then smoke-tests
# the guest-front-page wiring end-to-end.
#
# Boots app.psgi for a live $Everything::DB; SKIPs if unavailable.
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use Test::More;

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';

require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);
$test->request( HTTP::Request::Common::GET('/') ) for 1 .. 2;    # warm

no warnings 'once';
my $DB = $Everything::DB;
plan skip_all => "no live \$Everything::DB with memoized_build"
    unless $DB && $DB->can('memoized_build');

my $KEY = "t169_memo_$$";    # process-unique so we never collide with real keys
my $builds = 0;
my $build  = sub { $builds++; return { n => $builds } };

# --- COLD START: first call with a version builds ---
my $r1 = $DB->memoized_build( $KEY, "v1", $build );
is( $builds,  1, 'cold start: build runs exactly once' );
is( $r1->{n}, 1, 'cold start: returns the freshly built value' );

# --- CACHE HIT: same version does NOT rebuild ---
my $r2 = $DB->memoized_build( $KEY, "v1", $build );
is( $builds, 1, 'same version: no rebuild (cache hit)' );
is( $r1, $r2, 'same version: same ref returned (memoized)' );

# --- INVALIDATION: a changed version rebuilds ---
my $r3 = $DB->memoized_build( $KEY, "v2", $build );
is( $builds,  2, 'changed version: rebuilds' );
is( $r3->{n}, 2, 'changed version: returns the fresh value' );

# only the latest version is cached, so churning back rebuilds again
$DB->memoized_build( $KEY, "v1", $build );
is( $builds, 3, 'version churn rebuilds (single-slot cache, latest only)' );

# --- undef version disables caching: always rebuilds ---
$DB->memoized_build( $KEY, undef, $build );
$DB->memoized_build( $KEY, undef, $build );
is( $builds, 5, 'undef version: never cached, always rebuilds' );

# --- stats reflect it: 1 hit, 5 builds for our key ---
my ($row) = grep { $_->{name} eq $KEY } @{ $DB->memoized_build_stats() };
ok( $row, 'memoized_build_stats has a row for our key' );
is( $row->{hits},   1, 'stats: exactly one hit (the same-version call)' );
is( $row->{builds}, 5, 'stats: five builds (cold + churn + undef x2)' );

# --- the version source: a feed's last_update is a numeric epoch stamp ---
my $lu = $DB->stash_last_update("frontpagenews");
ok( defined $lu && $lu =~ /^\d+$/, 'stash_last_update returns a numeric last_update stamp' );

# --- guest-front-page wiring end-to-end: a repeat render is a memoize HIT ---
SKIP: {
    $test->request( HTTP::Request::Common::GET('/node/2030780') );   # ensure built
    my ($g1) = grep { $_->{name} eq 'guest_front_page' } @{ $DB->memoized_build_stats() };
    skip 'guest front page (2030780) not the guest_front_page page in this env', 1 unless $g1;

    my $hits_before = $g1->{hits};
    $test->request( HTTP::Request::Common::GET('/node/2030780') );   # should hit the cache
    my ($g2) = grep { $_->{name} eq 'guest_front_page' } @{ $DB->memoized_build_stats() };
    cmp_ok( $g2->{hits}, '>', $hits_before,
        'second guest-front-page render is a memoize HIT (assembly skipped)' );
}

done_testing;

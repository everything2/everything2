#!/usr/bin/perl -w
# cached_stash (#3981 / #4385): a per-worker TTL cache over stashData's JSON decode.
# stashData() re-decodes the datastash blob on every call (the standing "permanent cache"
# TODO); cached_stash() decodes at most once per refresh window and returns the memoized
# structure on a hit. This pins correctness + memoization. The TTL/delta/grace timing is
# covered by code review (it needs time + last_update control to exercise directly).
#
# Boots app.psgi to get a live $Everything::DB (same pattern as the dev probes); SKIPs if
# the app/DB or the sample stash isn't available in this environment.
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use Test::More;
use Scalar::Util qw(refaddr);

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';

require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);
$test->request( HTTP::Request::Common::GET('/') ) for 1 .. 2;    # warm the caches

no warnings 'once';    # $Everything::DB is a package global referenced once here
my $DB = $Everything::DB;
plan skip_all => "no live \$Everything::DB" unless $DB && $DB->can('cached_stash');

# Missing stash -> undef, matching stashData's "return unless $stashnode".
is( $DB->cached_stash("definitely_not_a_real_stash_xyz"), undef,
    'missing stash returns undef' );

my $raw = $DB->stashData("coolnodes");    # a fresh decode for comparison
SKIP: {
    skip "coolnodes stash not present in this env", 3 unless defined $raw;

    my $c1 = $DB->cached_stash("coolnodes");    # populate
    my $c2 = $DB->cached_stash("coolnodes");    # hit

    ok( defined $c1, 'cached_stash returns data' );
    is( ref $c1, ref $raw,
        'cached_stash returns the same structure type as stashData' );
    is( refaddr($c1), refaddr($c2),
        'second read is a cache hit -- same ref, no re-decode (memoized)' );
}

done_testing;

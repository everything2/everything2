#!/usr/bin/perl -w
# Cache tuning (#4392):
#  1. cached_stash SELF-TUNES its window to the observed refresh cadence (the gap between
#     consecutive last_updates) rather than the declared interval -- so a 60s-interval stash
#     on the 120s cron stops expiring a cron-cycle early and burning grace.
#  2. stash_content_version keys a derived memoize on the CONTENT (canonical JSON), so the
#     cron's no-op last_update re-stamps don't churn the guest-front-page rebuild.
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
plan skip_all => "no live \$Everything::DB" unless $DB && $DB->can('stash_content_version');

#############################################################################
# 1. SELF-TUNE: window tracks the observed cadence, not the declared interval
#############################################################################
SKIP: {
    my $name = "coolnodes";    # declared interval 60s
    my $node = $DB->getNode( $name, 'datastash' );
    skip "coolnodes datastash not present", 3 unless $node;
    my $iv = $DB->_stash_interval($name);    # 60

    # Seed a prior cache entry (last_update L1) that's already expired, then advance the
    # source last_update by a gap LARGER than the declared interval, and force a re-check.
    # Prior refresh 90s ago; "current" refresh = now, so the self-tuned window lands in the
    # FUTURE and isn't clamped by the past-guard. observed gap = 90 (> interval 60, < 2x = 120).
    my $now = time();
    my $L1  = $now - 90;
    $DB->{_stash_cache}{$name} = { data => [], last_update => $L1, next_check => 0 };
    my $L2 = $now;
    $DB->setNodeParam( $node, 'last_update', $L2 );

    $DB->cached_stash($name);    # expired + delta>0 -> re-decode + self-tune
    my $e = $DB->{_stash_cache}{$name};

    is( $e->{last_update}, $L2, 'self-tune: re-decoded to the advanced last_update' );
    is( $e->{next_check}, $L2 + 90,
        'self-tune: window = observed gap (90s), not the declared 60s interval' );
    cmp_ok( $e->{next_check} - $L2, '>', $iv,
        'self-tune: window is longer than the declared interval' );
}

#############################################################################
# 2. CONTENT-VERSION: stable across a re-decode of UNCHANGED content
#############################################################################
SKIP: {
    my $cv0 = $DB->stash_content_version("frontpagenews");
    skip "frontpagenews datastash not present", 1 unless length $cv0;

    # Force a fresh re-decode (drop the per-worker entry) -- the stash content is unchanged,
    # so the canonical content fingerprint must come back identical.
    delete $DB->{_stash_cache}{frontpagenews};
    my $cv1 = $DB->stash_content_version("frontpagenews");
    is( $cv1, $cv0,
        'content_version is stable across a re-decode of unchanged content (canonical, no churn)' );
}

#############################################################################
# 3. guest_front_page: a re-decode of unchanged feeds does NOT rebuild the memoize
#    (this is the prod symptom #4392 fixes -- last_update churn was rebuilding it)
#############################################################################
SKIP: {
    $test->request( HTTP::Request::Common::GET('/node/2030780') );    # populate the memoize
    my ($g0) = grep { $_->{name} eq 'guest_front_page' } @{ $DB->memoized_build_stats() };
    skip "guest_front_page (2030780) not built in this env", 1 unless $g0;
    my $builds0 = $g0->{builds};

    # Drop the feed cache entries so the next render re-decodes them (simulating the cron's
    # re-stamp), but the CONTENT is unchanged -> content_version unchanged -> memoize HIT.
    delete $DB->{_stash_cache}{altfrontpagecontent};
    delete $DB->{_stash_cache}{frontpagenews};

    $test->request( HTTP::Request::Common::GET('/node/2030780') );
    my ($g1) = grep { $_->{name} eq 'guest_front_page' } @{ $DB->memoized_build_stats() };
    is( $g1->{builds}, $builds0,
        'a re-decode of unchanged feeds does NOT rebuild the guest-fp (content-version, not last_update)' );
}

done_testing;

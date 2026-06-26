#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::DataStash::guestchrome;

# Build-keyed guest-chrome cache (#4369): the stash is { $buildid => $chrome }, used only
# when the cached build == the running build, with inline build-on-miss to avoid a cold
# window after a deploy.

initEverything("development-docker");
ok( $APP, 'APP object' );
ok( $DB,  'DB connection' );

my $gc = Everything::DataStash::guestchrome->new(
    APP => $APP, CONF => $APP->{conf}, DB => $DB );

my $buildid = $APP->{conf}->last_commit;
ok( $buildid, "have a build id (last_commit = $buildid)" );

# The guestchrome datastash node is seeded from nodepack (node 2213887); stashData requires
# it to pre-exist. A stale dev DB predating the node needs a devclean + reseed.
ok( $DB->getNode( 'guestchrome', 'datastash' ), 'guestchrome datastash node is seeded' );

# No longer lengthy -> rides the regular ~2-min datastash tick.
is( $gc->lengthy, 0, 'guestchrome is not lengthy (fast tick)' );

#############################################################################
# generate() stashes { $buildid => $chrome }
#############################################################################
$gc->generate;
my $raw = $DB->stashData('guestchrome');
is( ref($raw), 'HASH', 'stash is a hash' );
is_deeply( [ keys %$raw ], [$buildid], 'stash keyed by exactly the current build id' );

my $chrome = $raw->{$buildid};
ok( $chrome->{guest},            'cached value is the chrome (guest key present)' );
ok( !exists $chrome->{contentData}, 'cached chrome carries no content-partition keys' );

#############################################################################
# current_chrome: hit when the build matches
#############################################################################
my $cur = $gc->current_chrome;
ok( $cur && $cur->{guest}, 'current_chrome returns the chrome when the build id matches' );

#############################################################################
# Stale build (post-deploy): current_chrome misses -> never serve stale-asset chrome
#############################################################################
$DB->stashData( 'guestchrome', { 'stale-build-deadbeef' => { guest => 1, lastCommit => 'old' } } );
is( $gc->current_chrome, undef,
    'current_chrome returns undef when the cached build id is stale (post-deploy safety)' );

#############################################################################
# current_or_build: inline build+stash on a miss, then warm
#############################################################################
my $warm = $gc->current_or_build;
ok( $warm && $warm->{guest}, 'current_or_build builds + returns chrome on a cache miss (inline warm)' );

my $raw2 = $DB->stashData('guestchrome');
ok( exists $raw2->{$buildid}, 'current_or_build re-stashed under the current build id' );
ok( $gc->current_chrome,      'subsequent current_chrome is now a warm hit' );

done_testing();

=head1 NAME

t/165_guestchrome_cache.t - build-keyed guest-chrome cache + inline warm (#4369)

=cut

#!/usr/bin/perl -w
#
# gotoNode force-removal coherence (#4436, closes #4434).
#
# Everything::HTML::gotoNode used to fetch the *displayed* node with
# getNodeById($id, 'force'), which bypasses the cache and unconditionally re-reads
# from the DB on every render. That force is gone; the displayed node now rides the
# version-checked cache like every other read. Coherence therefore rests on
# getCachedNodeById -> isSameVersion returning stale (undef) when the global version
# was bumped, so getNodeById re-fetches fresh instead of serving the cached copy.
#
# This guards that property by brute force: poison the cached copy, confirm a
# version-matched read still serves it (the cache path the force used to bypass),
# then bump the global version as another worker's write would and confirm the next
# read comes back fresh -- i.e. dropping the force does NOT serve stale content.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;

initEverything 'everything';
my $cache = $DB->{cache};

# A content node that goes through the real version check: not a static_cache type and
# not a hydration resident. Use the lowest-id writeup in the seed set.
my $wt = $DB->getNode('writeup', 'nodetype');
plan skip_all => 'no writeup nodetype' unless $wt;
my ($wid) = $DB->{dbh}->selectrow_array(
    "SELECT node_id FROM node WHERE type_nodetype=? ORDER BY node_id LIMIT 1",
    undef, $wt->{node_id} );
plan skip_all => 'no writeup node in this DB' unless $wid;

ok( !exists $cache->{hydrationExempt}{$wid}, 'test node is not hydration-exempt' );
ok( !exists $Everything::CONF->static_cache->{'writeup'},
    'writeup is not a static_cache type (so it is version-checked)' );

my $node = getNodeById($wid);
ok( $node, "fetched content node $wid" );
my $real = $node->{title};

# getCachedNodeById returns the cached ref itself -- poison it in place.
$node->{title} = 'POISONED-STALE-COPY';

# Version still matches: the cache legitimately serves its (now poisoned) copy. This is
# exactly the cache read the old 'force' skipped on every single render.
$cache->clearSessionCache;
my $hit = getNodeById($wid);
is( $hit->{title}, 'POISONED-STALE-COPY',
    'version match: plain getNodeById serves the cached copy (what force used to bypass)' );

# Bump the global version, as another worker's updateNode would. The cached copy is now
# stale -> getCachedNodeById returns undef -> getNodeById re-fetches from the DB.
$cache->incrementGlobalVersion($node);
$cache->clearSessionCache;
my $fresh = getNodeById($wid);
is( $fresh->{title}, $real,
    'version bump: getNodeById re-fetches fresh -- coherence holds without the force' );
isnt( $fresh->{title}, 'POISONED-STALE-COPY',
    'stale cached copy is NOT served after a version bump' );

done_testing();

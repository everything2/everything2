#!/usr/bin/perl -w
#
# Everything::NodeCache hydration loader (#4423). Loads the committed core-node bundle
# and verifies the residents are cached, version-exempt, and served with ZERO DB
# queries -- plus that the flattened {type} is reconstructed and secrets stay blanked.
# Uses Com_select (a SHOW, which is NOT itself a SELECT) to count real SELECTs.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;

initEverything 'everything';

my $cache = $DB->{cache};
my $dbh   = $DB->{dbh};
sub selects { my @r = $dbh->selectrow_array("SHOW SESSION STATUS LIKE 'Com_select'"); return $r[1]; }

my $bundle = '/var/everything/hydration/hydration_cache.json';
plan skip_all => "no hydration bundle at $bundle" unless -r $bundle;

my $loaded = $cache->loadHydrationCache($bundle);
cmp_ok( $loaded, '>', 400, "loaded $loaded core nodes from the committed bundle" );

# --- Guest User: the one non-static-type member -> must be explicitly exempt ----
my $gu = $Everything::CONF->guest_user;
ok( exists $cache->{hydrationExempt}{$gu}, 'Guest User is marked hydration-exempt' );

$cache->clearSessionCache;    # fresh page-load: drop the per-request "verified" memo
my $b    = selects();
my $node = getNodeById($gu);
is( selects() - $b, 0, 'fetching Guest User does 0 DB queries (resident)' );
is( $node->{title}, 'Guest User', 'Guest User served from the hydration cache' );

$cache->clearSessionCache;
$b = selects();
ok( $cache->isSameVersion($node), 'hydration node passes isSameVersion (version-exempt)' );
is( selects() - $b, 0, 'isSameVersion does 0 queries for a hydration node' );

# --- a static_cache-type node + its reconstructed {type} -----------------------
$cache->clearSessionCache;
$b = selects();
my $nt = getNodeById(1);
is( selects() - $b, 0, 'nodetype (node_id 1) fetched with 0 DB queries (resident)' );
is( $nt->{title}, 'nodetype', 'node_id 1 is the nodetype nodetype' );
is( ( $nt->{type} ? $nt->{type}{node_id} : undef ),
    1, '{type} reconstructed from the flat bundle (self-referential nodetype)' );

# --- sanitization survived into the resident copy ------------------------------
is( ( $node->{passwd} // '' ),        '', 'Guest User passwd blanked in the resident node' );
is( ( $node->{validationkey} // '' ), '', 'Guest User validationkey blanked in the resident node' );

done_testing();

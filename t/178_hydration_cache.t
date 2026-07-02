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

# --- #4444 regression: hydrated nodetypes must be fully resolved -----------------
# The bundle captured some nodetypes mid-construction (resolvedInheritance set but
# sqltablelist/tableArray empty). getType's guard then skipped re-derivation, so
# constructNode built nodes of those types MISSING their type-table columns: a
# datastash came back without vars (stashData 500), a user without experience (write
# NULLs it), and getNodeWhere-by-type dropped its join (1054). The loader now strips
# the stale derived fields so getType re-derives cleanly.
for my $tn (qw(user datastash setting e2node achievement)) {
    my $ty = $DB->getType($tn);
    ok( $ty && ref($ty->{tableArray}) && scalar(@{$ty->{tableArray}}),
        "hydrated '$tn' nodetype resolves to a non-empty tableArray (#4444)" );
}
SKIP: {
    my $ds = eval { $DB->getNode('newwriteups', 'datastash') };
    skip 'no newwriteups datastash present', 1 unless $ds;
    ok( defined $ds->{vars},
        'a datastash node builds with its vars column present, not UNDEF (#4444)' );
}
SKIP: {
    my $u = eval { $DB->getNode('normaluser1', 'user') };
    skip 'no normaluser1 present', 1 unless $u;
    ok( defined $u->{experience},
        'a user node builds with its experience column present, not UNDEF (#4444)' );
}

done_testing();

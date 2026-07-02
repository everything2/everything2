#!/usr/bin/perl -w
#
# Hydration-ON coverage (#4446). The rest of the suite bare-inits (no hydration), so
# hydration-only regressions slip through -- that is exactly how #4443/#4444 shipped:
# the bundle carried nodetypes serialized mid-construction (resolvedInheritance set
# but sqltablelist/tableArray empty), getType's guard then never re-derived them, and
# constructNode built every node of those types MISSING its type-table columns
# (achievement 1054, datastash.vars UNDEF -> 500, user.experience UNDEF -> write NULL).
#
# This loads the real committed bundle and asserts the invariant that guards the whole
# class: EVERY hydrated nodetype that owns a sqltable resolves, through getType, to a
# non-empty tableArray that contains that sqltable. If a hydrated nodetype ever ships
# without its derived tables again, this fails.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;

initEverything 'everything';
my $cache = $DB->{cache};

my $bundle = '/var/everything/hydration/hydration_cache.json';
plan skip_all => "no hydration bundle at $bundle" unless -r $bundle;

my $loaded = $cache->loadHydrationCache($bundle);
cmp_ok( $loaded, '>', 400, "loaded $loaded core nodes" );

my $checked = 0;
my $bad     = 0;
for my $id ( sort { $a <=> $b } keys %{ $cache->{hydrationExempt} } ) {
    my $node = $cache->getCachedNodeById($id) or next;
    next unless ( ( $node->{type_nodetype} // 0 ) == 1 );    # nodetypes only

    my $type     = $DB->getType($id);
    my $tables   = $DB->getNodetypeTables($type) || [];
    my $sqltable = $type->{sqltable};

    # A nodetype that owns tables (non-empty sqltable) MUST resolve them. Types with
    # no own table (e.g. the base 'node') legitimately resolve to an empty array.
    next unless ( defined $sqltable && length $sqltable );

    my %have = map { $_ => 1 } @$tables;
    my @own  = grep { length } split /,/, $sqltable;
    my $ok   = scalar(@$tables) && !grep { !$have{$_} } @own;
    $bad++ unless $ok;
    ok( $ok,
        "hydrated nodetype '$type->{title}' resolves tableArray [@$tables] covering sqltable '$sqltable'" );
    $checked++;
}

cmp_ok( $checked, '>', 10, "exercised a meaningful set of hydrated nodetypes ($checked)" );
is( $bad, 0, 'no hydrated nodetype resolved to a missing/empty tableArray (#4443/#4444)' );

# Concrete end-to-end: a node of a hydrated type builds WITH its type-table columns.
# newwriteups is a datastash (vars lives in the type table); a missing tableArray drops it.
SKIP: {
    my $ds = eval { $DB->getNode( 'newwriteups', 'datastash' ) };
    skip 'no newwriteups datastash', 1 unless $ds;
    ok( defined $ds->{vars},
        'datastash node builds with its vars column present (constructNode joined the type table)' );
}

# #4446 item 3: a hydrated CONTENT node's {type} is re-pointed to the resolved
# nodetype, so updateNode (which reads $NODE->{type}{tableArray} directly) writes its
# type-table columns instead of silently dropping them.
SKIP: {
    my $gu = $cache->getCachedNodeById( $Everything::CONF->guest_user );
    skip 'Guest User not resident', 1 unless $gu;
    ok( ref( $gu->{type}{tableArray} ) && scalar( @{ $gu->{type}{tableArray} } ),
        "a hydrated content node's {type} resolves a non-empty tableArray for writes (#4446)" );
}

done_testing();

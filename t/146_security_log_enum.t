#!/usr/bin/perl -w
#
# Unit tests for Everything::SecurityLog -- the security-log event enum (#4272).
# Pure registry logic, no DB. Pins the append-only invariant (ids are persisted in
# ~2M seclog rows) and the legacy node/title -> event mappings used by the backfill
# and the transitional securityLog().
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;

use Everything::SecurityLog qw(:events);

my @events = Everything::SecurityLog->all;
ok( scalar(@events) >= 35, 'registry has the full event set' );

#############################################################################
# Shape + append-only invariants
#############################################################################

subtest 'every event is well-formed' => sub {
    for my $e (@events) {
        ok( defined $e->{id} && $e->{id} =~ /^\d+$/, "id is a non-negative int ($e->{key})" );
        ok( length( $e->{key}   // '' ), "key present ($e->{id})" );
        ok( length( $e->{desc}  // '' ), "desc present ($e->{key})" );
        ok( length( $e->{group} // '' ), "group present ($e->{key})" );
    }
};

subtest 'ids and keys are unique (append-only)' => sub {
    my (%id, %key);
    $id{ $_->{id} }++   for @events;
    $key{ $_->{key} }++ for @events;
    is( scalar( grep { $_ > 1 } values %id ),  0, 'no duplicate ids' );
    is( scalar( grep { $_ > 1 } values %key ), 0, 'no duplicate keys' );
};

is( Everything::SecurityLog->id_for_key('LEGACY_UNKNOWN'), 0, 'LEGACY_UNKNOWN is id 0 (column default)' );

#############################################################################
# Lookups round-trip
#############################################################################

subtest 'by_id / by_key / id_for_key' => sub {
    is( Everything::SecurityLog->id_for_key('MASSACRE'),         5,  'MASSACRE => 5' );
    is( Everything::SecurityLog->id_for_key('PARAMETER_CHANGE'), 26, 'PARAMETER_CHANGE => 26' );
    is( Everything::SecurityLog->id_for_key('PUNCH_THYSELF'),    35, 'PUNCH_THYSELF => 35 (the ex-716619 GP sink)' );
    is( Everything::SecurityLog->by_id(5)->{key},  'MASSACRE', 'by_id(5) round-trips' );
    is( Everything::SecurityLog->by_key('BLESS')->{id}, 18, 'by_key(BLESS) round-trips' );
    is( Everything::SecurityLog->id_for_key('NO_SUCH_EVENT'), undef, 'unknown key => undef' );

    is( Everything::SecurityLog->description(5),     'Kill reasons', 'description(5)' );
    is( Everything::SecurityLog->group(5),           'content',      'group(5)' );
    is( Everything::SecurityLog->description(999999), 'Unknown',     'unknown id => Unknown' );
};

#############################################################################
# Exported constants
#############################################################################

subtest 'SECLOG_* constants match the registry' => sub {
    is( SECLOG_MASSACRE(),         5,  'SECLOG_MASSACRE' );
    is( SECLOG_PARAMETER_CHANGE(), 26, 'SECLOG_PARAMETER_CHANGE' );
    is( SECLOG_LEGACY_UNKNOWN(),   0,  'SECLOG_LEGACY_UNKNOWN' );
};

#############################################################################
# Title mapping (env-stable; used by transitional securityLog)
#############################################################################

subtest 'event_for_title' => sub {
    is( Everything::SecurityLog->event_for_title('parameter'),    26, 'parameter -> PARAMETER_CHANGE' );
    is( Everything::SecurityLog->event_for_title('massacre'),     5,  'massacre -> MASSACRE' );
    is( Everything::SecurityLog->event_for_title('Sign up'),      1,  'Sign up -> USER_SIGNUP' );
    is( Everything::SecurityLog->event_for_title('bestow cools'), 20, 'bestow cools -> COOLS_BESTOWED' );
    is( Everything::SecurityLog->event_for_title('punch thyself'), 35, 'punch thyself -> PUNCH_THYSELF' );
    is( Everything::SecurityLog->event_for_title('not a category'), 0, 'unknown title -> LEGACY_UNKNOWN' );
    is( Everything::SecurityLog->event_for_title(undef),          0,  'undef title -> LEGACY_UNKNOWN' );

    # no title maps to two events
    my %seen;
    for my $e (@events) { $seen{$_}++ for @{ $e->{titles} } }
    is( scalar( grep { $_ > 1 } values %seen ), 0, 'each title maps to exactly one event' );
};

#############################################################################
# Prod node mapping (backfill only) -- incl. the dangling legacy ids
#############################################################################

subtest 'event_for_node (prod ids, incl. dangling)' => sub {
    is( Everything::SecurityLog->event_for_node(648516),   5,  'massacre node -> MASSACRE' );
    is( Everything::SecurityLog->event_for_node(2071202),  26, 'parameter node -> PARAMETER_CHANGE' );
    is( Everything::SecurityLog->event_for_node(2015009),  2,  'dangling old user-deletion node -> USER_DELETION' );
    is( Everything::SecurityLog->event_for_node(1668580),  25, 'dangling old resurrection node -> RESURRECTION' );
    is( Everything::SecurityLog->event_for_node(716619),   35, 'tombed "punch thyself" node -> PUNCH_THYSELF' );
    is( Everything::SecurityLog->event_for_node(99999999), 0,  'unknown node -> LEGACY_UNKNOWN' );

    # no prod node id maps to two events
    my %seen;
    for my $e (@events) { $seen{$_}++ for @{ $e->{nodes} } }
    is( scalar( grep { $_ > 1 } values %seen ), 0, 'each prod node id maps to exactly one event' );
};

done_testing();

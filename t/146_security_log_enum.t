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

done_testing();

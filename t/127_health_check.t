#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting ValuesAndExpressions ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON qw(decode_json);
use Everything::HealthCheck;

# Everything::HealthCheck is a standalone PSGI app (the rewrite of www/health.pl).
# It needs no framework init -- call handle() with a synthetic PSGI env and
# assert the PSGI response triple.

sub call {
    my ($qs) = @_;
    my $r = Everything::HealthCheck->handle( { QUERY_STRING => $qs } );
    isa_ok( $r, 'ARRAY', "response for '$qs'" );
    is( ref $r->[1], 'ARRAY', 'headers arrayref' );
    is( ref $r->[2], 'ARRAY', 'body arrayref' );
    my %h = @{ $r->[1] };
    like( $h{'Content-Type'}, qr{application/json}, 'JSON content-type' );
    like( $h{'Cache-Control'}, qr/no-store/, 'no-store cache-control' );
    return ( $r->[0], decode_json( $r->[2][0] ) );
}

subtest 'basic liveness (no args) -- fast, DB-independent' => sub {
    my ( $status, $body ) = call('');
    is( $status, 200, 'HTTP 200' );
    is( $body->{status},  'ok',              'status ok' );
    is( $body->{backend}, 'psgi',            'backend psgi' );
    is( $body->{version}, 'health-check-v2', 'version' );
    ok( $body->{timestamp} > 0, 'timestamp present' );
    ok( !exists $body->{checks}, 'no checks on the basic path' );
    ok( !exists $body->{system}, 'no system metrics on the basic path' );
    ok( !exists $body->{memory}, 'no memory metrics on the basic path' );
};

subtest 'detailed=1 -- system + memory, no DB' => sub {
    my ( $status, $body ) = call('detailed=1');
    is( $status, 200, 'HTTP 200 (no DB probe)' );
    is( $body->{checks}{app}, 'ok', 'app check ok' );
    ok( exists $body->{system}, 'system metrics present (/proc/loadavg)' );
    ok( exists $body->{memory}, 'memory metrics present (/proc/meminfo)' );
    ok( exists $body->{response_ms}, 'response_ms present' );
    ok( !exists $body->{checks}{database}, 'no DB check unless ?db=1' );
};

subtest 'db=1 -- framework-free DB probe; status/code consistent' => sub {
    my ( $status, $body ) = call('db=1');
    ok( exists $body->{checks}{database}, 'database check present' );
    ok( exists $body->{system},           'db probe implies detailed (system metrics)' );
    if ( $body->{checks}{database} eq 'ok' ) {
        is( $status, 200, 'DB ok -> 200' );
        is( $body->{status}, 'ok', 'overall status ok' );
    }
    else {
        is( $status, 503, "DB '$body->{checks}{database}' -> 503" );
        is( $body->{status}, 'unhealthy', 'overall status unhealthy' );
    }
};

subtest 'query parser handles multiple params' => sub {
    my ( undef, $body ) = call('detailed=1&db=1');
    ok( exists $body->{checks}{database}, 'both params parsed' );
    ok( exists $body->{memory},           'detailed honored alongside db' );
};

done_testing();

#!/usr/bin/perl -w
#
# Non-ASCII titles round-trip through a full web request (#4570).
#
# Request params are decoded to Perl character strings at the input edge
# (Everything::Request::PlackQuery and the /title/ route-recovery helper), matching
# what the utf8mb4 database returns. When a param stayed raw bytes, any page that
# echoed it back next to database text encoded it twice: the Findings page for
# "/title/Don’t ..." showed "Donâ€™t ...". These requests go through app.psgi so the
# whole path is covered: decode, lookup, JSON payload, response encoding.
#
use strict;
use warnings;
use utf8;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Encode qw(encode_utf8);
use Everything;

initEverything 'everything';

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);

sub get_body {
    my ($path) = @_;
    my $res = $test->request( HTTP::Request::Common::GET($path) );
    return ( $res->code, $res->content );    # raw response bytes
}

# The response body must carry the title's UTF-8 bytes, and none of the
# double-encoded forms (each UTF-8 byte re-encoded as its own character).
sub has_title_once_encoded {
    my ( $body, $title, $desc ) = @_;
    my $once  = encode_utf8($title);
    my $twice = encode_utf8( encode_utf8($title) );
    subtest $desc => sub {
        ok( index( $body, $once ) >= 0, 'title appears UTF-8 encoded once' );
        ok( index( $body, $twice ) < 0, 'title does not appear double-encoded' );
    };
}

# --- titles that don't exist: the Findings page echoes the searched title -------
for my $case (
    [ 'curly apostrophe', "Zzqx\x{2019}s nonexistent thing", '/title/Zzqx%E2%80%99s%20nonexistent%20thing' ],
    [ 'Latin-1 range',    "Caf\x{e9} zzqx nothing",          '/title/Caf%C3%A9%20zzqx%20nothing' ],
    [ 'CJK',              "\x{7F8E}\x{56FD} zzqx",           '/title/%E7%BE%8E%E5%9B%BD%20zzqx' ],
    [ 'emoji',            "zzqx \x{1F415}",                  '/title/zzqx%20%F0%9F%90%95' ],
    [ 'query string',     "Caf\x{e9} zzqx query",            '/?node=Caf%C3%A9%20zzqx%20query' ],
    )
{
    my ( $desc, $title, $path ) = @$case;
    my ( $code, $body ) = get_body($path);
    is( $code, 200, "$desc: Findings page responds" );
    has_title_once_encoded( $body, $title, "$desc: Findings echoes the searched title correctly" );
}

# --- titles that do exist: lookups of non-ASCII titles still resolve ------------
my $existing = $DB->{dbh}->selectall_arrayref(
    q{SELECT node_id, title FROM node WHERE type_nodetype = ? AND title REGEXP '[^ -~]' ORDER BY node_id LIMIT 5},
    undef, $DB->getType('e2node')->{node_id} );

SKIP: {
    skip 'no non-ASCII e2node titles in this database', 1 unless @$existing;
    for my $row (@$existing) {
        my ( $node_id, $title ) = @$row;
        my $path = '/title/' . join( '', map { sprintf '%%%02X', ord } split //, encode_utf8($title) );
        my ( $code, $body ) = get_body($path);
        like( $body, qr/"node_id":$node_id\b/, "existing title resolves to its node ($node_id)" );
    }
}

# --- curly vs straight apostrophe: two different titles, two different nodes ------
# Seeded by tools/seeds.pl. The utf8mb4_0900_ai_ci collation is accent-insensitive;
# make sure it doesn't fold U+2019 into U+0027 and send both links to one node.
SKIP: {
    my %id;
    for my $title ( "Don\x{2019}t panic", "Don't panic" ) {
        my $node = $DB->getNode( $title, 'e2node' );
        $id{$title} = $node && $node->{node_id};
    }
    skip 'apostrophe seed nodes not present', 3 if grep { !$_ } values %id;

    my ( undef, $curly )    = get_body('/title/Don%E2%80%99t%20panic');
    my ( undef, $straight ) = get_body("/title/Don't%20panic");
    like( $curly,    qr/"node_id":$id{"Don\x{2019}t panic"}\b/, 'curly-apostrophe link resolves to the curly node' );
    like( $straight, qr/"node_id":$id{"Don't panic"}\b/,        'straight-apostrophe link resolves to the straight node' );
    isnt( $id{"Don\x{2019}t panic"}, $id{"Don't panic"}, 'they are different nodes' );
}

done_testing();

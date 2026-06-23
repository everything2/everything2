#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitEscapedCharacters)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Everything::PageState;

# Step 2a: Everything::PageState->normalize_types (the #4152/#4108 fix) + the
# GET /api/pagestate facade endpoint. The unit half is pure; the HTTP half hits the
# running container and SKIPs if it's unreachable.

#############################################################################
# normalize_types -- integer-string IDs coerced to real integers
#############################################################################

subtest 'normalize_types coerces integer-string IDs to real ints' => sub {
    my $d = {
        node_id          => "1234567",
        title            => "Some Title",         # non-int key, left alone
        use_local_assets => "0",                  # string flag -> 0 (truthy-bug fix)
        list             => [ { node_id => "42", author_user => "99", name => "x" }, { node_id => "0" } ],
        nested           => { user_id => "555", note => "keep-string" },
        nonnumeric       => { node_id => "abc" }, # not an integer-string -> untouched
        already_int      => { node_id => 7 },
    };
    Everything::PageState->normalize_types($d);

    is( $d->{node_id},              1234567, 'top-level node_id numified' );
    is( $d->{use_local_assets},     0,       'use_local_assets "0" -> 0' );
    is( $d->{list}[0]{node_id},     42,      'node_id nested in an array numified' );
    is( $d->{list}[0]{author_user}, 99,      'author_user numified' );
    is( $d->{list}[0]{name},        "x",     'non-int key untouched' );
    is( $d->{list}[1]{node_id},     0,       'node_id "0" -> 0' );
    is( $d->{nested}{user_id},      555,     'deep user_id numified' );
    is( $d->{nested}{note},         "keep-string", 'non-int value untouched' );
    is( $d->{title},                "Some Title",  'non-int key untouched' );
    is( $d->{nonnumeric}{node_id},  "abc",   'non-numeric node_id left alone' );

    # The real assertion: it serializes as a NUMBER, not a quoted string.
    my $enc = JSON->new->canonical->encode($d);
    like(   $enc, qr/"node_id":1234567(?!")/, 'node_id encodes unquoted (real int)' );
    unlike( $enc, qr/"node_id":"1234567"/,    'node_id is NOT a quoted string' );
    like(   $enc, qr/"use_local_assets":0(?!")/, 'use_local_assets encodes as 0, not "0"' );
};

#############################################################################
# GET /api/pagestate -- the facade endpoint (guest), end-to-end
#############################################################################

SKIP: {
    eval { require LWP::UserAgent; 1 } or skip 'LWP::UserAgent unavailable', 1;
    my $ua   = LWP::UserAgent->new( timeout => 20 );
    my $resp = eval { $ua->get('http://localhost/api/pagestate') };
    skip 'pagestate endpoint unreachable', 1 unless $resp && $resp->is_success;

    is( $resp->code, 200, 'GET /api/pagestate returns 200' );
    like( $resp->header('content-type'), qr{application/json}i, 'JSON content-type' );

    my $page = eval { JSON->new->decode( $resp->content ) };
    ok( ref $page eq 'HASH', 'pagestate decodes to an object' );

    # Full page payload: chrome + the node content + the rendering key.
    ok( exists $page->{user},        'carries chrome identity (user)' );
    ok( exists $page->{newWriteups}, 'carries the newWriteups feed' );
    ok( exists $page->{contentData}, 'carries the node content (contentData)' );
    ok( $page->{contentData} && $page->{contentData}{type},
        'content carries the rendering key (contentData.type)' );

    # Normalization held end-to-end (content included): no string-typed node_id survives.
    unlike( $resp->content, qr/"node_id":"\d/, 'no string-typed node_id in /api/pagestate' );

    # Head metadata: the React app sets <title>/canonical/JSON-LD from this on client nav.
    ok( $page->{meta}, 'carries the page head metadata (meta)' );
    ok( $page->{meta} && $page->{meta}{title},     'meta.title present' );
    ok( $page->{meta} && $page->{meta}{canonical}, 'meta.canonical present' );
    ok( $page->{meta} && $page->{meta}{jsonLd} && $page->{meta}{jsonLd}{'@graph'},
        'meta.jsonLd carries a schema.org @graph' );

    # Addressing forms: id, title+type, title-default-e2node, lookup path, bad lookup.
    my $type_of = sub {
        my $r = $ua->get( 'http://localhost' . $_[0] );
        return undef unless $r && $r->is_success;
        my $d = eval { JSON->new->decode( $r->content ) };
        return ( $d->{contentData} || {} )->{type};
    };
    is( $type_of->('/api/pagestate?title=root&type=user'), 'user',
        '?title=root&type=user resolves the user view' );
    is( $type_of->('/api/pagestate/lookup/user/root'), 'user',
        'lookup/:type/:title path form resolves' );

    # Per-document-type addressing: the facade exists to serve controller-class
    # nodes, and each carries the contentData.type that DocumentComponent.js (and
    # the future React router) keys its view off. Superdocs normalize to a
    # document-specific key (title-slug), not the bare "superdoc" type -- pin a
    # few so a normalize/resolve regression can't silently mistype a whole class
    # of pages during the routing flip. Rows whose node isn't in this DB (seed
    # variance) are skipped, not failed.
    my %type_cases = (
        'Settings'                 => [ 'superdoc', 'settings' ],                  # core system superdoc
        "Everything's Most Wanted" => [ 'superdoc', 'everything_s_most_wanted' ],  # content superdoc
        'Coffee Culture'           => [ 'category', 'category' ],                  # category controller-class
    );
    for my $title ( sort keys %type_cases ) {
        my ( $type, $want ) = @{ $type_cases{$title} };
        ( my $esc = $title ) =~ s/([^A-Za-z0-9])/sprintf('%%%02X', ord $1)/ge;
        my $got = $type_of->("/api/pagestate?title=$esc&type=$type");
        if ( !defined $got ) { diag("skip '$title' ($type): not resolvable in this DB"); next; }
        is( $got, $want, "$type '$title' resolves contentData.type='$want'" );
    }

    my $bad = $ua->get('http://localhost/api/pagestate/lookup/e2node/NoSuchNode_zzz_999');
    is( $bad->code, 200, 'bad lookup is still HTTP 200 (E2 convention)' );
    my $bd = JSON->new->decode( $bad->content );
    is( $bd->{success}, 0, 'bad lookup returns success=0' );
}

done_testing();

=head1 NAME

t/142_pagestate_api.t - Step 2a: PageState->normalize_types + the /api/pagestate facade

=cut

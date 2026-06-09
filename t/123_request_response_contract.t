#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting ValuesAndExpressions ProhibitMagicNumbers ProhibitEscapedCharacters)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Plack::Request;
use Everything::Request::PlackQuery;
use Everything::Response;

# CGI-free contract test for the request/response layer. Replaces the migration
# parity scaffolds (which compared against CGI, now removed): the equivalence is
# proven and the behaviour is exercised by t/122 + the full integration suite.
# This pins the few SUBTLE, E2-specific behaviours directly, against literal
# expected values -- no CGI, no framework init.

sub pq {
    my ( $qs, %env ) = @_;
    open my $in, '<', \( my $e = '' ) or die $!;
    return Everything::Request::PlackQuery->new(
        req => Plack::Request->new(
            { QUERY_STRING => $qs, REQUEST_METHOD => 'GET', 'psgi.input' => $in, 'psgi.url_scheme' => 'http', %env }
        )
    );
}

#############################################################################
# Everything::Request::PlackQuery -- read + mutation contract
#############################################################################

subtest 'param scalar = FIRST value of a multi-value key (CGI-compat rule)' => sub {
    my $q = pq('a=1&a=2&a=3&b=x&empty=');
    is( scalar( $q->param('a') ), '1', 'scalar param is the FIRST value' );
    is_deeply( [ $q->multi_param('a') ], [ '1', '2', '3' ], 'multi_param is all values, in order' );
    is( scalar( $q->param('b') ),       'x',   'single-value scalar' );
    is( scalar( $q->param('empty') ),   '',    'empty-valued param is empty string' );
    is( scalar( $q->param('missing') ), undef, 'missing param is undef' );
    is_deeply( [ sort $q->param ], [qw(a b empty)], 'param() with no args lists names' );
};

subtest 'decoding: UTF-8 bytes, encoded ampersand, plus-as-space' => sub {
    my $q = pq('t=caf%C3%A9&amp=a%26b&plus=a+b');
    is( $q->param('t'),    "caf\xc3\xa9", 'UTF-8 decodes to raw bytes' );
    is( $q->param('amp'),  'a&b',         'encoded ampersand' );
    is( $q->param('plus'), 'a b',         'plus decodes to space' );
};

subtest 'Vars joins multi-values with NUL' => sub {
    my $v = pq('a=1&a=2&b=x&c=')->Vars;
    is( $v->{a}, "1\x002", 'multi-value joined with \\0' );
    is( $v->{b}, 'x',      'single value plain' );
    is( $v->{c}, '',       'empty value' );
};

subtest 'mutable param table: set / delete / delete_all' => sub {
    my $q = pq('a=1&a=2&b=x');
    $q->param( 'a', 'z' );
    is( scalar( $q->param('a') ), 'z', 'set scalar replaces' );
    is_deeply( [ $q->multi_param('a') ], ['z'], 'set collapses to single' );
    $q->param( 'new', 'n' );
    ok( ( grep { $_ eq 'new' } $q->param ), 'set new key appears in names' );
    $q->delete('b');
    is( scalar( $q->param('b') ), undef, 'delete removes the key' );
    $q->delete_all;
    is_deeply( [ $q->param ], [], 'delete_all clears everything' );
};

subtest 'op-default idiom (param("op","") when absent)' => sub {
    my $q = pq('node_id=1');
    is( scalar( $q->param('op') ), undef, 'op absent initially' );
    $q->param( 'op', '' ) unless defined $q->param('op');
    is( scalar( $q->param('op') ), '', 'op defaulted to empty string, not undef' );
};

subtest 'cookie read + request_method' => sub {
    my $q = pq( 'a=1', HTTP_COOKIE => 'userpass=root%7Cabc; theme=blue', REQUEST_METHOD => 'POST' );
    is( $q->cookie('userpass'), 'root|abc', 'cookie read, | decoded' );
    is( $q->cookie('theme'),    'blue',     'second cookie' );
    is( $q->cookie('missing'),  undef,      'missing cookie undef' );
    is( $q->request_method,     'POST',     'request_method' );
};

subtest 'multipart upload via Plack' => sub {
    my $boundary  = 'BoUnDaRy';
    my $file_data = "\x89PNGfake";
    my $body      = join( "\r\n",
        "--$boundary",
        'Content-Disposition: form-data; name="imgsrc_file"; filename="p.png"',
        'Content-Type: image/png', '', $file_data, "--$boundary--", '' );
    open my $in, '<', \( my $b = $body ) or die $!;
    my $q = Everything::Request::PlackQuery->new(
        req => Plack::Request->new( {
            REQUEST_METHOD => 'POST',
            CONTENT_TYPE   => "multipart/form-data; boundary=$boundary",
            CONTENT_LENGTH => length($body),
            QUERY_STRING   => '',
            'psgi.input'   => $in,
            'psgi.url_scheme' => 'http',
        } ) );
    my $up = $q->upload('imgsrc_file');
    ok( $up, 'upload() returns the file object' );
    is( $q->uploadInfo($up)->{'Content-Type'}, 'image/png', 'uploadInfo content-type' );
    is( $q->upload('nope'), undef, 'missing upload field is undef' );
};

#############################################################################
# Everything::Response -- output contract
#############################################################################

subtest 'format_cookie: session + remember-me (value url-encoded)' => sub {
    is( Everything::Response->format_cookie( -name => 'userpass', -value => 'root|abc', -path => '/', -samesite => 'Lax' ),
        'userpass=root%7Cabc; path=/; SameSite=Lax', 'session cookie (no expires, | -> %7C)' );
    like( Everything::Response->format_cookie( -name => 'userpass', -value => 'root|abc', -expires => '+1y', -path => '/', -samesite => 'Lax' ),
        qr{^userpass=root%7Cabc; path=/; expires=\w{3}, .+ GMT; SameSite=Lax$}, 'remember-me adds a valid expires' );
};

subtest 'cgi_header: Content-Type block, Status, Set-Cookie' => sub {
    is( Everything::Response->cgi_header( -type => 'text/html', charset => 'utf-8' ),
        "Content-Type: text/html; charset=utf-8\r\n\r\n", 'page header block' );
    my $h = Everything::Response->cgi_header( -type => 'application/json', charset => 'utf-8', -status => '404 Not Found' );
    like( $h, qr/^Status: 404 Not Found\r\n/, 'status line first' );
    like( $h, qr{Content-Type: application/json; charset=utf-8\r\n\r\n$}, 'content-type last' );
    like( Everything::Response->cgi_header( { -cookie => 'userpass=x; path=/' } ),
        qr{Set-Cookie: userpass=x; path=/\r\n}, 'set-cookie carried through (hashref form)' );
};

subtest 'cgi_redirect: 303 and default 302' => sub {
    is( Everything::Response->cgi_redirect( -uri => '/title/Foo', -status => 303 ),
        "Status: 303\r\nLocation: /title/Foo\r\n\r\n", '303 with Location' );
    is( Everything::Response->cgi_redirect('https://example.com/y'),
        "Status: 302\r\nLocation: https://example.com/y\r\n\r\n", 'default 302' );
};

subtest 'Response object: finalize -> PSGI triple with Set-Cookie' => sub {
    my $r = Everything::Response->new;
    $r->status(200);
    $r->content_type('application/json; charset=utf-8');
    $r->set_cookie( 'userpass', { value => 'root|abc', path => '/', samesite => 'Lax' } );
    $r->body('{"ok":1}');
    my $t = $r->finalize;
    is( $t->[0], 200, 'status' );
    my %hdr = @{ $t->[1] };
    like( $hdr{'Content-Type'}, qr{application/json}, 'content-type header' );
    ok( ( grep { /^userpass=/ } map { $t->[1][$_] } grep { $_ % 2 } 0 .. $#{ $t->[1] } ), 'Set-Cookie baked into finalize' );
    is( $t->[2][0], '{"ok":1}', 'body' );
};

done_testing();

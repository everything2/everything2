#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting ValuesAndExpressions ProhibitMagicNumbers ProhibitEscapedCharacters ProhibitNoisyQuotes)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything::Response;

# Return-based response contract + parity (the "moving HTTP out of controllers"
# step -- docs/api-driven-architecture.md). The API path no longer prints into the
# STDOUT capture; Everything::APIRouter::output builds an Everything::Response via
# from_cgi_parts() and RETURNS it for app.psgi to finalize. This test pins:
#   (1) from_cgi_parts() -> finalize() emits the right PSGI triple (contract), and
#   (2) it is field-for-field equivalent to the capture path -- i.e. parsing
#       cgi_header()'s block the same way app.psgi's _cgi_output_to_psgi does yields
#       the same status + headers (parity). Both consume the same _parse_header_args.
# CGI-free, no framework init -- Everything::Response only needs Plack + Cookie::Baker.

#############################################################################
# Helpers
#############################################################################

# A flat PSGI header list ([k,v,k,v,...]) -> { lc_key => [values in order] }.
# Content-Length is excluded: Plack::Response->finalize auto-derives it from the
# body on the return path, while on the capture path the PSGI server adds it at
# serve time -- both correct on the wire, so it is not a parity field.
sub header_multimap {
    my ($flat) = @_;
    my %m;
    for ( my $i = 0; $i < @$flat; $i += 2 ) {
        my $k = lc $flat->[$i];
        next if $k eq 'content-length';
        push @{ $m{$k} }, $flat->[ $i + 1 ];
    }
    return \%m;
}

# Parse a CGI header BLOCK ("Key: Val\r\n...\r\n\r\n") the way app.psgi's
# _cgi_output_to_psgi does: pull the Status code out, collect the rest as headers.
sub parse_cgi_block {
    my ($block) = @_;
    my ( $head, $body ) = split /\r?\n\r?\n/, $block, 2;
    my $status = 200;
    my @flat;
    for my $line ( split /\r?\n/, $head ) {
        my ( $k, $v ) = split /:\s*/, $line, 2;
        next unless defined $v;
        if ( lc $k eq 'status' ) { ($status) = $v =~ /(\d{3})/; $status ||= 200 }
        else { push @flat, $k, $v }
    }
    return ( $status, header_multimap( \@flat ) );
}

# finalize() the return-based response for a CGI-style header hash + body.
sub finalize_parts {
    my ( $h, $body ) = @_;
    my $r = Everything::Response->from_cgi_parts( $h, $body )->finalize;
    my $got_body = '';
    if ( ref $r->[2] eq 'ARRAY' ) { $got_body = join '', @{ $r->[2] } }
    return ( $r->[0], header_multimap( $r->[1] ), $got_body, $r->[1] );
}

# The matrix mirrors what Everything::APIRouter::output actually produces: every
# API response is application/json; the optional bits are cookies, the cache-control
# that pairs with a cookie, the dev-only CORS header, and varied status codes.
my @cases = (
    {
        name => 'plain JSON 200 with body',
        h    => { status => 200, type => 'application/json', charset => 'utf-8' },
        body => '{"display":{"is_guest":1}}',
    },
    {
        name => 'header-only 401 (no body)',
        h    => { status => 401, type => 'application/json', charset => 'utf-8' },
        body => undef,
    },
    {
        name => 'login response: cookie + no-store cache-control',
        h    => {
            status         => 200,
            type           => 'application/json',
            charset        => 'utf-8',
            cookie         => 'userpass=joe%7Cabc; path=/; SameSite=Lax',
            'Cache-Control' => 'private, no-cache, no-store, must-revalidate',
        },
        body => '{"display":{"is_guest":0}}',
    },
    {
        name => 'dev mode: Access-Control-Allow-Origin custom header',
        h    => {
            status                       => 200,
            type                         => 'application/json',
            charset                      => 'utf-8',
            '-Access-Control-Allow-Origin' => '*',
        },
        body => '{"ok":1}',
    },
    {
        name => 'multiple Set-Cookie (arrayref)',
        h    => {
            status  => 200,
            type    => 'application/json',
            charset => 'utf-8',
            cookie  => [ 'a=1; path=/', 'b=2; path=/' ],
        },
        body => '{"ok":1}',
    },
    {
        name => 'status given as "NNN Reason" reduces to the code',
        h    => { status => '404 Not Found', type => 'application/json', charset => 'utf-8' },
        body => '{"error":"nope"}',
    },
);

#############################################################################
# (1) + (2): contract values AND parity vs the capture path, per case
#############################################################################

for my $c (@cases) {
    subtest $c->{name} => sub {
        # cgi_header takes a flat list; pass a copy so we never mutate the case.
        my ( $cap_status, $cap_hdrs ) = parse_cgi_block( Everything::Response->cgi_header( %{ $c->{h} } ) );
        my ( $ret_status, $ret_hdrs, $ret_body, $ret_flat ) = finalize_parts( $c->{h}, $c->{body} );

        is( $ret_status, $cap_status, "status matches the capture path ($cap_status)" );
        is_deeply( $ret_hdrs, $cap_hdrs, 'header fields match the capture path (Content-Length excluded)' );

        # Body passes through byte-for-byte (undef body -> empty).
        is( $ret_body, defined $c->{body} ? $c->{body} : '', 'body is unchanged' );

        # Content-Type is always present and carries the charset.
        ok( $ret_hdrs->{'content-type'}, 'Content-Type present' );
        like( $ret_hdrs->{'content-type'}[0], qr{^application/json; charset=utf-8$},
            'Content-Type is application/json; charset=utf-8' );

        # If finalize emitted a Content-Length, it equals the body length.
        for ( my $i = 0; $i < @$ret_flat; $i += 2 ) {
            next unless lc $ret_flat->[$i] eq 'content-length';
            is( $ret_flat->[ $i + 1 ], length($ret_body), 'Content-Length equals body length' );
        }
    };
}

#############################################################################
# Specific contract spot-checks (literal expectations, not just parity)
#############################################################################

subtest 'cookie produces a Set-Cookie header + pairs with Cache-Control' => sub {
    my ( undef, $h ) = finalize_parts(
        {   status => 200, type => 'application/json', charset => 'utf-8',
            cookie => 'userpass=joe; path=/',
            'Cache-Control' => 'private, no-cache, no-store, must-revalidate',
        },
        '{"ok":1}'
    );
    is_deeply( $h->{'set-cookie'}, ['userpass=joe; path=/'], 'Set-Cookie carries the baked cookie value' );
    is( $h->{'cache-control'}[0], 'private, no-cache, no-store, must-revalidate', 'Cache-Control set' );
};

subtest 'two cookies become two Set-Cookie headers in order' => sub {
    my ( undef, $h ) = finalize_parts(
        { status => 200, type => 'application/json', charset => 'utf-8', cookie => [ 'a=1', 'b=2' ] },
        '{}'
    );
    is_deeply( $h->{'set-cookie'}, [ 'a=1', 'b=2' ], 'both Set-Cookie headers, in order' );
};

subtest 'class vs instance invocation both work' => sub {
    my $a = Everything::Response->from_cgi_parts( { status => 200, type => 'application/json' }, '{}' );
    isa_ok( $a, 'Everything::Response', 'class-method call returns a response' );
    my $b = Everything::Response->new->from_cgi_parts( { status => 200, type => 'application/json' }, '{}' );
    isa_ok( $b, 'Everything::Response', 'instance-method call returns a response' );
    is( $a->finalize->[0], 200, 'finalizes to 200' );
};

subtest 'arrayref header args accepted (not just hashref)' => sub {
    my ( $status, $h ) = finalize_parts(
        [ status => 503, type => 'application/json', charset => 'utf-8' ], '{"maint":1}' );
    is( $status, 503, 'arrayref pairs parsed' );
    like( $h->{'content-type'}[0], qr{application/json}, 'type from arrayref' );
};

done_testing();

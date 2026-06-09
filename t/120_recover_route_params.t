#!/usr/bin/perl -w
#
# Smoke test for Everything::HTML::_recover_route_params_from_request_uri --
# the function that re-derives node/type/author params from the raw, encoded
# $ENV{REQUEST_URI}. Under PSGI this REPLACES the old mod_rewrite title rules
# (the "mod_rewrite hell" of getting '+', '&', apostrophes, '#', multi-space,
# and UTF-8 through Apache intact). This pins the decode so a regression in the
# helper -- or in the Apache [NE] passthrough that feeds it -- is caught fast,
# without a browser.
#
# The REQUEST_URI values below are what actually arrives on the wire: LinkNode
# percent-encodes & @ + / ; ? # exactly once, the browser encodes the rest, and
# Apache (with [NE]) passes that through untouched. _recover decodes once.
#
use strict;
use lib qw(/var/libraries/lib/perl5 /var/everything/ecore);
use Test::More;
use Plack::Request;
use Everything::Request::PlackQuery;
use Everything::HTML;

# Drive the helper: set REQUEST_URI, hand it a fresh query object, read back the
# params. The helper receives the Plack-backed query object in production (CGI is
# gone), so we test it with an empty PlackQuery -- the real path.
sub recover {
    my ($uri) = @_;
    local $ENV{REQUEST_URI} = $uri;
    open my $in, '<', \(my $empty = '') or die $!;
    my $q = Everything::Request::PlackQuery->new(
        req => Plack::Request->new(
            { QUERY_STRING => '', REQUEST_METHOD => 'GET', 'psgi.input' => $in, 'psgi.url_scheme' => 'http' }
        )
    );
    Everything::HTML::_recover_route_params_from_request_uri($q);
    return { map { $_ => $q->param($_) } $q->param };
}

# [ description, REQUEST_URI, expected-params-hashref ]
my @cases = (
    [ 'plain title',
      '/title/good%20poetry',
      { node => 'good poetry' } ],

    [ "literal + (Writeups+plusses) -- %2B must decode to '+', NOT a space",
      '/title/Writeups%2Bplusses%2C%20a%20lesson%20in%20love',
      { node => 'Writeups+plusses, a lesson in love' } ],

    [ 'C++ (two literal pluses)',
      '/title/C%2B%2B',
      { node => 'C++' } ],

    [ 'ampersand (#4060 Sense & Sensibility) -- %26 decodes, no truncation',
      '/title/Sense%20%26%20Sensibility',
      { node => 'Sense & Sensibility' } ],

    [ 'apostrophe (#4145 Neiboku\'s Secret Library)',
      "/title/Neiboku's%20Secret%20Library",
      { node => "Neiboku's Secret Library" } ],

    [ 'hash/pound (#4132 Star Trek #9)',
      '/title/Star%20Trek%20%239',
      { node => 'Star Trek #9' } ],

    [ 'multi-space (#3418) -- both spaces preserved',
      '/title/red%20%20pepper',
      { node => 'red  pepper' } ],

    [ 'bare + as space (legacy Message+Inbox path, #4143)',
      '/title/Message+Inbox',
      { node => 'Message Inbox' } ],

    [ 'node/<type>/<title>',
      '/node/superdoc/Cool%20Archive',
      { type => 'superdoc', node => 'Cool Archive' } ],

    [ 'user writeups (author + node + type)',
      '/user/Simpleton/writeups/good%20poetry',
      { author => 'Simpleton', node => 'good poetry', type => 'writeup' } ],

    [ 'numeric node_id (no decode needed)',
      '/node/2213791',
      { node_id => '2213791' } ],

    [ 'query string is ignored (only the path matters)',
      '/title/good%20poetry?lastnode_id=0',
      { node => 'good poetry' } ],
);

for my $c (@cases) {
    my ( $desc, $uri, $want ) = @$c;
    my $got = recover($uri);
    is_deeply( $got, $want, $desc )
        or diag( "  URI: $uri\n  got: " . join( ', ', map {"$_=$got->{$_}"} sort keys %$got ) );
}

# UTF-8 emoji: %XX decode yields the raw UTF-8 BYTES of the title (chr(hex)).
# Compare via a hex dump so the assertion is independent of Perl's internal
# utf8 flag (which CGI param storage can toggle) -- what matters is the bytes.
{
    my $got = recover('/title/animals%20%F0%9F%90%95');  # "animals 🐕"
    my $node = $got->{node};
    utf8::encode($node) if utf8::is_utf8($node);   # normalize to bytes
    is( unpack( 'H*', $node ), unpack( 'H*', "animals \xF0\x9F\x90\x95" ),
        'emoji title decodes to the right raw UTF-8 bytes' );
}

done_testing();

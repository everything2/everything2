#!/usr/bin/perl -w
#
# 103_rewrite_clean_escape.t
#
# Comprehensive unit tests for Everything::Application::rewriteCleanEscape
# and its round-trip with Everything::HTML::_recover_route_params_from_request_uri.
#
# Why so much: this function has been a load-bearing source of pain
# (#4060, #4143, #4145). The contract is now:
#
#   1. SINGLE-encode via CGI::escape (no double-encoding).
#   2. Collapse ISOLATED mid-string %20 to '+' for cosmetic reasons.
#      Skip leading/trailing %20 and runs of adjacent %20s.
#   3. Output MUST round-trip through the helper back to the original
#      title across every route the helper recognizes.
#
# This file pins each piece of that contract loudly. If any of these
# break, every URL on the site with a special character in its title
# either 404s, infinite-loops on the redirect-to-canonical path, or
# silently lands on the wrong node.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::HTML;

initEverything('development-docker');
ok($APP, 'application object available');

sub encoded { return $APP->rewriteCleanEscape($_[0]); }

#############################################################################
# Section 1 — Direct encoding contract
#############################################################################
subtest 'plain ASCII, no special handling' => sub {
    is(encoded('foo'),      'foo',      'plain word');
    is(encoded('Foo123'),   'Foo123',   'mixed case + digits');
    is(encoded('hello'),    'hello',    'lowercase');
    is(encoded('HELLO'),    'HELLO',    'uppercase');
    is(encoded('a'),        'a',        'single char');
};

subtest 'URL-reserved characters single-encode' => sub {
    # Each reserved char gets encoded exactly once. Loud assertions so a
    # future careless change to the encoder is impossible to miss.
    is(encoded("'"),   '%27', "apostrophe → %27 (the #4145 case)");
    is(encoded('&'),   '%26', "ampersand → %26 (the #4060 case)");
    is(encoded('+'),   '%2B', 'literal plus → %2B');
    is(encoded('#'),   '%23', 'hash → %23 (the #4132 case)');
    is(encoded('?'),   '%3F', 'question mark → %3F');
    is(encoded('/'),   '%2F', 'slash → %2F');
    is(encoded('@'),   '%40', 'at-sign → %40');
    is(encoded(';'),   '%3B', 'semicolon → %3B');
    is(encoded('='),   '%3D', 'equals → %3D');
    is(encoded('%'),   '%25', 'literal % → %25 (must NOT round-trip as %25XX)');
    is(encoded('"'),   '%22', 'double-quote → %22');
    is(encoded('<'),   '%3C', 'less-than → %3C');
    is(encoded('>'),   '%3E', 'greater-than → %3E');
    is(encoded(','),   '%2C', 'comma → %2C');
    is(encoded(':'),   '%3A', 'colon → %3A');
};

subtest 'cosmetic %20 → + regex edge cases' => sub {
    # The collapse rule is: ONLY isolated mid-string %20. Test every edge.
    is(encoded(' '),         '%20',          'lone space (whole string) — keep as %20');
    is(encoded('  '),        '%20%20',       'two spaces — both adjacent, keep both');
    is(encoded('   '),       '%20%20%20',    'three spaces — middle is adjacent to neighbors, keep all');
    is(encoded(' foo'),      '%20foo',       'leading space — keep as %20');
    is(encoded('foo '),      'foo%20',       'trailing space — keep as %20');
    is(encoded(' foo '),     '%20foo%20',    'both ends — both stay %20');
    is(encoded('foo bar'),   'foo+bar',      'isolated mid-string → +');
    is(encoded('a b c'),     'a+b+c',        'multiple isolated → all +');
    is(encoded('foo  bar'),  'foo%20%20bar', 'adjacent pair stays %20%20');
    is(encoded('a b c d e'), 'a+b+c+d+e',    'long chain of isolated singles');
    is(encoded(' a b '),     '%20a+b%20',    'ends stay, middle swaps');
    is(encoded('  a  '),     '%20%20a%20%20','runs at both ends stay');
};

subtest 'real-world titles from reporters' => sub {
    is(encoded("Neiboku's Secret Library"),
        "Neiboku%27s+Secret+Library",
        '#4145 — Clockmaker apostrophe case');
    is(encoded('Sense & Sensibility'),
        'Sense+%26+Sensibility',
        '#4060 — JD ampersand case');
    is(encoded('Star Trek #9: Triangle'),
        'Star+Trek+%239%3A+Triangle',
        '#4132 — JD/in10se hash case');
    is(encoded('Writeups+plusses, a lesson in love'),
        'Writeups%2Bplusses%2C+a+lesson+in+love',
        'literal plus + comma');
    is(encoded('Message Inbox'),
        'Message+Inbox',
        '#4143 — Messages.js inbox link');
    is(encoded('I was raised on red pepper and blood.  I am so hot if you strike me I will light like a match.'),
        'I+was+raised+on+red+pepper+and+blood.%20%20I+am+so+hot+if+you+strike+me+I+will+light+like+a+match.',
        '#3418 — multi-space title preserves the double space');
};

subtest 'UTF-8 multibyte handling' => sub {
    is(encoded('block █'),     'block+%E2%96%88',   '3-byte BMP char');
    is(encoded('café'),        'caf%C3%A9',         '2-byte Latin extended');
    is(encoded('日本語'),       '%E6%97%A5%E6%9C%AC%E8%AA%9E', 'full CJK');
    is(encoded('emoji 🐕'),    'emoji+%F0%9F%90%95','4-byte supplementary plane');
};

subtest 'defensive — degenerate inputs' => sub {
    is(encoded(undef),   '',  'undef → empty string, no warning');
    is(encoded(''),      '',  'empty string → empty string');
    is(encoded('0'),     '0', 'string "0" survives (truthiness gotcha)');
};

#############################################################################
# Section 2 — Negative: no double-encoding can sneak back in
#
# A signature of double-encoding is %25XX in the output. If any test case
# ever produces that, the encoder regressed to its old behavior.
#############################################################################
subtest 'no double-encoding in output for any tested title' => sub {
    my @torture = (
        "Neiboku's Secret Library", 'Sense & Sensibility', 'C++',
        'Star Trek #9: Triangle', '50% off', 'A+B & C',
        "She said 'hi' & left", '&&&', "''", '%%%',
        'Tag <em>bold</em>', 'Question?', 'path/to/something',
        'a@b.com', 'list; item', 'key=value',
    );
    for my $t (@torture) {
        unlike(encoded($t), qr/%25[0-9A-Fa-f]{2}/,
            "no %25XX in output for: $t");
    }
};

#############################################################################
# Section 3 — Round-trip integrity
#
# THIS is the load-bearing test. rewriteCleanEscape feeds the URL that
# Everything::HTML::_recover_route_params_from_request_uri then parses
# server-side. The two MUST be inverses for every reachable title.
#############################################################################

# Stand-in CGI to capture param() writes. The helper only calls $q->param
# with two args (set form); this is intentionally minimal.
package FakeCGI;
sub new   { return bless { _p => {} }, shift }
sub param {
    my ($self, $name, $value) = @_;
    if (@_ >= 3) { $self->{_p}{$name} = $value; return $value; }
    return $self->{_p}{$name};
}
sub all   { return $_[0]->{_p} }
package main;

sub roundtrip_through_route {
    my ($route_prefix, $title, $param_name) = @_;
    $param_name //= 'node';
    my $uri = $route_prefix . $APP->rewriteCleanEscape($title);
    local $ENV{REQUEST_URI} = $uri;
    my $q = FakeCGI->new;
    Everything::HTML::_recover_route_params_from_request_uri($q);
    return $q->all->{$param_name};
}

# The comprehensive title corpus. If we round-trip cleanly here, the
# encoder + helper pair is correct.
my @corpus = (
    # Plain
    'foo', 'hello world', 'CamelCase',

    # Reserved characters in isolation
    "'", '&', '+', '#', '?', '/', '@', ';', '=', '%', '"', '<', '>',
    ',', ':',

    # Reserved characters in titles
    "Neiboku's Secret Library",
    'Sense & Sensibility',
    'C++',
    'C++ is fun',
    'Star Trek #9: Triangle',
    'AT&T',
    'rock & roll',
    '50% off',
    "She said 'hi' to me",
    'a/b path',
    'user@host',
    'list; item',
    'key=value',
    'q? a!',
    'tags <em>bold</em> here',
    'quote "yes" end',
    'comma, separated, values',

    # Cosmetic %20→+ regex edge cases — every transition matters
    ' leading',
    'trailing ',
    ' both ',
    'mid space',
    'two  spaces',
    'three   spaces',
    'one two three',
    'one  two  three',
    'one two  three',  # mixed isolated + adjacent
    ' one two ',       # leading + trailing + mid
    '  a  b  ',        # adjacent at ends and mid
    ' a b c d e ',     # many alternating

    # + adjacency with space
    '+ +',
    '+ ',
    ' +',
    '++',
    '+++',
    'foo+ bar',
    'foo +bar',
    'foo+ +bar',
    '+abc',
    'abc+',
    'a+b+c',

    # % adjacency
    '%2520',           # literal "%2520" — was the smoking gun of double-encoding
    'foo % bar',
    '100%',
    '%abc',

    # UTF-8
    'café',
    'block █',
    'emoji 🐕',
    '日本語',
    'a 🐕 b',
    'pre-cafè-post',

    # Long-ish
    'I was raised on red pepper and blood.  I am so hot if you strike me I will light like a match.',
    'a' x 200,         # length stress

    # Numeric and edge
    '0', '1', '00',
    'plain',
);

subtest 'round-trip via /title/ route preserves every title' => sub {
    for my $t (@corpus) {
        my $rt = roundtrip_through_route('/title/', $t);
        is($rt, $t, "/title/ round-trip: ${\ (substr($t, 0, 60))}");
    }
};

subtest 'round-trip via /e2node/ route preserves every title' => sub {
    for my $t (@corpus) {
        my $rt = roundtrip_through_route('/e2node/', $t);
        is($rt, $t, "/e2node/ round-trip: ${\ (substr($t, 0, 60))}");
    }
};

subtest 'round-trip via /user/ route preserves usernames with edge chars' => sub {
    # Usernames are a narrower domain in practice (no '/' or '#' likely),
    # but the helper has to handle whatever rewriteCleanEscape emits.
    for my $t ('genericdev', 'user with space', "O'Brien", 'a+b',
               'café user', '日本ユーザー', 'a b c', ' lead', 'trail ') {
        my $rt = roundtrip_through_route('/user/', $t);
        is($rt, $t, "/user/ round-trip: $t");
    }
};

subtest 'round-trip via /node/<type>/<title> route' => sub {
    # The helper's regex for this route is more restrictive (requires the
    # first segment to be non-numeric word chars). Test it with a type
    # known to fit and a title with all the trouble characters.
    for my $t (@corpus) {
        my $uri = '/node/e2node/' . $APP->rewriteCleanEscape($t);
        local $ENV{REQUEST_URI} = $uri;
        my $q = FakeCGI->new;
        Everything::HTML::_recover_route_params_from_request_uri($q);
        is($q->all->{node}, $t, "/node/e2node/ round-trip: ${\ (substr($t, 0, 60))}");
        is($q->all->{type}, 'e2node', "/node/e2node/ type preserved");
    }
};

subtest 'round-trip via /user/<author>/writeups/<title>' => sub {
    # Two-segment route — both author and title must survive intact.
    my @pairs = (
        ['normaluser1', "Neiboku's Secret Library"],
        ['normaluser1', 'Sense & Sensibility (thing)'],
        ['user with space', 'foo bar (thing)'],
        ["O'Brien", 'a/b/c path'],
        ['normaluser2', 'multi  space  title'],
    );
    for my $pair (@pairs) {
        my ($author, $title) = @$pair;
        my $uri = '/user/' . $APP->rewriteCleanEscape($author) .
                  '/writeups/' . $APP->rewriteCleanEscape($title);
        local $ENV{REQUEST_URI} = $uri;
        my $q = FakeCGI->new;
        Everything::HTML::_recover_route_params_from_request_uri($q);
        is($q->all->{author}, $author, "writeup author preserved: $author");
        is($q->all->{node},   $title,  "writeup title preserved: $title");
        is($q->all->{type},   'writeup', "writeup type set");
    }
};

#############################################################################
# Section 4 — Specific bug regressions, named loudly
#############################################################################
subtest '#4060 ampersand round-trip' => sub {
    is(roundtrip_through_route('/title/', 'Sense & Sensibility'),
        'Sense & Sensibility', 'ampersand title survives URL pipeline');
};

subtest '#4143 + as space round-trip' => sub {
    is(roundtrip_through_route('/title/', 'Message Inbox'),
        'Message Inbox', '"Message Inbox" round-trips through legacy + form');
};

subtest '#4145 apostrophe round-trip (Clockmaker)' => sub {
    is(roundtrip_through_route('/title/', "Neiboku's Secret Library"),
        "Neiboku's Secret Library",
        "apostrophe title doesn't loop through Findings anymore");
};

subtest '#3418 multi-space round-trip' => sub {
    my $t = 'I was raised on red pepper and blood.  I am so hot if you strike me I will light like a match.';
    is(roundtrip_through_route('/title/', $t), $t,
        'multi-space title survives — preserves both spaces');
};

#############################################################################
# Section 5 — Anti-double-encoding cross-check
#
# For every title in the corpus, the URL produced by rewriteCleanEscape
# must NOT decode to "the title with literal %XX in it" — that's the
# fingerprint of the double-encoding regression that caused #4145.
#############################################################################
subtest 'no title decodes to literal %XX (the #4145 fingerprint)' => sub {
    for my $t (@corpus) {
        my $rt = roundtrip_through_route('/title/', $t);
        unlike($rt, qr/%[0-9A-Fa-f]{2}/,
            "round-trip output has no literal %XX for: ${\ (substr($t, 0, 60))}")
            if $t !~ /%/;    # if the title itself contains %, the test is meaningless
    }
};

done_testing;

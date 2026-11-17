#!/usr/bin/perl -w
# Writeup meta descriptions (what search engines show as a page's excerpt; #3893).
#
# Everything::Node::writeup::metadescription returns plain, entity-decoded text, and the
# page head escapes it exactly once. The cases are real patterns from production writeups.

use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::HTMLShell;
binmode( Test::More->builder->$_, ':encoding(UTF-8)' ) for qw(output failure_output todo_output);

initEverything('development-docker');

my $wu_type = $DB->sqlSelect( 'node_id', 'node', "title='writeup' AND type_nodetype=1" );
my $base_id = $DB->sqlSelect( 'node_id', 'node', "type_nodetype=$wu_type ORDER BY node_id LIMIT 1" );
my $base    = $APP->node_by_id($base_id);
ok( $base, 'a writeup to model on' );

# A writeup like the dev one, with the given doctext.
sub wu { my ($doctext) = @_; return Everything::Node::writeup->new( { %{ $base->NODEDATA }, doctext => $doctext } ) }
sub desc { return wu(shift)->metadescription }

my @cases = (
    [ 'named and numeric entities (Koala pad)',
      'The Koala pad was a small &quot;touch tablet&quot; for the Apple &#93;&#91; series of computers.',
      'The Koala pad was a small "touch tablet" for the Apple ][ series of computers.' ],
    [ 'typographic entities, decimal and hex',
      '<p>&ldquo;Quoted&rdquo; &mdash; caf&eacute;, it&#8217;s here &#x2014; done&hellip;</p>',
      "\x{201C}Quoted\x{201D} \x{2014} caf\x{E9}, it\x{2019}s here \x{2014} done\x{2026}" ],
    [ 'Windows-1252 numbers, with and without the semicolon (Too Much Joy)',
      'Some anecdotes: &#149 The band fed hamburger to a dog. &#149; Three members',
      "Some anecdotes: \x{2022} The band fed hamburger to a dog. \x{2022} Three members" ],
    [ 'paragraphs and line breaks keep a space between them',
      '<p>Daddy?</p><p>Yeah [Princess].</p>Line one<br>line two',
      'Daddy? Yeah Princess. Line one line two' ],
    [ 'leading no-break spaces and empty paragraphs',
      '<p>&nbsp;</p><p><br>&nbsp; &nbsp;</p><p>She was awkward</p>',
      'She was awkward' ],
    [ 'a tab entity (The Jungle)',
      'The Jungle: A Historical Perspective &#9;Upton Sinclair',
      'The Jungle: A Historical Perspective Upton Sinclair' ],
    [ 'escaped markup in the text stays text',
      'Use &lt;b&gt; for bold &amp; &lt;i&gt; for italics.',
      'Use <b> for bold & <i> for italics.' ],
    [ 'pipelinks keep their display text',
      'See [Upton Sinclair|the author] and [The Jungle].',
      'See the author and The Jungle.' ],
);
for my $c (@cases) {
    my ( $name, $doctext, $want ) = @$c;
    is( desc($doctext), $want, $name );
}

subtest 'long text is cut at a word boundary' => sub {
    my $d = desc( '<p>' . join( ' ', ('word&mdash;word') x 40 ) . '</p>' );
    cmp_ok( length($d), '<=', 160, 'at most 160 characters' );
    like( $d, qr/\.\.\.$/, 'ends with an ellipsis' );
    unlike( $d, qr/&/, 'no entity fragments' );
};

subtest 'empty text falls back to the site description' => sub {
    like( desc('<p>&nbsp;</p>'), qr/^Everything2 is a community/, 'site default' );
};

subtest 'the page head escapes it exactly once' => sub {
    my $node = wu('The small &quot;touch tablet&quot; for the Apple &#93;&#91; &ndash; caf&eacute;');
    my $shell = Everything::HTMLShell->new(
        node => $node, REQUEST => bless( {}, 'GuestRequest' ), e2_json => '{}', basesheet => '/b.css', zensheet => '',
        printsheet => '/p.css', canonical_url => 'https://everything2.com/x', react_bundle => '/r.js',
        favicon => '/f.ico', metadescription => $node->metadescription, body_class => 'writeup',
        pagetitle => 'x', friendly_pagetype => 'writeup',
    );
    my $head = $shell->_render_head;
    my ($content) = $head =~ m{<meta name="description" content="([^"]*)">};
    ok( defined $content, 'meta description rendered' );
    like( $content, qr/&quot;touch tablet&quot;/, 'quotes escaped once' );
    unlike( $content, qr/&amp;(?:quot|amp|#\d)/, 'never escaped twice' );
    my $shown = HTML::Entities::decode_entities($content);    # what a browser or search engine shows
    is( $shown, "The small \"touch tablet\" for the Apple ][ \x{2013} caf\x{E9}", 'reads correctly once decoded' );
};

done_testing();

package GuestRequest;
sub is_guest { return 1 }


#!/usr/bin/perl -w

# Coverage for the Atom + Podcast feeds. These are the surviving XML feed
# surfaces (real subscribers per ALB logs) and they exercise the htmlcode path
# we deliberately KEEP while retiring xmltrue/formxml:
#   *_atom_feed -> htmlcode('userAtomFeed') / htmlcode('atomiseNode') -> show_content
# Guards against the htmlcode burndown accidentally cutting that path. #4300

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Page::new_writeups_atom_feed;
use Everything::Page::cool_archive_atom_feed;
use Everything::Page::podcast_rss_feed;
use Everything::Controller::debatecomment;
use MockRequest;
use TestSeed;
use XML::Parser;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');
my $DB   = $Everything::DB;
my $APP  = $Everything::APP;
END { TestSeed::cleanup($DB) if $DB; }
my $root = $DB->getNode('root', 'user');

sub feed_req {
    my (%qp) = @_;
    return MockRequest->new(
        node_id => $root->{node_id}, nodedata => $root, is_guest_flag => 0,
        query_params => { %qp },
    );
}

# --- New Writeups Atom Feed: main path -> filtered_newwriteups + atomiseNode ---
{
    my $page = Everything::Page::new_writeups_atom_feed->new();
    my $r = eval { $page->display(feed_req()) };
    ok($r, 'new_writeups_atom_feed display did not die') or diag($@);
    is($r->[0], $page->HTTP_OK, 'new_writeups: HTTP_OK');
    is($r->[2]{type}, 'application/atom+xml', 'new_writeups: atom mimetype');
    like($r->[1], qr/<feed/, 'new_writeups: has <feed> root');
}

# --- foruser path -> htmlcode('userAtomFeed') ---
{
    my $page = Everything::Page::new_writeups_atom_feed->new();
    my $r = eval { $page->display(feed_req(foruser => 'root')) };
    ok($r, 'new_writeups foruser feed did not die') or diag($@);
    is($r->[0], $page->HTTP_OK, 'new_writeups foruser: HTTP_OK');
    is($r->[2]{type}, 'application/atom+xml', 'new_writeups foruser: atom mimetype');
}

# --- Cool Archive Atom Feed: default path -> atomiseNode over cooled writeups ---
{
    my $page = Everything::Page::cool_archive_atom_feed->new();
    my $r = eval { $page->display(feed_req()) };
    ok($r, 'cool_archive_atom_feed display did not die') or diag($@);
    is($r->[0], $page->HTTP_OK, 'cool_archive: HTTP_OK');
    is($r->[2]{type}, 'application/atom+xml', 'cool_archive: atom mimetype');
    like($r->[1], qr/<feed/, 'cool_archive: has <feed> root');
}

# --- Podcast RSS Feed ---
{
    my $page = Everything::Page::podcast_rss_feed->new();
    my $r = eval { $page->display(feed_req()) };
    ok($r, 'podcast_rss_feed display did not die') or diag($@);
    is($r->[0], $page->HTTP_OK, 'podcast: HTTP_OK');
    is($r->[2]{type}, 'application/rss+xml', 'podcast: rss mimetype');
    like($r->[1], qr/<rss/, 'podcast: has <rss> root');
    # <item> children must be real XML elements, not HTML-escaped text. The old
    # code concatenated $XG->title(...) . $XG->link(...) with '.', stringifying
    # them before $XG->item() so item() escaped the whole thing to &lt;title&gt;.
    unlike($r->[1], qr/&lt;title&gt;/, 'podcast item children are real XML, not escaped');
}

# --- Every feed is well-formed XML, whatever the request or stored names hold ---
# Parse the whole document (XML::Parser dies on anything malformed) and return a
# lookup of the text inside each named element, so callers can check that values
# come back as the same text rather than as markup.
sub parse_feed {
    my ($xml, $name) = @_;
    my %text;
    my @open;
    my $ok = eval {
        XML::Parser->new(Handlers => {
            Start => sub { push @open, [ $_[1], '' ] },
            Char  => sub { $open[-1][1] .= $_[1] if @open },
            End   => sub { my $e = pop @open; push @{ $text{ $e->[0] } }, $e->[1] },
        })->parse($xml);
        1;
    };
    ok($ok, "$name parses as XML") or diag("$@\n$xml");
    return \%text;
}

{
    my $odd = q{Q&A <i>"quoted"</i> 'feeds' & <more>};

    # A name that matches no user, echoed back in the Cool Archive feed
    my $page = Everything::Page::cool_archive_atom_feed->new();
    my $r = $page->display(feed_req(cooluser => $odd, useraction => 'cooled'));
    my $t = parse_feed($r->[1], 'cool archive feed for an unknown user');
    unlike($r->[1], qr/<i>/, 'the unknown name is not echoed as markup');

    # An author whose stored name has markup characters, with one writeup
    my $author = TestSeed::make_user($DB, $APP, label => 'feedname', title => "$odd $$");
    my $ts     = time();
    my $e2node_id = $DB->insertNode("Feed Target $ts", 'e2node', $root, { title => "Feed Target $ts" });
    my $wu_id     = $DB->insertNode("Feed Target $ts (idea)", 'writeup', $author, {
        parent_e2node      => $e2node_id,
        doctext            => 'A plain entry.',
        wrtype_writeuptype => $DB->getNode('idea', 'writeuptype')->{node_id},
    });
    $DB->sqlUpdate('writeup', { publishtime => '2021-05-05 12:00:00' }, "writeup_id=$wu_id");

    my $user_page = Everything::Page::new_writeups_atom_feed->new();
    my $ur = $user_page->display(feed_req(foruser => $author->{title}));
    my $ut = parse_feed($ur->[1], "an author's own feed");
    is($ut->{title}[0], "$author->{title}'s New Writeups", 'feed title holds the name as text');
    is($ut->{name}[0], $author->{title}, 'entry author holds the name as text');

    local $ENV{HTTP_HOST} = 'everything2.com"';
    parse_feed('<feed>' . $APP->atomise_node($wu_id) . '</feed>', 'an entry built under an odd Host header');

    # Discussion feed entries
    my $controller = Everything::Controller::debatecomment->new();
    my $entry = $controller->_build_atom_entry(
        { node_id => $wu_id, author_user => $author->{node_id}, title => $odd,
          doctext => 'A reply.', createtime => '2021-05-05 12:00:00' },
        'https://everything2.com"');
    my $dt = parse_feed("<feed>$entry</feed>", 'a discussion feed entry');
    is($dt->{name}[0], $author->{title}, 'discussion entry author holds the name as text');
    is($dt->{title}[0], $odd, 'discussion entry title holds the text');

    $DB->nukeNode($DB->getNodeById($wu_id, 'force'), -1, 1)     if $DB->getNodeById($wu_id, 'force');
    $DB->nukeNode($DB->getNodeById($e2node_id, 'force'), -1, 1) if $DB->getNodeById($e2node_id, 'force');
}

done_testing();

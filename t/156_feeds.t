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
use MockRequest;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');
my $DB   = $Everything::DB;
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
}

done_testing();

#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::PageMetadata;

initEverything('development-docker');

ok( $DB,  'Database connection established' );
ok( $APP, 'Application object created' );

# Find one blessed node of a given type (robust to reseeds -- no hardcoded ids).
sub first_node_of {
    my ($type) = @_;
    my $type_id = $DB->sqlSelect( 'node_id', 'node',
        "title=" . $DB->getDatabaseHandle->quote($type) . " AND type_nodetype=1" );
    return unless $type_id;
    my $node_id = $DB->sqlSelect( 'node_id', 'node', "type_nodetype=$type_id ORDER BY node_id LIMIT 1" );
    return unless $node_id;
    return $APP->node_by_id($node_id);
}

# Build a producer the way the controller does (canonical from CONF + node).
sub meta_for {
    my ($node) = @_;
    my $canonical = "https://" . $Everything::CONF->canonical_web_server . $node->canonical_url;
    return Everything::PageMetadata->new(
        node            => $node,
        canonical_url   => $canonical,
        pagetitle       => $node->title,
        metadescription => $node->metadescription,
    );
}

#############################################################################
# as_hashref shape -- the contract the React app reads
#############################################################################

subtest 'as_hashref carries the full head contract' => sub {
    my $node = first_node_of('e2node') || first_node_of('superdoc');
    plan skip_all => 'no e2node/superdoc in dev DB' unless $node;

    my $m = meta_for($node)->as_hashref;

    ok( defined $m->{title} && length $m->{title}, 'title present' );
    like( $m->{canonical}, qr{^https://}, 'canonical is an absolute URL' );
    ok( defined $m->{description} && length $m->{description}, 'description present' );
    is( $m->{robots}, 'index,follow', 'robots defaults to index,follow' );

    is( ref $m->{og},      'HASH', 'og block is a hash' );
    is( ref $m->{twitter}, 'HASH', 'twitter block is a hash' );
    is( $m->{og}{site_name}, 'Everything2', 'og:site_name' );
    is( $m->{twitter}{card}, 'summary',     'twitter:card' );

    is( ref $m->{jsonLd},          'HASH',  'jsonLd is a hash' );
    is( $m->{jsonLd}{'@context'},  'https://schema.org', 'jsonLd @context' );
    is( ref $m->{jsonLd}{'@graph'}, 'ARRAY', 'jsonLd @graph is an array' );

    # WebSite + WebPage are always present.
    my %types = map { $_->{'@type'} => 1 } @{ $m->{jsonLd}{'@graph'} };
    ok( $types{WebSite}, '@graph has a WebSite node' );
    ok( $types{WebPage}, '@graph has a WebPage node' );
};

#############################################################################
# robots override
#############################################################################

subtest 'robots override flows through' => sub {
    my $node = first_node_of('superdoc') || first_node_of('e2node');
    plan skip_all => 'no node available' unless $node;

    my $canonical = "https://" . $Everything::CONF->canonical_web_server . $node->canonical_url;
    my $m = Everything::PageMetadata->new(
        node            => $node,
        canonical_url   => $canonical,
        pagetitle       => $node->title,
        metadescription => $node->metadescription,
        robots_index    => 'noindex',
        robots_follow   => 'nofollow',
    )->as_hashref;

    is( $m->{robots}, 'noindex,nofollow', 'robots reflects the override' );
};

#############################################################################
# og:type -- article for writeup/e2node, website otherwise
#############################################################################

subtest 'og:type keys off the node type' => sub {
    my $wu = first_node_of('writeup');
    if ($wu) {
        my $og = meta_for($wu)->og;
        is( $og->{type}, 'article', 'writeup -> og:type article' );
    }
    else {
        ok( 1, 'no writeup in dev DB (skipped article check)' );
    }

    my $sd = first_node_of('superdoc');
    if ($sd) {
        my $og = meta_for($sd)->og;
        is( $og->{type}, 'website', 'superdoc -> og:type website' );
    }
    else {
        ok( 1, 'no superdoc in dev DB (skipped website check)' );
    }
};

#############################################################################
# JSON-LD type-specific schemas
#############################################################################

subtest 'writeup JSON-LD carries Article + BreadcrumbList' => sub {
    my $wu = first_node_of('writeup');
    plan skip_all => 'no writeup in dev DB' unless $wu;

    my $graph = meta_for($wu)->json_ld->{'@graph'};
    my %types = map { $_->{'@type'} => $_ } @$graph;
    ok( $types{Article},        'has an Article node' );
    ok( $types{BreadcrumbList}, 'has a BreadcrumbList node' );
    is( $types{Article}{publisher}{name}, 'Everything2', 'Article publisher is Everything2' );
};

subtest 'category JSON-LD carries a CollectionPage' => sub {
    my $cat = first_node_of('category');
    plan skip_all => 'no category in dev DB' unless $cat;

    my $graph = meta_for($cat)->json_ld->{'@graph'};
    my ($collection) = grep { $_->{'@type'} eq 'CollectionPage' } @$graph;
    ok( $collection, 'has a CollectionPage node' );
    is( $collection->{mainEntity}{'@type'}, 'ItemList', 'CollectionPage mainEntity is an ItemList' );
};

done_testing();

=head1 NAME

t/143_page_metadata.t - Everything::PageMetadata producer (the e2 `meta` key + JSON-LD)

=cut

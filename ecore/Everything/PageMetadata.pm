package Everything::PageMetadata;

use Moose;
with 'Everything::Globals';

use HTML::Entities qw(decode_entities);

=head1 Everything::PageMetadata

The page's head metadata as DATA, produced once and consumed two ways:

  * Everything::HTMLShell renders it into the server <head> (<title>, canonical,
    robots, Open Graph / Twitter meta, and the schema.org JSON-LD @graph).
  * Everything::Controller::layout surfaces it as the e2 blob's `meta` key, so the
    React app can set <head> on client-side navigation (where there is no server
    render). Delivered via /api/pagestate alongside the rest of the page payload.

Before this, the metadata logic lived only inside HTMLShell's HTML emitters, so the
React app had no title / canonical / JSON-LD to set after the first paint. This is
the single source; HTMLShell renders FROM it rather than computing its own.

Inputs mirror the HTMLShell attributes the controller already builds (canonical_url,
pagetitle, metadescription, robots) so the server head stays byte-stable. Values are
RAW (entity-decoded) text -- the consumer encodes (HTMLShell HTML-encodes, React sets
.textContent / attributes). Do not pre-encode here.

=cut

has 'node'            => ( is => 'ro', required => 1 );
has 'canonical_url'   => ( is => 'ro', required => 1 );
has 'pagetitle'       => ( is => 'ro', required => 1 );
has 'metadescription' => ( is => 'ro', required => 1 );
has 'robots_index'    => ( is => 'ro', default  => 'index' );
has 'robots_follow'   => ( is => 'ro', default  => 'follow' );

# 'website' for everything else; 'article' for the two long-form content types. Open
# Graph type and the article:published_time emission both key off this.
sub _friendly_pagetype {
    my ($self) = @_;
    return $self->node->type->title;
}

sub _is_article {
    my ($self) = @_;
    my $t = $self->_friendly_pagetype;
    return ( $t eq 'writeup' || $t eq 'e2node' ) ? 1 : 0;
}

# Open Graph block. published_time only for article-type nodes that carry one.
sub og {
    my ($self) = @_;
    my $og = {
        type        => $self->_is_article ? 'article' : 'website',
        url         => $self->canonical_url,
        title       => $self->pagetitle,
        description => $self->metadescription,
        site_name   => 'Everything2',
    };
    if ( $self->_is_article && $self->node->can('publishtime') && $self->node->publishtime ) {
        $og->{published_time} = $self->node->publishtime;
    }
    return $og;
}

sub twitter {
    my ($self) = @_;
    return {
        card        => 'summary',
        title       => $self->pagetitle,
        description => $self->metadescription,
    };
}

# The schema.org @graph: WebSite (always) + WebPage (always) + a BreadcrumbList and an
# Article/CollectionPage for the long-form/collection types. Returns the data structure;
# HTMLShell encode_json's it into a <script type="application/ld+json">, and it rides
# along in the e2 `meta` key for the React app to inject the same way.
sub json_ld {
    my ($self) = @_;

    my $node            = $self->node;
    my $ntypet          = $node->type->title;
    my $canonical_url   = $self->canonical_url;
    my $pagetitle       = $self->pagetitle;
    my $metadescription = $self->metadescription;

    my @json_ld_items;

    # WebSite schema (always include on all pages)
    push @json_ld_items, {
        '@type'       => 'WebSite',
        '@id'         => 'https://everything2.com/#website',
        'url'         => 'https://everything2.com/',
        'name'        => 'Everything2',
        'description' => 'Everything2 is a community for fiction, nonfiction, poetry, reviews, and more.',
        'potentialAction' => {
            '@type'  => 'SearchAction',
            'target' => {
                '@type'       => 'EntryPoint',
                'urlTemplate' => 'https://everything2.com/title/{search_term_string}'
            },
            'query-input' => 'required name=search_term_string'
        }
    };

    # WebPage schema (for all pages)
    my $webpage_schema = {
        '@type'      => 'WebPage',
        '@id'        => $canonical_url . '#webpage',
        'url'        => $canonical_url,
        'name'       => $pagetitle,
        'description' => $metadescription,
        'isPartOf'   => { '@id' => 'https://everything2.com/#website' },
        'inLanguage' => 'en-US'
    };

    # Add breadcrumbs for writeups and e2nodes
    if ( $ntypet eq 'writeup' || $ntypet eq 'e2node' ) {
        my @breadcrumb_items = (
            {
                '@type'    => 'ListItem',
                'position' => 1,
                'name'     => 'Home',
                'item'     => 'https://everything2.com/'
            }
        );

        if ( $ntypet eq 'writeup' ) {
            my $parent = $node->parent;
            if ( $parent && !UNIVERSAL::isa( $parent, "Everything::Node::null" ) ) {
                my $parent_url = 'https://everything2.com/title/' . $self->APP->rewriteCleanEscape( $parent->title );
                push @breadcrumb_items, {
                    '@type'    => 'ListItem',
                    'position' => 2,
                    'name'     => decode_entities( $parent->title ),
                    'item'     => $parent_url
                };
                push @breadcrumb_items, {
                    '@type'    => 'ListItem',
                    'position' => 3,
                    'name'     => $pagetitle
                };
            }
        }
        else {
            push @breadcrumb_items, {
                '@type'    => 'ListItem',
                'position' => 2,
                'name'     => decode_entities( $node->title )
            };
        }

        push @json_ld_items, {
            '@type'           => 'BreadcrumbList',
            'itemListElement' => \@breadcrumb_items
        };
    }

    # Article schema for writeups
    if ( $ntypet eq 'writeup' ) {
        my $author      = $node->author;
        my $author_name = $author ? $author->title : 'Anonymous';
        my $author_url  = $author ? 'https://everything2.com/user/' . $self->APP->rewriteCleanEscape($author_name) : undef;

        my $article_schema = {
            '@type'      => 'Article',
            '@id'        => $canonical_url . '#article',
            'headline'   => $pagetitle,
            'description' => $metadescription,
            'url'        => $canonical_url,
            'isPartOf'   => { '@id' => $canonical_url . '#webpage' },
            'inLanguage' => 'en-US',
            'author'     => {
                '@type' => 'Person',
                'name'  => $author_name,
                ( $author_url ? ( 'url' => $author_url ) : () )
            },
            'publisher' => {
                '@type' => 'Organization',
                'name'  => 'Everything2',
                'url'   => 'https://everything2.com/'
            }
        };

        # Add dates if available
        if ( $node->can('createtime') && $node->createtime ) {
            $article_schema->{datePublished} = $node->createtime;
        }
        if ( $node->can('updated') && $node->updated ) {
            $article_schema->{dateModified} = $node->updated;
        }

        push @json_ld_items, $article_schema;
        $webpage_schema->{mainEntity} = { '@id' => $canonical_url . '#article' };
    }

    # CollectionPage schema for categories
    if ( $ntypet eq 'category' ) {
        my $author      = $node->author;
        my $author_name = $author ? $author->title : 'Everything2';
        my $author_url  = $author ? 'https://everything2.com/user/' . $self->APP->rewriteCleanEscape($author_name) : undef;

        # Get member count from category
        my $category_linktype = $self->DB->getNode( 'category', 'linktype' );
        my $member_count      = 0;
        if ($category_linktype) {
            $member_count = $self->DB->sqlSelect(
                'COUNT(*)',
                'links',
                'from_node = ' . $node->node_id . ' AND linktype = ' . $category_linktype->{node_id}
            ) || 0;
        }

        my $collection_schema = {
            '@type'      => 'CollectionPage',
            '@id'        => $canonical_url . '#collection',
            'name'       => $node->title,
            'description' => $metadescription,
            'url'        => $canonical_url,
            'isPartOf'   => { '@id' => $canonical_url . '#webpage' },
            'inLanguage' => 'en-US',
            'mainEntity' => {
                '@type'         => 'ItemList',
                'numberOfItems' => $member_count,
                'itemListOrder' => 'https://schema.org/ItemListOrderAscending'
            }
        };

        # Add author/maintainer
        if ($author_url) {
            $collection_schema->{maintainer} = {
                '@type' => 'Person',
                'name'  => $author_name,
                'url'   => $author_url
            };
        }

        # Add dates if available
        if ( $node->can('createtime') && $node->createtime ) {
            $collection_schema->{dateCreated} = $node->createtime;
        }

        push @json_ld_items, $collection_schema;
        $webpage_schema->{mainEntity} = { '@id' => $canonical_url . '#collection' };
    }

    push @json_ld_items, $webpage_schema;

    return {
        '@context' => 'https://schema.org',
        '@graph'   => \@json_ld_items
    };
}

# The whole metadata block as a plain hashref -- this is the e2 `meta` key the React app
# reads to set <head> on client navigation. Strings are raw/decoded; the consumer encodes.
sub as_hashref {
    my ($self) = @_;
    return {
        title       => $self->pagetitle,
        canonical   => $self->canonical_url,
        description => $self->metadescription,
        robots      => $self->robots_index . ',' . $self->robots_follow,
        og          => $self->og,
        twitter     => $self->twitter,
        jsonLd      => $self->json_ld,
    };
}

__PACKAGE__->meta->make_immutable;

1;

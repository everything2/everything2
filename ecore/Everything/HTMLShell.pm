package Everything::HTMLShell;

use Moose;
with 'Everything::Globals';

use JSON::MaybeXS;
use HTML::Entities qw(encode_entities);

# Core page data
has 'node' => (is => 'ro', required => 1);
has 'REQUEST' => (is => 'ro', required => 1);
has 'e2_json' => (is => 'ro', required => 1);

# Stylesheets
has 'basesheet' => (is => 'ro', required => 1);
has 'zensheet' => (is => 'ro', required => 1);
has 'printsheet' => (is => 'ro', required => 1);
has 'customstyle' => (is => 'ro', default => '');

# URLs and assets
has 'canonical_url' => (is => 'ro', required => 1);
has 'react_bundle' => (is => 'ro', required => 1);
has 'favicon' => (is => 'ro', required => 1);

# Optional base href (for guest users)
has 'basehref' => (is => 'ro', default => '');

# SEO meta
has 'metadescription' => (is => 'ro', required => 1);
has 'meta_robots_index' => (is => 'ro', default => 'index');
has 'meta_robots_follow' => (is => 'ro', default => 'follow');

# Atom feed
has 'atom_feed_title' => (is => 'ro', default => 'Everything2 New Writeups');
has 'atom_feed_url' => (is => 'ro', default => '/node/ticker/New+Writeups+Atom+Feed');

# Body class
has 'body_class' => (is => 'ro', required => 1);

# Computed/lazy attributes
has 'pagetitle' => (is => 'ro', lazy => 1, builder => '_build_pagetitle');
has 'friendly_pagetype' => (is => 'ro', lazy => 1, builder => '_build_friendly_pagetype');

sub _build_pagetitle {
    my ($self) = @_;
    return $self->node->title;
}

sub _build_friendly_pagetype {
    my ($self) = @_;
    return $self->node->type->title;
}

sub render {
    my ($self) = @_;

    my $html = $self->_render_doctype;
    $html .= $self->_render_head;
    $html .= $self->_render_body;
    $html .= "</html>\n";

    return $html;
}

sub _render_doctype {
    return qq{<!DOCTYPE html>\n<html lang="en">\n};
}

sub _render_head {
    my ($self) = @_;

    # Only encode user-controllable values (node titles can contain special chars)
    my $pagetitle = encode_entities($self->pagetitle);
    my $metadescription = encode_entities($self->metadescription);
    my $canonical_url = $self->canonical_url;
    my $friendly_pagetype = $self->friendly_pagetype;

    my $html = "<head>\n";
    $html .= qq{<meta charset="utf-8">\n};
    $html .= qq{<meta http-equiv="X-UA-Compatible" content="IE=Edge" />\n};
    $html .= qq{<title>$pagetitle</title>\n};

    # Stylesheets (URLs are system-controlled)
    $html .= qq{<link rel="stylesheet" id="basesheet" type="text/css" href="} . $self->basesheet . qq{" media="all">\n};
    $html .= qq{<link rel="stylesheet" id="zensheet" type="text/css" href="} . $self->zensheet . qq{" media="screen,tv,projection">\n};
    $html .= qq{<link rel="stylesheet" id="printsheet" type="text/css" href="} . $self->printsheet . qq{" media="print">\n};

    # Custom style
    if ($self->customstyle) {
        $html .= qq{<style type="text/css">} . $self->customstyle . qq{</style>\n};
    }

    # Base href for guests
    if ($self->basehref) {
        $html .= qq{<base href="} . $self->basehref . qq{">\n};
    }

    # Canonical and meta
    $html .= qq{<link rel="canonical" href="$canonical_url">\n};
    $html .= qq{<meta name="robots" content="} . $self->meta_robots_index . "," . $self->meta_robots_follow . qq{">\n};
    $html .= qq{<meta name="description" content="$metadescription">\n};

    # Open Graph
    my $og_type = ($friendly_pagetype eq 'writeup' || $friendly_pagetype eq 'e2node') ? 'article' : 'website';
    $html .= qq{<!-- Open Graph / Facebook -->\n};
    $html .= qq{<meta property="og:type" content="$og_type">\n};
    $html .= qq{<meta property="og:url" content="$canonical_url">\n};
    $html .= qq{<meta property="og:title" content="$pagetitle">\n};
    $html .= qq{<meta property="og:description" content="$metadescription">\n};
    $html .= qq{<meta property="og:site_name" content="Everything2">\n};

    # Article published time for writeups/e2nodes
    if (($friendly_pagetype eq 'writeup' || $friendly_pagetype eq 'e2node')
        && $self->node->can('publishtime') && $self->node->publishtime) {
        $html .= qq{<meta property="article:published_time" content="} . $self->node->publishtime . qq{">\n};
    }

    # Twitter
    $html .= qq{<!-- Twitter -->\n};
    $html .= qq{<meta name="twitter:card" content="summary">\n};
    $html .= qq{<meta name="twitter:title" content="$pagetitle">\n};
    $html .= qq{<meta name="twitter:description" content="$metadescription">\n};

    # Favicon (URL is system-controlled)
    $html .= qq{<link rel="icon" href="} . $self->favicon . qq{" type="image/vnd.microsoft.icon">\n};
    $html .= qq{<!--[if lt IE 8]><link rel="shortcut icon" href="} . $self->favicon . qq{" type="image/x-icon"><![endif]-->\n};

    # Atom feed (system-controlled values)
    $html .= qq{<link rel="alternate" type="application/atom+xml" title="} . $self->atom_feed_title . qq{" href="} . $self->atom_feed_url . qq{">\n};

    # Viewport
    $html .= qq{<meta content="width=device-width,initial-scale=1.0,user-scalable=1" name="viewport">\n};

    # Google Analytics
    $html .= qq{<script async src="https://www.googletagmanager.com/gtag/js?id=G-2GBBBF9ZDK"></script>\n};

    # AdSense for guests only
    if ($self->REQUEST->is_guest) {
        $html .= qq{<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-0613380022572506" crossorigin="anonymous"></script>\n};
    }

    # JSON-LD structured data
    $html .= $self->_render_json_ld;

    $html .= "</head>\n";

    return $html;
}

sub _render_json_ld {
    my ($self) = @_;

    my $node = $self->node;
    my $ntypet = $node->type->title;
    my $canonical_url = $self->canonical_url;
    my $pagetitle = $self->pagetitle;
    my $metadescription = $self->metadescription;

    my @json_ld_items;

    # WebSite schema (always include on all pages)
    push @json_ld_items, {
        '@type' => 'WebSite',
        '@id' => 'https://everything2.com/#website',
        'url' => 'https://everything2.com/',
        'name' => 'Everything2',
        'description' => 'Everything2 is a community for fiction, nonfiction, poetry, reviews, and more.',
        'potentialAction' => {
            '@type' => 'SearchAction',
            'target' => {
                '@type' => 'EntryPoint',
                'urlTemplate' => 'https://everything2.com/title/{search_term_string}'
            },
            'query-input' => 'required name=search_term_string'
        }
    };

    # WebPage schema (for all pages)
    my $webpage_schema = {
        '@type' => 'WebPage',
        '@id' => $canonical_url . '#webpage',
        'url' => $canonical_url,
        'name' => $pagetitle,
        'description' => $metadescription,
        'isPartOf' => { '@id' => 'https://everything2.com/#website' },
        'inLanguage' => 'en-US'
    };

    # Add breadcrumbs for writeups and e2nodes
    if ($ntypet eq 'writeup' || $ntypet eq 'e2node') {
        my @breadcrumb_items = (
            {
                '@type' => 'ListItem',
                'position' => 1,
                'name' => 'Home',
                'item' => 'https://everything2.com/'
            }
        );

        if ($ntypet eq 'writeup') {
            my $parent = $node->parent;
            if ($parent && !UNIVERSAL::isa($parent, "Everything::Node::null")) {
                my $parent_url = 'https://everything2.com/title/' . $self->APP->rewriteCleanEscape($parent->title);
                push @breadcrumb_items, {
                    '@type' => 'ListItem',
                    'position' => 2,
                    'name' => $parent->title,
                    'item' => $parent_url
                };
                push @breadcrumb_items, {
                    '@type' => 'ListItem',
                    'position' => 3,
                    'name' => $pagetitle
                };
            }
        } else {
            push @breadcrumb_items, {
                '@type' => 'ListItem',
                'position' => 2,
                'name' => $node->title
            };
        }

        push @json_ld_items, {
            '@type' => 'BreadcrumbList',
            'itemListElement' => \@breadcrumb_items
        };
    }

    # Article schema for writeups
    if ($ntypet eq 'writeup') {
        my $author = $node->author;
        my $author_name = $author ? $author->title : 'Anonymous';
        my $author_url = $author ? 'https://everything2.com/user/' . $self->APP->rewriteCleanEscape($author_name) : undef;

        my $article_schema = {
            '@type' => 'Article',
            '@id' => $canonical_url . '#article',
            'headline' => $pagetitle,
            'description' => $metadescription,
            'url' => $canonical_url,
            'isPartOf' => { '@id' => $canonical_url . '#webpage' },
            'inLanguage' => 'en-US',
            'author' => {
                '@type' => 'Person',
                'name' => $author_name,
                ($author_url ? ('url' => $author_url) : ())
            },
            'publisher' => {
                '@type' => 'Organization',
                'name' => 'Everything2',
                'url' => 'https://everything2.com/'
            }
        };

        # Add dates if available
        if ($node->can('createtime') && $node->createtime) {
            $article_schema->{datePublished} = $node->createtime;
        }
        if ($node->can('updated') && $node->updated) {
            $article_schema->{dateModified} = $node->updated;
        }

        push @json_ld_items, $article_schema;
        $webpage_schema->{mainEntity} = { '@id' => $canonical_url . '#article' };
    }

    push @json_ld_items, $webpage_schema;

    # Combine into @graph
    my $json_ld = {
        '@context' => 'https://schema.org',
        '@graph' => \@json_ld_items
    };

    my $json_ld_str = encode_json($json_ld);
    return qq{<script type="application/ld+json">$json_ld_str</script>\n};
}

sub _render_body {
    my ($self) = @_;

    # All values are system-controlled, no encoding needed
    my $body_class = $self->body_class;
    my $e2_json = $self->e2_json;
    my $react_bundle = $self->react_bundle;

    my $html = qq{<body class="$body_class" itemscope itemtype="http://schema.org/WebPage">\n};
    $html .= qq{<!-- React renders entire page body -->\n};
    $html .= qq{<div id="e2-react-page-root"></div>\n};
    $html .= qq{<script id="nodeinfojson">e2 = $e2_json</script>\n};
    $html .= qq{<script src="$react_bundle" type="text/javascript"></script>\n};
    $html .= qq{</body>\n};

    return $html;
}

__PACKAGE__->meta->make_immutable;
1;

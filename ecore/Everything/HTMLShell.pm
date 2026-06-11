package Everything::HTMLShell;

use Moose;
with 'Everything::Globals';

use JSON::MaybeXS;
use HTML::Entities qw(encode_entities decode_entities);
use Everything::PageMetadata;

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

# The single metadata producer (og / JSON-LD / the e2 `meta` key the React app reads).
# HTMLShell renders FROM it so the server <head> and the client-set <head> never diverge.
has 'page_metadata' => (is => 'ro', lazy => 1, builder => '_build_page_metadata');

sub _build_page_metadata {
    my ($self) = @_;
    return Everything::PageMetadata->new(
        node            => $self->node,
        canonical_url   => $self->canonical_url,
        pagetitle       => $self->pagetitle,
        metadescription => $self->metadescription,
        robots_index    => $self->meta_robots_index,
        robots_follow   => $self->meta_robots_follow,
    );
}

sub _build_pagetitle {
    my ($self) = @_;
    # Decode HTML numeric/named entities stored in the title (e.g. prod node
    # 2198233 stores 美国国家安全局 as the literal string "&#32654;&#22269;…",
    # and `[NSA]` is stored as "&#91;NSA&#93;" because '[' / ']' are link
    # syntax). _render_head re-encodes for the <title> tag and meta content,
    # so the round-trip is decode-then-encode rather than letting raw
    # entities double-escape into &amp;#NNNN; visible to users.
    return decode_entities($self->node->title);
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
    # Only include zensheet if user has a non-default theme
    if ($self->zensheet) {
        $html .= qq{<link rel="stylesheet" id="zensheet" type="text/css" href="} . $self->zensheet . qq{" media="screen,tv,projection">\n};
    }
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

    # Open Graph (driven by the shared metadata producer so the client-set <head> matches)
    my $og = $self->page_metadata->og;
    $html .= qq{<!-- Open Graph / Facebook -->\n};
    $html .= qq{<meta property="og:type" content="} . $og->{type} . qq{">\n};
    $html .= qq{<meta property="og:url" content="$canonical_url">\n};
    $html .= qq{<meta property="og:title" content="$pagetitle">\n};
    $html .= qq{<meta property="og:description" content="$metadescription">\n};
    $html .= qq{<meta property="og:site_name" content="Everything2">\n};

    # Article published time for writeups/e2nodes
    if (defined $og->{published_time}) {
        $html .= qq{<meta property="article:published_time" content="} . $og->{published_time} . qq{">\n};
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

    # Preconnect hints - establish early connections to external resources
    # dns-prefetch is fallback for browsers that don't support preconnect
    $html .= qq{<!-- Preconnect to external resources for faster loading -->\n};
    $html .= qq{<link rel="preconnect" href="https://www.googletagmanager.com" crossorigin>\n};
    $html .= qq{<link rel="dns-prefetch" href="https://www.googletagmanager.com">\n};
    $html .= qq{<link rel="preconnect" href="https://www.google-analytics.com" crossorigin>\n};
    $html .= qq{<link rel="dns-prefetch" href="https://www.google-analytics.com">\n};

    # S3 assets preconnect for production (CSS/JS are loaded from S3)
    if ($self->CONF->is_production) {
        my $assets_location = $self->CONF->assets_location;
        if ($assets_location =~ m{^(https://[^/]+)}) {
            my $assets_origin = $1;
            $html .= qq{<link rel="preconnect" href="$assets_origin" crossorigin>\n};
            $html .= qq{<link rel="dns-prefetch" href="$assets_origin">\n};
        }
    }

    # AdSense preconnect for guests
    if ($self->REQUEST->is_guest) {
        $html .= qq{<link rel="preconnect" href="https://pagead2.googlesyndication.com" crossorigin>\n};
        $html .= qq{<link rel="dns-prefetch" href="https://pagead2.googlesyndication.com">\n};
        $html .= qq{<link rel="preconnect" href="https://googleads.g.doubleclick.net" crossorigin>\n};
        $html .= qq{<link rel="dns-prefetch" href="https://googleads.g.doubleclick.net">\n};
        $html .= qq{<link rel="preconnect" href="https://tpc.googlesyndication.com" crossorigin>\n};
        $html .= qq{<link rel="dns-prefetch" href="https://tpc.googlesyndication.com">\n};
    }

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

    # The schema.org @graph is built by Everything::PageMetadata (the single source,
    # also surfaced to React via the e2 `meta` key). Here we only serialize + wrap it.
    my $json_ld_str = encode_json($self->page_metadata->json_ld);
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

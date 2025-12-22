<%class>
use Encode;

has 'node' => (required => 1);
has 'basesheet' => (required => 1);
has 'zensheet' => (required => 1);
has 'printsheet' => (required => 1);
has 'canonical_url' => (required => 1);

has 'customstyle';
has 'basehref';

has 'pagetitle' => (builder => '_build_pagetitle', lazy => 1);

has 'meta_robots_index' => (default => "index");
has 'meta_robots_follow' => (default => "follow");

has 'metadescription' => (required => 1);

has 'atom_feed' => (default => sub { ["Everything2 New Writeups", "/node/ticker/New+Writeups+Atom+Feed"] });

has 'body_class' => (required => 1);

has 'default_javascript' => (required => 1);
has 'nodeinfojson' => (required => 1);

has 'no_ads' => (default => 0);

has 'script_name' => (required => 1);

has 'lastnode' => (required => 1);

has 'nodelets' => (required => 1);
has 'nodeletorder' => (required => 1);

has 'friendly_pagetype' => (default => sub { my $self = shift; $self->node->type->title }, lazy => 1);

has 'favicon' => (required => 1);

sub _build_pagetitle
{
  my ($self) = @_;
  return $self->node->title;
}

</%class>

<%augment wrap>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<title><% $.pagetitle %></title>
<link rel="stylesheet" id="basesheet" type="text/css" href="<% $.basesheet %>" media="all">
<link rel="stylesheet" id="zensheet" type="text/css" href="<% $.zensheet %>" media="screen,tv,projection">
<link rel="stylesheet" id="printsheet" type="text/css" href="<% $.printsheet %>" media="print">
% if($.customstyle) {
<style type="text/css"><% $.customstyle %></style>
% }
% if($.basehref) {
<base href="<% $.basehref %>">
% }
<link rel="canonical" href="<% $.canonical_url %>">
<meta name="robots" content="<% $.meta_robots_index %>,<% $.meta_robots_follow %>">
<meta name="description" content="<% $.metadescription %>">
<!-- Open Graph / Facebook -->
<meta property="og:type" content="<% ($.friendly_pagetype eq 'writeup' || $.friendly_pagetype eq 'e2node') ? 'article' : 'website' %>">
<meta property="og:url" content="<% $.canonical_url %>">
<meta property="og:title" content="<% $.pagetitle %>">
<meta property="og:description" content="<% $.metadescription %>">
<meta property="og:site_name" content="Everything2">
% if (($.friendly_pagetype eq 'writeup' || $.friendly_pagetype eq 'e2node') && $.node->can('publishtime') && $.node->publishtime) {
<meta property="article:published_time" content="<% $.node->publishtime %>">
% }
<!-- Twitter -->
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="<% $.pagetitle %>">
<meta name="twitter:description" content="<% $.metadescription %>">
<link rel="icon" href="<% $.favicon %>" type="image/vnd.microsoft.icon">
<!--[if lt IE 8]><link rel="shortcut icon" href="<% $.favicon %>" type="image/x-icon"><![endif]-->
<link rel="alternate" type="application/atom+xml" title="<% $.atom_feed->[0] %>" href="<% $.atom_feed->[1] %>">
<meta content="width=device-width,initial-scale=1.0,user-scalable=1" name="viewport">
<script async src="https://www.googletagmanager.com/gtag/js?id=G-2GBBBF9ZDK"></script>
<%perl>
  # Generate JSON-LD structured data for SEO
  use JSON::MaybeXS;
  my $node = $.node;
  my $ntypet = $node->type->title;
  my $APP = $REQUEST->APP;

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
    '@id' => $.canonical_url . '#webpage',
    'url' => $.canonical_url,
    'name' => $.pagetitle,
    'description' => $.metadescription,
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
        my $parent_url = 'https://everything2.com/title/' . $APP->rewriteCleanEscape($parent->title);
        push @breadcrumb_items, {
          '@type' => 'ListItem',
          'position' => 2,
          'name' => $parent->title,
          'item' => $parent_url
        };
        push @breadcrumb_items, {
          '@type' => 'ListItem',
          'position' => 3,
          'name' => $.pagetitle
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
    my $author_url = $author ? 'https://everything2.com/user/' . $APP->rewriteCleanEscape($author_name) : undef;

    my $article_schema = {
      '@type' => 'Article',
      '@id' => $.canonical_url . '#article',
      'headline' => $.pagetitle,
      'description' => $.metadescription,
      'url' => $.canonical_url,
      'isPartOf' => { '@id' => $.canonical_url . '#webpage' },
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
    $webpage_schema->{mainEntity} = { '@id' => $.canonical_url . '#article' };
  }

  push @json_ld_items, $webpage_schema;

  # Combine into @graph
  my $json_ld = {
    '@context' => 'https://schema.org',
    '@graph' => \@json_ld_items
  };

  my $json_ld_str = encode_json($json_ld);
  $m->print(qq{<script type="application/ld+json">$json_ld_str</script>\n});
</%perl>
</head>
<body class="<% $.body_class %>" itemscope itemtype="http://schema.org/WebPage">
<& 'googleads', no_ads => $.no_ads &>
<div id='header'>
<%perl>
  # Show epicenterZen linkbar if user doesn't have Epicenter nodelet
  my $user = $REQUEST->user;
  my $DB = $REQUEST->DB;

  unless ($user->is_guest) {
    my $epicenter_nodelet = $DB->getNode('Epicenter', 'nodelet');
    if ($epicenter_nodelet) {
      my $epid = $epicenter_nodelet->{node_id};
      my $nodelets = $user->VARS->{nodelets} || '';

      # If user doesn't have Epicenter nodelet, show the epicenterZen linkbar
      if ($nodelets !~ /\b$epid\b/) {
        my $epicenter_html = Everything::HTML::htmlcode('epicenterZen');
        $m->print($epicenter_html) if $epicenter_html;
      }
    }
  }
</%perl>
 <& 'searchform', script_name => $.script_name, lastnode => $.lastnode &>
 <div id='e2logo'><a href="/">Everything<span id="e2logo2">2</span></a></div>
</div>
<div id='wrapper'>
 <div id='mainbody' itemprop="mainContentOfPage"><!-- google_ad_section_start -->
  <div id="pageheader">
   <h1 class="nodetitle"><% $.node->title %></h1>
   <& 'createdby', node => $.node &>
<%perl>
  # Parent link for writeups - "See all of [parent e2node]"
  my $node = $.node;
  my $ntypet = $node->type->title;
  if ($ntypet eq 'writeup') {
    my $parent = $node->parent;
    if ($parent && !UNIVERSAL::isa($parent, "Everything::Node::null")) {
      my $parent_title = $parent->title;
      my $APP = $REQUEST->APP;
      my $writeup_count = $APP->node_by_id($parent->node_id, 'light')->{group} || [];
      $writeup_count = ref($writeup_count) eq 'ARRAY' ? scalar(@$writeup_count) : 0;

      my $more_text;
      if ($writeup_count <= 1) {
        $more_text = 'no other writeups in this node';
      } elsif ($writeup_count == 2) {
        $more_text = 'there is 1 more in this node';
      } else {
        $more_text = 'there are ' . ($writeup_count - 1) . ' more in this node';
      }

      # Build a simple link to the parent e2node
      my $parent_url = "/title/" . $APP->rewriteCleanEscape($parent_title);
      my $parent_link = qq{<a href="$parent_url">See all of $parent_title</a>};
      $m->print(qq{<div class="topic" id="parentlink">$parent_link, $more_text.</div>\n});
    }
  }
</%perl>
<%perl>
  # Firmlinks for e2nodes and writeup parent e2nodes - "See also:" section
  # Reuse $node and $ntypet from previous block
  $node = $.node;
  $ntypet = $node->type->title;
  my $target_node;

  # For writeups, show firmlinks from the parent e2node
  if ($ntypet eq 'writeup') {
    my $parent = $node->parent;
    $target_node = $parent if ($parent && !UNIVERSAL::isa($parent, "Everything::Node::null"));
  }
  # For e2nodes, show their own firmlinks
  elsif ($ntypet eq 'e2node') {
    $target_node = $node;
  }

  if ($target_node && $target_node->can('firmlinks')) {
    my $firmlinks = $target_node->firmlinks();
    if ($firmlinks && @$firmlinks > 0) {
      my $APP = $REQUEST->APP;
      my @firmlink_html;

      foreach my $firmlink (@$firmlinks) {
        my $title = $firmlink->title;
        my $url = "/title/" . $APP->rewriteCleanEscape($title);
        my $note_text = $firmlink->{firmlink_note_text} || '';
        my $link_html = qq{<a href="$url">$title</a>};
        # Append note text if present (with space prefix, matching legacy behavior)
        $link_html .= $APP->encodeHTML(" $note_text") if $note_text ne '';
        push @firmlink_html, $link_html;
      }

      my $firmlinks_str = join(', ', @firmlink_html);
      $m->print(qq{<div class="topic" id="firmlink"><strong>See also:</strong> $firmlinks_str</div>\n});
    }
  }
</%perl>
% if (!$REQUEST->user->is_guest) {
     <ul class="topic actions">
<%perl>
  # Add editor cool and bookmark icon buttons
  # Reuse $node and $ntypet from previous block
  $node = $.node;
  my $user = $REQUEST->user;
  my $APP = $REQUEST->APP;
  my $DB = $REQUEST->DB;
  my $node_id = $node->node_id || 0;
  $ntypet = $node->type->title;

  # Skip bookmark/cool buttons if node_id is invalid
  return unless $node_id > 0;

  # Editor cool button (editors only, for e2node/superdoc/document types, if allowed)
  if ($user->is_editor && ($ntypet eq 'e2node' || $ntypet eq 'superdoc' || $ntypet eq 'superdocnolinks' || $ntypet eq 'document') && $APP->can_edcool($node->NODEDATA)) {
    # Check if node is already editor cooled
    my $coollink_type = $DB->getNode('coollink', 'linktype');
    my $is_cooled = 0;
    if ($coollink_type) {
      my $link = $DB->sqlSelectHashref('*', 'links',
        "from_node=$node_id AND linktype=" . $coollink_type->{node_id});
      $is_cooled = $link ? 1 : 0;
    }

    my $color = $is_cooled ? '#f4d03f' : '#999';
    my $title_text = $is_cooled ? 'Remove editor cool' : 'Add editor cool (endorsement)';

    $m->print(qq{       <li><button onclick="window.toggleEditorCool && window.toggleEditorCool($node_id, this)" style="background: none; border: none; cursor: pointer; padding: 0; color: $color; font-size: 16px;" title="$title_text" data-cooled="$is_cooled">&#9733;</button></li>\n});
  }

  # Bookmark button (all logged-in users, if bookmarking is allowed)
  if ($APP->can_bookmark($node->NODEDATA)) {
    my $bookmark_type = $DB->getNode('bookmark', 'linktype');
    my $is_bookmarked = 0;
    if ($bookmark_type) {
      my $link = $DB->sqlSelectHashref('*', 'links',
        "from_node=" . $user->node_id . " AND to_node=$node_id AND linktype=" . $bookmark_type->{node_id});
      $is_bookmarked = $link ? 1 : 0;
    }

    my $bookmark_color = $is_bookmarked ? '#4060b0' : '#999';
    my $bookmark_title = $is_bookmarked ? 'Remove bookmark' : 'Bookmark this page';
    my $bookmark_icon = $is_bookmarked ? '&#128278;' : '&#128279;';  # Filled vs outline bookmark

    $m->print(qq{       <li><button onclick="window.toggleBookmark && window.toggleBookmark($node_id, this)" style="background: none; border: none; cursor: pointer; padding: 0; color: $bookmark_color; font-size: 16px;" title="$bookmark_title" data-bookmarked="$is_bookmarked">$bookmark_icon</button></li>\n});
  }
</%perl>
%   if ($.node->can_be_categoried) {
<& 'category', friendly_pagetype => $.friendly_pagetype, node => $.node &>
%   }
%   if ($.node->can_be_weblogged and $REQUEST->user->can_weblog) {
<& 'weblog', friendly_pagetype => $.friendly_pagetype, node => $.node &>
%   }
     </ul>
% }
  </div>

  <% inner() %>
  <!-- google_ad_section_end -->
 </div>
 <div id='sidebar'>
  <!-- Phase 3: React now renders the entire sidebar (no more Mason2 nodelet loop) -->
  <div id='e2-react-root'></div>
 </div> 
</div>
<div id='footer'>
Everything2 &trade; is brought to you by Everything2 Media, LLC. All content copyright &#169; original author unless stated otherwise.
</div>
<& 'static_javascript', nodeinfojson => $.nodeinfojson, default_javascript => $.default_javascript &>
</body>
</html>
</%augment>

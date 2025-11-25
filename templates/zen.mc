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
<link rel="icon" href="<% $.favicon %>" type="image/vnd.microsoft.icon">
<!--[if lt IE 8]><link rel="shortcut icon" href="<% $.favicon %>" type="image/x-icon"><![endif]-->
<link rel="alternate" type="application/atom+xml" title="<% $.atom_feed->[0] %>" href="<% $.atom_feed->[1] %>">
<meta content="width=device-width,initial-scale=1.0,user-scalable=1" name="viewport">

</head>
<body class="<% $.body_class %>" itemscope itemtype="http://schema.org/WebPage">
<& 'googleads', no_ads => $.no_ads &>
<div id='header'>
 <& 'searchform', script_name => $.script_name, lastnode => $.lastnode &>
 <div id='e2logo'><a href="/">Everything<span id="e2logo2">2</span></a></div>
</div>
<div id='wrapper'>
 <div id='mainbody' itemprop="mainContentOfPage"><!-- google_ad_section_start -->
  <div id="pageheader">
   <h1 class="nodetitle"><% $.node->title %></h1>
% if (!$REQUEST->user->is_guest) {
     <ul class="topic actions">
%   if ($.node->can_be_bookmarked) {
<& 'bookmark', friendly_pagetype => $.friendly_pagetype, node => $.node, bookmarktext => "Add to bookmarks" &>
%   }
%   if ($.node->can_be_categoried) {
<& 'category', friendly_pagetype => $.friendly_pagetype, node => $.node &>
%   }
%   if ($.node->can_be_weblogged and $REQUEST->user->can_weblog) {
<& 'weblog', friendly_pagetype => $.friendly_pagetype, node => $.node &>
%   }
     </ul>
% }
   <& 'ed_cooled' , node => $.node &>
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

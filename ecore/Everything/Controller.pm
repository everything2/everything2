package Everything::Controller;

use Moose;
with 'Everything::Globals';
with 'Everything::HTTP';

use Everything::HTML;
use Everything::HTMLShell;

has 'PAGE_TABLE' => (isa => "HashRef", is => "ro", builder => "_build_page_table", lazy => 1);

sub _build_page_table
{
  my ($self) = @_;
  return $self->APP->plugin_table("page");
}

sub display
{
  my ($self, $REQUEST, $node) = @_;

  # Default display for nodetypes without specific controllers
  # Similar to SystemNode but simpler - shows basic node info
  my $author = $self->APP->node_by_id($node->NODEDATA->{author_user});

  my $content_data = {
    type => 'default_display',
    nodeId => $node->node_id,
    nodeTitle => $node->title,
    nodeType => $node->NODEDATA->{type}->{title},
  };

  # Add author if available
  if ($author) {
    $content_data->{author} = {
      node_id => $author->node_id,
      title => $author->title
    };
  }

  # Add createtime if available
  if ($node->NODEDATA->{createtime}) {
    $content_data->{createtime} = $node->NODEDATA->{createtime};
  }

  # Add doctext if this nodetype has it (documents, etc.)
  if (exists $node->NODEDATA->{doctext} && $node->NODEDATA->{doctext}) {
    $content_data->{doctext} = $self->APP->htmlScreen($node->NODEDATA->{doctext});
  }

  # Set node on REQUEST for buildNodeInfoStructure
  $REQUEST->node($node);

  # Build e2 data structure
  my $e2 = $self->APP->buildNodeInfoStructure(
    $node->NODEDATA,
    $REQUEST->user->NODEDATA,
    $REQUEST->user->VARS,
    $REQUEST->cgi,
    $REQUEST
  );

  # Override contentData with our default display data
  $e2->{contentData} = $content_data;
  $e2->{reactPageMode} = \1;

  # Use react_page layout
  my $html = $self->layout(
    '/pages/react_page',
    e2 => $e2,
    REQUEST => $REQUEST,
    node => $node
  );

  return [$self->HTTP_OK, $html];
}

sub edit
{
  my ($self, $REQUEST, $node) = @_;

  # Default edit - redirect to basicedit for nodetypes without specific edit forms
  # This provides a universal fallback that gods can use to edit any node type
  return $self->basicedit($REQUEST, $node);
}

sub xml
{
  my ($self, $REQUEST, $node) = @_;

  my $xml = $node->to_xml();
  my $output = qq|<?xml version="1.0" standalone="yes"?>\n$xml|;

  return [$self->HTTP_OK, $output, {type => 'application/xml'}];
}

# basicedit - Gods-only raw database field editor
# Available for all nodetypes via ?displaytype=basicedit
sub basicedit
{
  my ($self, $REQUEST, $node) = @_;
  my $user = $REQUEST->user;

  # Only gods can use basicedit
  unless ($self->APP->isAdmin($user->NODEDATA)) {
    # Redirect non-gods to regular display
    return $self->display($REQUEST, $node);
  }

  # Build content data for SystemNodeEditor React component
  # Use NODEDATA->{type}->{title} to avoid cache issues with $node->type
  my $content_data = {
    type => 'basicedit',
    node_id => $node->node_id,
    title => $node->title,
    nodeType => $node->NODEDATA->{type}->{title},
  };

  # Set node on REQUEST for buildNodeInfoStructure
  $REQUEST->node($node);

  # Build e2 data structure
  my $e2 = $self->APP->buildNodeInfoStructure(
    $node->NODEDATA,
    $REQUEST->user->NODEDATA,
    $REQUEST->user->VARS,
    $REQUEST->cgi,
    $REQUEST
  );

  # Override contentData with our basicedit data
  $e2->{contentData} = $content_data;
  $e2->{reactPageMode} = \1;

  # Use react_page layout
  my $html = $self->layout(
    '/pages/react_page',
    e2 => $e2,
    REQUEST => $REQUEST,
    node => $node
  );

  return [$self->HTTP_OK, $html];
}

sub xmltrue
{
  my ($self, $REQUEST, $node) = @_;

  my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
  $str .= Everything::HTML::htmlcode("xmlheader") .
          Everything::HTML::htmlcode("formxml") .
          Everything::HTML::htmlcode("xmlfooter");

  return [$self->HTTP_OK, $str, {type => 'application/xml'}];
}

sub layout
{
  my ($self, $template, @p) = @_;
  my $params = {@p};
  my $REQUEST = $params->{REQUEST};
  my $node = $params->{node};

  my $basesheet = $self->APP->node_by_name("basesheet","stylesheet");
  my $zensheet = $REQUEST->user->style;
  my $customstyle = $self->APP->htmlScreen($REQUEST->user->customstyle);
  my $printsheet = $self->APP->node_by_name("print","stylesheet");

  my $canonical_url = "https://".$self->CONF->canonical_web_server.$params->{node}->canonical_url;

  my $basesheet_url = $basesheet->cdn_link;
  my $zensheet_url = $zensheet->cdn_link;
  my $printsheet_url = $printsheet->cdn_link;

  # Check if user is using the default theme (Kernel Blue)
  # If so, skip loading the zensheet since basesheet already has Kernel Blue defaults
  my $default_style = $self->APP->node_by_name($self->CONF->default_style, "stylesheet");
  my $is_default_theme = ($zensheet->node_id == $default_style->node_id);

  if ($is_default_theme) {
    # Don't load a separate zensheet - basesheet has all Kernel Blue defaults
    $zensheet_url = '';
  }

  # Build body class - add writeuppage for e2node/writeup/draft like legacy container
  my $type_title = $node->type->title;
  my $body_class = '';
  if ($type_title eq 'e2node' || $type_title eq 'writeup' || $type_title eq 'draft') {
    $body_class = 'writeuppage ';
  }
  $body_class .= $type_title;

  # Build nodeletorder for React sidebar
  # For guest users, always use guest_nodelets config
  my $user_nodelets;
  if ($REQUEST->user->is_guest) {
    my $guest_nodelet_ids = $self->CONF->guest_nodelets || [];
    $user_nodelets = [];
    foreach my $nid (@$guest_nodelet_ids) {
      my $nodelet = $self->APP->node_by_id($nid);
      push @$user_nodelets, $nodelet if $nodelet;
    }
  } else {
    $user_nodelets = $REQUEST->user->nodelets || [];
  }

  my @nodeletorder = ();
  foreach my $nodelet (@$user_nodelets) {
    my $title = lc($nodelet->title);
    $title =~ s/ /_/g;
    push @nodeletorder, $title;
  }

  # Use e2 data from controller if already built, otherwise build fresh
  my $e2 = $params->{e2} || $self->APP->buildNodeInfoStructure($node->NODEDATA, $REQUEST->user->NODEDATA, $REQUEST->user->VARS, $REQUEST->cgi, $REQUEST);
  $e2->{lastnode_id} = $params->{lastnode_id};
  $e2->{nodeletorder} = \@nodeletorder;

  # Pass collapsedNodelets from user preferences to frontend
  $e2->{collapsedNodelets} = $REQUEST->VARS->{collapsedNodelets} if $REQUEST->VARS->{collapsedNodelets};
  $e2->{collapsedNodelets} =~ s/\bsignin\b// if defined $e2->{collapsedNodelets} && $e2->{collapsedNodelets};

  # Developer nodelet for edev members
  my $nodelets_var = ($REQUEST->user->VARS && $REQUEST->user->VARS->{nodelets}) // '';
  if($e2->{user}->{developer} and $nodelets_var =~ /836984/)
  {
    my $edev = $self->APP->node_by_name("edev","usergroup");
    my $page = Everything::HTML::getPage($node->NODEDATA, scalar($REQUEST->param("displaytype")));
    my $page_struct = {node_id => $page->{node_id}, title => $page->{title}, type => $page->{type}->{title}};
    my $sourceMap = $self->APP->buildSourceMap($node->NODEDATA, $page);
    $e2->{developerNodelet} = {
      page => $page_struct,
      news => {weblog_id => $edev->node_id, weblogs => $self->APP->weblogs_structure($edev->node_id)},
      sourceMap => $sourceMap
    };
  }

  # Build shell parameters - controllers can override via $params->{shell_overrides}
  my %shell_params = (
    node => $node,
    REQUEST => $REQUEST,
    e2_json => $self->JSON->encode($e2),
    basesheet => $basesheet_url,
    zensheet => $zensheet_url,
    printsheet => $printsheet_url,
    customstyle => $customstyle // '',
    canonical_url => $canonical_url,
    react_bundle => $self->APP->asset_uri("react/main.bundle.js"),
    favicon => $self->APP->asset_uri("static/favicon.ico"),
    metadescription => $node->metadescription,
    body_class => $body_class,
    basehref => ($REQUEST->is_guest) ? ($self->APP->basehref) : '',
  );

  # Allow controller overrides (e.g., meta_robots_index, meta_robots_follow)
  if ($params->{shell_overrides}) {
    %shell_params = (%shell_params, %{$params->{shell_overrides}});
  }

  # Generate HTML using HTMLShell (no more Mason!)
  my $shell = Everything::HTMLShell->new(%shell_params);
  my $output = $shell->render();

  # Persist VARS changes made during buildNodeInfoStructure (oldGP, oldexp, etc.)
  unless ($REQUEST->is_guest) {
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->user->VARS;
    Everything::setVars($USER, $VARS);
  }

  return $output;
}

sub epicenter
{
  my ($self, $REQUEST, $node) = @_;
  
  if($REQUEST->is_guest)
  {
    return;
  }

  my $params = {};
  foreach my $property (qw|is_borged level coolsleft votesleft newxp newgp writeups_to_level xp_to_level|)
  {
    $params->{$property} = $REQUEST->user->$property;
  }

  return $params;
}

sub title_to_page
{
  my ($self, $title) = @_;

  $title = lc($title);
  $title =~ s/[\s\/\:\?\'\-\!\.]/_/g;
  $title =~ s/_+/_/g;
  $title =~ s/_$//g;
  return $title;
}

sub page_exists
{
  my ($self, $page) = @_;

  my $page_to_find = $self->title_to_page($page);
  return exists($self->PAGE_TABLE->{$page_to_find});
}

1;

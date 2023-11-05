package Everything::Controller;

use Moose;
with 'Everything::Globals';
with 'Everything::HTTP';

use Everything::Delegation::nodelet;

has 'PAGE_TABLE' => (isa => "HashRef", is => "ro", builder => "_build_page_table", lazy => 1);

sub _build_page_table
{
  my ($self) = @_;
  return $self->APP->plugin_table("page");
}

sub display
{
  my ($self, $REQUEST) = @_;

  return [$self->HTTP_UNIMPLEMENTED];
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
  
  $params->{basesheet} = $basesheet->cdn_link;
  $params->{zensheet} = $zensheet->cdn_link;
  $params->{customstyle} = $customstyle;
  $params->{printsheet} = $printsheet->cdn_link;
  $params->{basehref} = ($REQUEST->is_guest)?($self->APP->basehref):(undef);
  $params->{canonical_url} = $canonical_url;
  $params->{metadescription} = $node->metadescription;

  $params->{body_class} = $node->type->title;

  $params->{default_javascript} = [$self->APP->asset_uri("react/main.bundle.js"),$self->APP->asset_uri("legacy.js")];
  $params->{favicon} = $self->APP->asset_uri("react/assets/favicon.ico");

  my $lastnode = $REQUEST->param("lastnode_id");
  if($lastnode)
  {
    # TODO Should we make sure that lastnode is readable? 
    $lastnode = $self->APP->node_by_id($lastnode);
    $lastnode = undef unless $lastnode;
  }
  $lastnode ||= $node;

  $params->{lastnode} ||= $lastnode;

  $params->{script_name} = $REQUEST->script_name;

  my $e2 = $self->APP->buildNodeInfoStructure($node->NODEDATA, $REQUEST->user->NODEDATA, $REQUEST->user->VARS);
  $e2->{lastnode_id} = $params->{lastnode_id};

  my $cookie = undef;
  foreach ('fxDuration', 'collapsedNodelets', 'settings_useTinyMCE', 'autoChat', 'inactiveWindowMarker'){
    if (!$REQUEST->is_guest){
      $REQUEST->VARS->{$_} = $cookie if($cookie = $REQUEST->cookie($_));
      delete $REQUEST->VARS->{$_} if(defined($cookie) and $cookie eq '0');
    }
    $e2->{$_} = $REQUEST->VARS->{$_} if ($REQUEST->VARS->{$_});
  }

  $e2->{collapsedNodelets} =~ s/\bsignin\b//;

  if($e2->{user}->{developer} and $REQUEST->user->VARS->{nodelets} =~ /836984/)
  {
    my $edev = $self->APP->node_by_name("edev","usergroup");
    my $page = Everything::HTML::getPage($node->NODEDATA, $REQUEST->param("displaytype"));
    my $page_struct = {node_id => $page->{node_id}, title => $page->{title}, type => $page->{type}->{title}};
    $e2->{developerNodelet} = {page => $page_struct, news => {weblog_id => $edev->node_id, weblogs => $self->APP->weblogs_structure($edev->node_id)}}; 
  }

  $params->{nodeinfojson} = $self->JSON->encode($e2);

  $params->{no_ads} = 1 unless($REQUEST->is_guest);

  $params = $self->nodelets($REQUEST->user->nodelets, $params);

  $self->MASON->set_global('$REQUEST',$REQUEST);
  return $self->MASON->run($template, $params)->output();
}

sub nodelets
{
  my ($self, $nodelets, $params) = @_;
  my $REQUEST = $params->{REQUEST};
  my $node = $params->{node};

  $params->{nodelets} = {};
  $params->{nodeletorder} ||= [];

  foreach my $nodelet (@{$nodelets|| []})
  {
    my $title = lc($nodelet->title);
    my $id = $title;
    $title =~ s/ /_/g;
    $id =~ s/\W//g;

    if($self->can($title))
    {
      $self->devLog("In controller-handled nodelet: $title");
      my $nodelet_values = $self->$title($REQUEST, $node);
      next unless $nodelet_values;
      $params->{nodelets}->{$title} = $nodelet_values;
    }else{
      if(my $delegation = Everything::Delegation::nodelet->can($title))
      {
        $self->devLog("Using delegated nodelet content for: $title");
        $params->{nodelets}->{$title}->{delegated_content} = $delegation->($self->DB, $REQUEST->cgi, $node->NODEDATA, $REQUEST->user->NODEDATA,$REQUEST->VARS, $Everything::HTML::PAGELOAD, $self->APP);
      }
    }
    push @{$params->{nodeletorder}}, $title;  
    $params->{nodelets}->{$title}->{title} = $nodelet->title;
    $params->{nodelets}->{$title}->{id} = $id;
    $params->{nodelets}->{$title}->{node} = $node;
  }
  return $params;
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
  $title =~ s/[\s\/\:\?\']/_/g;
  $title =~ s/_+/_/g;
  $title =~ s/_$//g;
  return $title;
}

sub fully_supports
{
  my ($self, $title) = @_;
  return 1;
}

sub page_exists
{
  my ($self, $page) = @_;
  
  my $page_to_find = $self->title_to_page($page);
  $self->devLog("Looking for page: $page_to_find");
  return exists($self->PAGE_TABLE->{$page_to_find});
}

1;

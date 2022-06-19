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

  my $gzip = (($REQUEST->can_gzip)?("gz"):(undef));
 
  my $basesheet = $self->APP->node_by_name("basesheet","stylesheet");
  my $zensheet = $REQUEST->user->style;
  my $customstyle = $self->APP->htmlScreen($REQUEST->user->customstyle);
  my $printsheet = $self->APP->node_by_name("print","stylesheet");

  my $canonical_url = "https://".$self->CONF->canonical_web_server.$params->{node}->canonical_url;
  
  $params->{basesheet} = $basesheet->cdn_link($gzip);
  $params->{zensheet} = $zensheet->cdn_link($gzip);
  $params->{customstyle} = $customstyle;
  $params->{printsheet} = $printsheet->cdn_link($gzip);
  $params->{basehref} = ($REQUEST->is_guest)?($self->APP->basehref):(undef);
  $params->{canonical_url} = $canonical_url;
  $params->{metadescription} = $node->metadescription;

  $params->{body_class} = $node->type->title;

  $params->{default_javascript} = $self->APP->node_by_name("default javascript","jscript")->cdn_link;


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

  my $e2 = undef;
  $e2->{node_id} = $node->node_id;
  $e2->{lastnode_id} = $params->{lastnode_id};
  $e2->{title} = $node->title;
  $e2->{guest} = $REQUEST->is_guest;
  $e2->{use_local_assets} = $self->CONF->use_local_assets;
  if($e2->{use_local_assets} == 0)
  {
    $e2->{assets_location} = $self->CONF->assets_location;
  }else{
    $e2->{assets_location} = "";
  }
  $e2->{can_gzip} = $REQUEST->can_gzip;

  my $cookie = undef;
  foreach ('fxDuration', 'collapsedNodelets', 'settings_useTinyMCE', 'autoChat', 'inactiveWindowMarker'){
    if (!$REQUEST->is_guest){
      $REQUEST->VARS->{$_} = $cookie if($cookie = $REQUEST->cookie($_));
      delete $REQUEST->VARS->{$_} if(defined($cookie) and $cookie eq '0');
    }
    $e2->{$_} = $REQUEST->VARS->{$_} if ($REQUEST->VARS->{$_});
  }

  $e2->{collapsedNodelets} =~ s/\bsignin\b//;
  $e2->{noquickvote} = 1 if($REQUEST->VARS->{noquickvote});
  $e2->{nonodeletcollapser} = 1 if($REQUEST->VARS->{nonodeletcollapser});
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

sub new_writeups
{
  my ($self, $REQUEST, $node) = @_;

  my $params = {};
  $params->{newwriteups} = [];
  foreach my $newwriteups_entry (@{$self->DB->stashData("newwriteups")})
  {
    push @{$params->{newwriteups}}, $self->APP->node_by_id($newwriteups_entry->{writeup_id});
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

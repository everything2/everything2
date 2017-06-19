package Everything::HTMLRouter;

use Moose;
extends 'Everything::Router';

has 'PAGE_TABLE' => (isa => 'HashRef', is => 'ro', builder => '_build_page_table', lazy => 1); 

sub _build_page_table
{
  my ($self) = @_;
  return $self->_build_controller_table('page');
}


#TODO unblessed node
sub can_route
{
  my ($self, $NODE, $displaytype) = @_;

  $displaytype ||= "display";
  $self->devLog("Checking route controller for: $NODE->{type}->{title} with view '$displaytype'");
  if(exists($self->CONTROLLER_TABLE->{$NODE->{type}->{title}}) and $self->CONTROLLER_TABLE->{$NODE->{type}->{title}}->transate_to_page)  {
    $self->devLog("Route for $NODE->{type}->{title} is a Page type");
    if($self->page_exists($NODE, $displaytype))
    {
       $self->devLog("Page found for $NODE->{title}");
       return 1;
    }else{
       $self->devLog("Page NOT found for $NODE->{title}");
       return 0;
    }
  }

  if(exists($self->CONTROLLER_TABLE->{$NODE->{type}->{title}}) and $self->CONTROLLER_TABLE->{$NODE->{type}->{title}}->can($displaytype))
  {
    $self->devLog("Can route for: $NODE->{type}->{title} with view '$displaytype'");
    return 1;
  }

  $self->devLog("Can NOT route for: $NODE->{type}->{title} with view '$displaytype'");
  return;
}

sub page_exists
{
  my ($self, $NODE, $displaytype) = @_;

  # Fix the unblessed node here.
  # First, check the type
  return unless(exists($self->CONTROLLER_TABLE->{$NODE->{type}->{title}}) and $self->CONTROLLER_TABLE->{$NODE->{type}->{title}}->transate_to_page);

  my $page = $self->title_to_page($NODE->{title});
  $self->devLog("Checking for Page for '$NODE->{title}' as '$page' with displaytype '$displaytype'");

  if(exists($self->PAGE_TABLE->{$page}))
  {
    $self->devLog("$page exists in plugin cache");
  }else{
    $self->devLog("$page does not exist in plugin cache");
    return;
  }


  if($self->PAGE_TABLE->{$page}->can($displaytype))
  {
    $self->devLog("$page is saying it can '$displaytype'");
    return 1;
  }else{
    $self->devLog("$page is saying it can NOT '$displaytype'");
  }

  return;
}

sub title_to_page
{
  my ($self, $title) = @_;

  $title = lc($title);
  $title =~ s/[\s\/\:\?]/_/g;
  return $title;
}

sub route_node
{
  my ($self, $NODE, $displaytype, $REQUEST) = @_;
  $displaytype ||= "display";

  my $node = $self->APP->node_by_id($NODE->{node_id});
  if($self->page_exists($NODE, $displaytype))
  {
    $self->devLog("Using page router for node: '$NODE->{title}' with displaytype '$displaytype'");
    my $page = $self->title_to_page($NODE->{title});
    return $self->output($REQUEST, $self->PAGE_TABLE->{$page}->$displaytype($REQUEST, $node));
  }else{
    return $self->output($REQUEST, $self->CONTROLLER_TABLE->{$node->type->title}->$displaytype($REQUEST, $node));
  }
}

1;

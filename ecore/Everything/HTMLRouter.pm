package Everything::HTMLRouter;

use Moose;
extends 'Everything::Router';

# Base controller instance for nodetypes without specific controllers
# Loaded lazily to avoid circular dependencies at compile time
has 'BASE_CONTROLLER' => (
  is => 'ro',
  lazy => 1,
  builder => '_build_base_controller'
);

sub _build_base_controller {
  my ($self) = @_;
  require Everything::Controller;
  return Everything::Controller->new;
}

sub can_route
{
  my ($self, $NODE, $displaytype) = @_;

  $displaytype ||= "display";

  unless(grep { $displaytype eq $_ } ("display","edit","xml","xmltrue","basicedit","editvars","softlinks","useredit","compact","replyto","atom"))
  {
    $self->devLog("Using banned displaytype: '$displaytype', falling back");
    return 0;
  }

  my $nodetype = $NODE->{type}->{title};

  # Check if there's a specific controller for this nodetype
  if(exists($self->CONTROLLER_TABLE->{$nodetype}) and $self->CONTROLLER_TABLE->{$nodetype}->can($displaytype))
  {
    return 1;
  }

  # Fall back to base controller for standard displaytypes
  if($self->BASE_CONTROLLER->can($displaytype))
  {
    return 1;
  }

  $self->devLog("Can NOT route for: $NODE->{type}->{title} with view '$displaytype'");
  return;
}

sub route_node
{
  my ($self, $NODE, $displaytype, $REQUEST) = @_;
  $displaytype ||= "display";

  # Get the nodetype title from the already-loaded $NODE hashref
  # Don't use $node->type->title as it triggers node_by_id which has cache issues
  my $nodetype = $NODE->{type}->{title};

  # Use get_blessed_node directly to avoid cache issues with node_by_id
  my $node = $self->APP->get_blessed_node($NODE);

  unless ($node) {
    $self->devLog("route_node: get_blessed_node returned undef for node_id $NODE->{node_id}, type: $nodetype");
    return;
  }

  # Preserve the 'group' field if it exists (used for duplicates_found page)
  if (exists $NODE->{group}) {
    $node->NODEDATA->{group} = $NODE->{group};
  }

  # Use specific controller if available, otherwise fall back to base controller
  my $controller;
  if (exists($self->CONTROLLER_TABLE->{$nodetype}) and $self->CONTROLLER_TABLE->{$nodetype}->can($displaytype)) {
    $controller = $self->CONTROLLER_TABLE->{$nodetype};
  } else {
    $self->devLog("route_node: Using base controller for '$nodetype' with view '$displaytype'");
    $controller = $self->BASE_CONTROLLER;
  }

  return $self->output($REQUEST, $controller->$displaytype($REQUEST, $node));
}

1;

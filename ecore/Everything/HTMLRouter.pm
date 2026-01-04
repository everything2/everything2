package Everything::HTMLRouter;

use Moose;
extends 'Everything::Router';

#TODO unblessed node
sub can_route
{
  my ($self, $NODE, $displaytype) = @_;

  $displaytype ||= "display";

  unless(grep { $displaytype eq $_ } ("display","edit","xml","xmltrue","basicedit"))
  {
    $self->devLog("Using banned displaytype: '$displaytype', falling back");
    return 0;
  }

  $self->devLog("Checking route controller for: $NODE->{type}->{title} with view '$displaytype'");

  my $nodetype = $NODE->{type}->{title};

  if(exists($self->CONTROLLER_TABLE->{$nodetype}) and $self->CONTROLLER_TABLE->{$nodetype}->can($displaytype))
  {
    if($self->CONTROLLER_TABLE->{$nodetype}->fully_supports($NODE->{title}))
    {
      $self->devLog("Node type '$nodetype' has full support for page '$NODE->{title}'");
      return 1;
    }else{
      $self->devLog("Node type '$nodetype' does not fully support page '$NODE->{title}'");
      return 0;
    }
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

  return $self->output($REQUEST, $self->CONTROLLER_TABLE->{$nodetype}->$displaytype($REQUEST, $node));
}

1;

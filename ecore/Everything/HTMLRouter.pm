package Everything::HTMLRouter;

use Moose;
extends 'Everything::Router';

#TODO unblessed node
sub can_route
{
  my ($self, $NODE, $displaytype) = @_;

  $displaytype ||= "display";

  unless(grep { $displaytype eq $_ } ("display","edit","xml","xmltrue"))
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
    $self->devLog("Can route for: $nodetype with view '$displaytype'");
    return 1;
  }

  $self->devLog("Can NOT route for: $NODE->{type}->{title} with view '$displaytype'");
  return;
}

sub route_node
{
  my ($self, $NODE, $displaytype, $REQUEST) = @_;
  $displaytype ||= "display";

  my $node = $self->APP->node_by_id($NODE->{node_id});
  return $self->output($REQUEST, $self->CONTROLLER_TABLE->{$node->type->title}->$displaytype($REQUEST, $node));
}

1;

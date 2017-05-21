package Everything::HTMLRouter;

use Moose;
extends 'Everything::Router';

use Data::Dumper;

sub can_route
{
  my ($self, $node, $displaytype) = @_;

  $displaytype ||= "display";
  $self->devLog("Checking route controller for: $node->{type}->{title} with view '$displaytype'");

  #TODO unblessed node
  if(exists($self->CONTROLLER_TABLE->{$node->{type}->{title}}) and $self->CONTROLLER_TABLE->{$node->{type}->{title}}->can($displaytype))
  {
    $self->devLog("Can route for: $node->{type}->{title} with view '$displaytype'");
    return 1;
  }

  $self->devLog("Can NOT route for: $node->{type}->{title} with view '$displaytype'");
  return;
}

sub route_node
{
  my ($self, $NODE, $displaytype, $REQUEST) = @_;
  $displaytype ||= "display";
  my $node = $self->APP->node_by_id($NODE->{node_id});

  $self->output($REQUEST, $self->CONTROLLER_TABLE->{$node->type->title}->$displaytype($REQUEST, $node));
}

1;

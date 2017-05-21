package Everything::Node::maintenance;
use Moose;
extends 'Everything::Node::htmlcode';
with 'Everything::Node::helper::delegated';

sub maintaintype
{
  my ($self) = @_;
  return $self->NODEDATA->{maintaintype};
}

sub maintains
{
  my ($self) = @_;
  return $self->APP->node_by_id($self->NODEDATA->{maintain_nodetype});
}

sub maintenance_sub
{
  my ($self) = @_;
  return lc($self->maintains->title."_".$self->NODEDATA->{maintaintype});
}

__PACKAGE__->meta->make_immutable;
1;

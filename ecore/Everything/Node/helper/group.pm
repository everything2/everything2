package Everything::Node::helper::group;

use Moose::Role;

has 'group' => (is => 'rw', lazy => 1, builder => '_build_group');

sub _build_group
{
  my ($self) = @_;

  my $group = [];
  foreach my $item (@{$self->NODEDATA->{group} || []})
  {
    push @$group, $self->APP->node_by_id($item);
  }

  return $group;
}

sub group_remove
{
  my ($self, $items_to_remove, $user) = @_;

  foreach my $item (@$items_to_remove)
  {
    my $itemnode = $self->APP->node_by_id($item);
    unless($itemnode)
    {
      $self->devLog("Couldn't find item node for id: $item");
      next;
    }
    $self->DB->removeFromNodegroup($self->NODEDATA, $itemnode->NODEDATA, $user->NODEDATA);
  }
  $self->DB->updateNode($self->NODEDATA, $user->NODEDATA);

  $self->NODEDATA($self->DB->getNodeById($self->node_id));
  $self->group($self->_build_group);
  return $self;
}

sub group_add
{
  my ($self, $items_to_add, $user) = @_;

  foreach my $item (@$items_to_add)
  {
    my $itemnode = $self->APP->node_by_id($item);
    unless($itemnode)
    {
      $self->devLog("Couldn't find item node for id: $item");
      next;
    }
    my $found = 0;
    foreach my $group_item (@{$self->NODEDATA->{group}})
    {
      if($item eq $group_item)
      {
        $found = 1;
        last;
      }
    }
    unless($found)
    {
      $self->DB->insertIntoNodegroup($self->NODEDATA, $user->NODEDATA, $itemnode->NODEDATA);
    }
  }
  $self->DB->updateNode($self->NODEDATA, $user->NODEDATA);

  $self->NODEDATA($self->DB->getNodeById($self->node_id));
  $self->group($self->_build_group);
  return $self;
}

1;

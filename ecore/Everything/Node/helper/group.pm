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
  my ($self, $items_to_remove) = @_;

  my $newgroup = [];
  foreach my $group_item (@{$self->NODEDATA->{group}})
  {
    my $found = 0;
    foreach my $item (@$items_to_remove)
    {
      if($group_item == $item)
      {
        $found = 1;
        last;
      }
    }
    unless($found)
    {
      push @$newgroup, $group_item;
    }
  }

  $self->NODEDATA->{group} = $newgroup;
  $self->group($self->_build_group);
  return $self;
}

sub group_add
{
  my ($self, $items_to_add) = @_;

  foreach my $item (@$items_to_add)
  {
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
      push @{$self->NODEDATA->{group}},$item;
    }
  }

  $self->group($self->_build_group);
  return $self;
}

1;

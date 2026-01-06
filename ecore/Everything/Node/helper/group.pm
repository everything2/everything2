package Everything::Node::helper::group;

use Moose::Role;

has 'is_group' => (is => 'ro', default => 1);
has 'flatgroup' => (is => 'ro', lazy => 1, builder => '_build_flatgroup');
has 'group' => (is => 'rw', lazy => 1, builder => '_build_group');

sub _build_group
{
  my ($self) = @_;

  my $group = [];
  foreach my $item (@{$self->NODEDATA->{group} || []})
  {
    push @{$group}, $self->APP->node_by_id($item);
  }

  return $group;
}

sub _build_flatgroup
{
  my ($self) = @_;

  my $seen = {};
  my $group = [];

  return $self->_flatten($self->group, {});
}

sub _flatten
{
  my ($self, $group, $seen) = @_;

  my $output = [];

  foreach my $n (@{$group})
  {
    next if $seen->{$n->id};
    $seen->{$n->id} = 1;

    if($n->is_group)
    {
      push(@{$output}, @{$self->_flatten($n->group, $seen)});
    }else{
      push(@{$output}, $n);
    }
  }

  return $output;
}

sub group_remove
{
  my ($self, $items_to_remove, $user) = @_;

  foreach my $item (@{$items_to_remove})
  {
    my $itemnode = $self->APP->node_by_id($item);
    unless($itemnode)
    {
      # No item node for id
      next;
    }
    $self->DB->removeFromNodegroup($self->NODEDATA, $itemnode->NODEDATA, $user->NODEDATA);
  }
  $self->DB->updateNode($self->NODEDATA, $user->NODEDATA);

  $self->cache_refresh;
  $self->group($self->_build_group);
  return $self;
}

sub group_add
{
  my ($self, $items_to_add, $user) = @_;

  my $NODE = $self->NODEDATA;
  foreach my $item (@{$items_to_add})
  {
    my $itemnode = $self->APP->node_by_id($item);
    unless($itemnode)
    {
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
      $self->DB->insertIntoNodegroup($NODE, $user->NODEDATA, $item);
    }
  }
  $self->cache_refresh;
  $self->group($self->_build_group);

  $self->DB->updateNode($self->NODEDATA, $user->NODEDATA);

  return $self;
}

1;

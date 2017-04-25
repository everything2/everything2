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

1;

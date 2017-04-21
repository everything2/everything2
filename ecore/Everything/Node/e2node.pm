package Everything::Node::e2node;

use Moose;
extends 'Everything::Node';

has 'group' => (is => 'ro', lazy => 1, builder => '_build_group');

sub _build_group
{
  my ($self) = @_;

  my $group;
  foreach my $item (@{$self->NODEDATA->{group}})
  {
    push @$group, $self->APP->node_by_id($item);
  }

  return $group;
}

override 'json_display' => sub
{
  my ($self) = @_;
  my $values = super();

  $values->{author} = $self->author->json_reference;

  return $values;
};

sub group_voting_display
{
  my ($self, $user) = @_;

  my $values = $self->json_display;

  my $group;

  foreach my $writeup (@{$self->group})
  {
    push @$group, $writeup->voting_display($user);
  }

  if(scalar(@$group) > 0)
  {
    $values->{group} = $group;
  }

  return $values;
}

__PACKAGE__->meta->make_immutable;
1;

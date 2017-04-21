package Everything::Node::e2node;

use Moose;
extends 'Everything::Node';

with 'Everything::Node::helper::group';

override 'json_display' => sub
{
  my ($self, $user) = @_;
  my $values = super();

  my $group = [];
  $values->{author} = $self->author->json_reference;

  foreach my $writeup (@{$self->group || []})
  {
    push @$group, $writeup->display_single_writeup($user);
  }

  if(scalar(@$group) > 0)
  {
    $values->{group} = $group;
  }

  return $values;
};

__PACKAGE__->meta->make_immutable;
1;

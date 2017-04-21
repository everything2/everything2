package Everything::Node::usergroup;

use Moose;
extends 'Everything::Node::document';
with 'Everything::Node::helper::group';

override 'json_display' => sub
{
  my ($self) = @_;
  my $values = super();

  my $group = [];

  foreach my $user (@{$self->group})
  {
    push @$group,$user->json_reference;
  }

  if(scalar(@$group) > 0)
  {
    $values->{group} = $group;
  }

  return $values;
};

__PACKAGE__->meta->make_immutable;
1;

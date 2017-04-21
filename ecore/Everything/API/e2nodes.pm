package Everything::API::e2nodes;

use Moose;
extends 'Everything::API::nodes';

sub get_id
{
  my ($self, $node, $user) = @_;

  unless($node->type->title eq "e2node")
  {
    return [$self->HTTP_NOT_FOUND];
  }

  return [$self->HTTP_OK, $node->json_display($user)];
}

around ['get_id'] => \&Everything::API::nodes::_can_read_okay;

__PACKAGE__->meta->make_immutable;
1;

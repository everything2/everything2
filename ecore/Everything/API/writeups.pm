package Everything::API::writeups;

use Moose;
extends 'Everything::API::nodes';

sub get_id
{
  my ($self, $node, $user) = @_;

  unless($node->type->title eq "writeup")
  {
    return [$self->HTTP_NOT_FOUND];
  }

  my $u = $self->APP->node_by_id($user->{node_id});
  return [$self->HTTP_OK, $node->voting_display($u)];
}

around ['get_id'] => \&Everything::API::nodes::_can_read_okay;
__PACKAGE__->meta->make_immutable;
1;

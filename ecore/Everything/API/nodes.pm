package Everything::API::nodes;

use strict;
use Moose;

extends 'Everything::API';

sub routes
{ 
  return {
  "/" => "get",
  "/:id" => "get_id(:id)"
  }
}

sub get
{
  my ($self, $REQUEST, $version, $id) = @_;

  return [$self->HTTP_UNIMPLEMENTED];
}

sub get_id
{
  my ($self, $node, $user) = @_;
  return [$self->HTTP_OK, $node->json_display($user)]
}

sub _can_read_okay
{
  my ($orig, $self, $REQUEST, $version, $id) = @_;

  my $node = $self->APP->node_by_id(int($id));

  # We need a cleanly blessed node object to continue
  unless($node)
  {
    return [$self->HTTP_UNIMPLEMENTED];
  }

  if($node->can_read_node($REQUEST->USER))
  {
    my $user = $self->APP->node_by_id($REQUEST->USER->{user_id});
    return $self->$orig($node,$user);
  }else{
    return [$self->HTTP_FORBIDDEN];
  }

}

around ['get_id'] => \&_can_read_okay;
 
__PACKAGE__->meta->make_immutable;
1;


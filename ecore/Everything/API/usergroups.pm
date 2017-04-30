package Everything::API::usergroups;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

around 'routes' => sub {
  my ($orig, $self) = @_;

  my $routes = $self->$orig;
  $routes->{':id/action/adduser'} = 'adduser(:id)';
  $routes->{':id/action/removeuser'} = 'removeuser(:id)';

  return $routes;
};

sub _group_operation_permissions
{
  my ($orig, $self, $REQUEST, $version, $id) = @_;

  my $user = $self->APP->node_by_id($REQUEST->USER->{node_id});
  if($user->is_guest)
  {
    $self->devLog("User is not logged in and thus can never perform these functions. Returning UNAUTHORIZED");
    return [$self->HTTP_UNAUTHORIZED];
  }

  my $group = $self->APP->node_by_id($id);
  unless($group)
  {
    $self->devLog("Could not find node by id: $id. Returning NOT FOUND");
    return [$self->HTTP_NOT_FOUND];
  }

  unless($group->can_update_node($user))
  {
    $self->devLog("User doesn't have permission to update node ".$group->title." (".$group->node_id."). Returning FORBIDDEN");
    return [$self->HTTP_FORBIDDEN];
  }

  my $data = $self->parse_postdata($REQUEST);
  
  unless(ref $data eq "ARRAY")
  {
    $self->devLog("Expecting POST to be an array. Returning BAD REQUEST");
    return [$self->BAD_REQUEST];
  }

  return $self->$orig($user, $group, $data, $id);

}

sub adduser
{
  my ($self, $user, $group, $data) = @_;
  $group->group_add($data, $user);
  $group->update($user);

  return [$self->HTTP_OK, $group->json_display($user)];
}

sub removeuser
{
  my ($self, $user, $group, $data) = @_;
  $group->group_remove($data, $user);
  $group->update($user);

  return [$self->HTTP_OK, $group->json_display($user)];
}

around ['adduser','removeuser'] => \&_group_operation_permissions; 

__PACKAGE__->meta->make_immutable;
1;


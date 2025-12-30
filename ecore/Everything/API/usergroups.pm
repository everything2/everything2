package Everything::API::usergroups;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);
has 'UPDATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

around 'routes' => sub {
  my ($orig, $self) = @_;

  my $routes = $self->$orig;
  $routes->{':id/action/adduser'} = 'adduser(:id)';
  $routes->{':id/action/removeuser'} = 'removeuser(:id)';
  $routes->{':id/action/leave'} = 'leave(:id)';

  return $routes;
};

sub _group_operation_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_action_okay($REQUEST, 'update', $id);
  my ($node, $user) = (undef, undef);
  if($output->[0])
  {
    $node = $output->[1];
    $user = $output->[2];
  }else{
    return [$output->[1]];
  }

  my $data = $REQUEST->JSON_POSTDATA;

  unless(ref $data eq 'ARRAY')
  {
    # Expecting POST to be an array. Returning BAD REQUEST
    return [$self->BAD_REQUEST];
  }

  return $self->$orig($user, $node, $data);
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

# Allow a user to leave a usergroup they're a member of
# Unlike removeuser, this doesn't require admin permissions - just membership
sub _leave_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  # Must be logged in
  if ($REQUEST->user->is_guest) {
    return [$self->HTTP_FORBIDDEN, { success => 0, error => 'Must be logged in to leave a group' }];
  }

  # Get the usergroup - force fresh fetch to avoid race condition with recent adds
  my $group_hash = $self->DB->getNodeById($id, 'force');
  unless ($group_hash && $group_hash->{type}{title} eq 'usergroup') {
    return [$self->HTTP_NOT_FOUND, { success => 0, error => 'Usergroup not found' }];
  }

  # Check if user is actually in the group using direct DB query for accuracy
  my $user = $REQUEST->user;
  my $user_id = $user->node_id;
  my $in_group = $self->DB->sqlSelect('node_id', 'nodegroup',
    "nodegroup_id=$id AND node_id=$user_id");

  unless ($in_group) {
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'You are not a member of this group' }];
  }

  # Get the blessed node object for the leave operation
  my $group = $self->APP->node_by_id($id);
  return $self->$orig($REQUEST, $group, $user);
}

sub leave
{
  my ($self, $REQUEST, $group, $user) = @_;

  # Remove the user from the group
  $self->DB->removeFromNodegroup($group->NODEDATA, $user->NODEDATA, -1);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'You have left ' . $group->title
  }];
}

around ['adduser','removeuser'] => \&_group_operation_permissions;
around ['leave'] => \&_leave_permissions;

__PACKAGE__->meta->make_immutable;
1;


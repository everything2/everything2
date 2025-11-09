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

around ['adduser','removeuser'] => \&_group_operation_permissions;

__PACKAGE__->meta->make_immutable;
1;


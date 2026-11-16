package Everything::Node::collaboration;
use Moose;
extends 'Everything::Node::document';

# Members (the collaboration's approved list), crtleads, editors and admins can work on a
# collaboration. Anyone can read one that has been made public.
sub can_access
{
  my ($self, $user) = @_;

  return 1 if $user->is_admin || $user->is_editor;

  my $crtleads = $self->DB->getNode('crtleads', 'usergroup');
  return 1 if $crtleads && Everything::isApproved($user->NODEDATA, $crtleads);

  return Everything::isApproved($user->NODEDATA, $self->NODEDATA) ? 1 : 0;
}

sub can_read_node
{
  my ($self, $user) = @_;
  return 1 if $self->NODEDATA->{public};
  return $self->can_access($user);
}

__PACKAGE__->meta->make_immutable;
1;

package Everything::Node::debatecomment;
use Moose;
extends 'Everything::Node::document';

# Discussions belong to a usergroup: the root comment's `restricted` field names it. Legacy
# rows use 0 (or empty) for Content Editors and 1 for gods. Admins can read every discussion.
my $CONTENT_EDITORS = 923653;
my $GODS            = 114;

sub can_access
{
  my ($self, $user) = @_;

  return 1 if $user->is_admin;

  my $root_id = $self->NODEDATA->{root_debatecomment} || $self->node_id;
  my $root = $root_id == $self->node_id ? $self : $self->APP->node_by_id($root_id);
  return 0 unless $root;

  my $restricted_id = $root->NODEDATA->{restricted} || $CONTENT_EDITORS;
  $restricted_id = $GODS if $restricted_id == 1;

  my $group = $self->DB->getNodeById($restricted_id);
  return 0 unless $group;

  return $self->APP->inUsergroup($user->NODEDATA, $group) ? 1 : 0;
}

sub can_read_node
{
  my ($self, $user) = @_;
  return $self->can_access($user);
}

__PACKAGE__->meta->make_immutable;
1;

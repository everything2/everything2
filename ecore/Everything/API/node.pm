package Everything::API::node;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

# Generic node creation. Replaces the legacy op=new dispatch
# (Everything::HTML::opNew): create a node of a given type + title if the user
# is allowed (canCreateNode) and not a guest, returning the new node_id so the
# client can redirect to it. Callers: CreateNode.js, CreateCategory.js,
# E2CollaborationNodes.js. #4340 / #4335 Phase 2.

sub routes
{
  return {
    "create" => "create",
  }
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $data    = $REQUEST->JSON_POSTDATA || {};
  my $type_in = $data->{type};
  my $title   = defined $data->{title} ? $data->{title} : '';

  unless (defined $type_in && $type_in ne '' && $title ne '')
  {
    return [$self->HTTP_BAD_REQUEST, {success => 0, error => 'type and title are required'}];
  }

  my $DB   = $self->DB;
  my $APP  = $self->APP;
  my $user = $REQUEST->user;

  # getType resolves a type by name or node_id (same input op=new accepted).
  my $TYPE = $DB->getType($type_in);
  unless ($TYPE)
  {
    return [$self->HTTP_OK, {success => 0, error => 'Unknown node type'}];
  }

  unless ($DB->canCreateNode($user->NODEDATA, $TYPE))
  {
    return [$self->HTTP_FORBIDDEN, {success => 0, error => 'Permission denied'}];
  }

  my $nodename = $APP->cleanNodeName($title, 1);

  my $node_id = $DB->insertNode($nodename, $TYPE, $user->node_id);
  if (!$node_id)
  {
    # Node already exists -- return the existing id (op=new's behavior).
    $node_id = $DB->sqlSelect('node_id', 'node',
      'title=' . $DB->quote($nodename) . ' AND type_nodetype=' . $TYPE->{node_id});
  }

  return [$self->HTTP_OK, {success => 1, node_id => int($node_id), title => $nodename}];
}

around ['create'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

package Everything::API::nodes;

use Moose;
use URI::Escape;

## no critic (ProhibitBuiltinHomonyms)

extends 'Everything::API';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 0);
has 'UPDATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 0);

sub routes
{
  return {
  "/" => "get",
  "/:id" => "get_id(:id)",
  "/:id/action/delete" => "delete(:id)",
  "create" => "create",
  "/:id/action/update" => "update(:id)",
  "/:id/action/clone" => "clone(:id)",
  "lookup/:type/:title" => "get_by_name(:type,:title)"
  }
}

sub get
{
  my ($self, $REQUEST, $id) = @_;

  return [$self->HTTP_UNIMPLEMENTED];
}

sub get_by_name
{
  my ($self, $REQUEST, $type, $title) = @_;

  $type = uri_unescape($type);
  $title = uri_unescape($title);

  # Works around an ecore bug which throws an ISE on non-existent nodetype
  my $nodetype = $self->APP->node_by_name($type,'nodetype');
  unless($nodetype)
  {
    return [$self->HTTP_NOT_FOUND];
  }

  my $node = $self->APP->node_by_name(uri_unescape($title), uri_unescape($type));

  unless($node)
  {
    return [$self->HTTP_NOT_FOUND];
  }

  if($node->can_read_node($REQUEST->user))
  {
    return [$self->HTTP_OK, $node->json_display($REQUEST->user)];
  }else{
    # Could not read node per can_read_node. Returning FORBIDDEN
    return [$self->HTTP_FORBIDDEN];
  }

}

sub get_id
{
  my ($self, $node, $user) = @_;

  my $class = ref $self;
  $class =~ s/.*:://g;
  $class =~ s/s$//g;

  unless($class eq "node")
  {
    if($node->typeclass ne $class)
    {
      # Node class does not match API class (and is not node). Returning NOT FOUND
      return [$self->HTTP_NOT_FOUND];
    }
  }

  return [$self->HTTP_OK, $node->json_display($user)];
}

sub create
{
  my ($self, $REQUEST) = @_;

  if($REQUEST->is_guest)
  {
    # Guest cannot access create endpoint
    return [$self->HTTP_UNAUTHORIZED];
  }

  unless($self->CREATE_ALLOWED)
  {
    # Creation flag explicitly off for API, returning UNIMPLEMENTED
    return [$self->HTTP_UNIMPLEMENTED];
  }

  my $newnode = $self->APP->node_new($self->node_type);

  unless($newnode)
  {
    # Returning unimplemented due to lack of good node skeleton
    return [$self->HTTP_UNIMPLEMENTED];
  }

  unless($newnode->can_create_type($REQUEST->user))
  {
    return [$self->HTTP_FORBIDDEN];
  }

  my $postdata = $REQUEST->JSON_POSTDATA;
  $postdata = $self->translate_create_params($postdata);

  if(not defined($postdata))
  {
    # No postdata after translate_create_params, returning BAD REQUEST
    return [$self->HTTP_BAD_REQUEST];
  }

  my $allowed_data = {};

  foreach my $key (@{$newnode->field_whitelist},"title")
  {
    if(exists($postdata->{$key}))
    {
      $allowed_data->{$key} = $postdata->{$key};
    }
  }

  $allowed_data->{createdby_user} = $REQUEST->user->node_id;

  my $node = $newnode->insert($REQUEST->user, $allowed_data);

  unless($node)
  {
    # Didn't get a good node back from the insert routine, having to return UNAUTHORIZED
    return [$self->HTTP_UNAUTHORIZED];
  }

  return [$self->HTTP_OK, $node->json_display($REQUEST->user)];
}

sub translate_create_params
{
  my ($self, $postdata) = @_;

  # The default is to do no translation
  return $postdata;
}

sub update
{
  my ($self, $REQUEST, $node, $user) = @_;

  my $postdata = $REQUEST->JSON_POSTDATA;

  my $allowed_data = {};

  foreach my $key (@{$node->field_whitelist})
  {
    if(exists($postdata->{$key}))
    {
      $allowed_data->{$key} = $postdata->{$key};
    }
  }

  $node = $node->update($user, $allowed_data);
  if($node)
  {
    # Update successful, returning new node object as JSON
    return [$self->HTTP_OK, $node->json_display($user)];
  }else{
    # Update went wrong for some reason, returning FORBIDDEN
    return [$self->HTTP_FORBIDDEN];
  }

}

sub node_type
{
  my ($self) = @_;
  my $string = ref $self;
  $string =~ s/.*:://g;
  $string =~ s/s$//g;

  return $string;
}

sub _can_read_okay
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_action_okay($REQUEST, "read", $id);

  # On success: true, node, user
  # On failure: false, error
  if($output->[0])
  {
    return $self->$orig($output->[1], $output->[2]);
  }else{
    return [$output->[1]];
  }

}

sub _can_update_okay
{
  my ($orig, $self, $REQUEST, $id) = @_; 

  my $output = $self->_can_action_okay($REQUEST, "update", $id);
  if($output->[0])
  {
    return $self->$orig($REQUEST, $output->[1], $output->[2]);
  }else{
    return [$output->[1]];
  }
}

sub _can_delete_okay
{
  my ($orig, $self, $REQUEST, $id) = @_; 

  my $output = $self->_can_action_okay($REQUEST, "delete", $id);
  if($output->[0])
  {
    return $self->$orig($REQUEST, $output->[1], $output->[2]);
  }else{
    return [$output->[1]];
  }
}

sub _can_action_okay
{
  my ($self, $REQUEST, $action, $id) = @_;
  
  my $node = $self->APP->node_by_id(int($id));

  unless($node)
  {
    return [0, $self->HTTP_UNIMPLEMENTED];
  }

  my $check = "can_".$action."_node";
  if($node->$check($REQUEST->user))
  {
    return [1,$node,$REQUEST->user];
  }else{
    return [0,$self->HTTP_FORBIDDEN];
  }
}

sub delete
{
  my ($self, $REQUEST, $node, $user) = @_;

  my $node_id = $node->node_id;
  $node->delete($user);
  return [$self->HTTP_OK, {"deleted" => $node_id}];
}

sub clone
{
  my ($self, $REQUEST, $node, $user) = @_;

  # Get POST data
  my $postdata = $REQUEST->JSON_POSTDATA;
  if (!$postdata || !exists $postdata->{title}) {
    return [$self->HTTP_BAD_REQUEST, { error => "Missing title for cloned node" }];
  }

  my $new_title = $postdata->{title};
  if (!defined($new_title) || length($new_title) == 0) {
    return [$self->HTTP_BAD_REQUEST, { error => "Title cannot be empty" }];
  }

  # Check if a node with this title already exists
  my $type_title = $node->type->title;
  my $existing_node = $self->APP->node_by_name($new_title, $type_title);
  if ($existing_node) {
    return [$self->HTTP_CONFLICT, { error => "A node with this title already exists" }];
  }

  # Clone the node
  my $cloned_node = $node->clone($new_title, $user);

  unless($cloned_node) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { error => "Failed to clone node" }];
  }

  return [$self->HTTP_OK, {
    message => "Node cloned successfully",
    original_node_id => $node->node_id,
    original_title => $node->title,
    cloned_node_id => $cloned_node->node_id,
    cloned_title => $cloned_node->title,
    cloned_node => $cloned_node->json_display($user)
  }];
}

sub _can_clone_okay
{
  my ($orig, $self, $REQUEST, $id) = @_;

  # Check if user is admin
  unless($REQUEST->user->is_admin) {
    return [$self->HTTP_FORBIDDEN, { error => "Only administrators can clone nodes" }];
  }

  my $output = $self->_can_action_okay($REQUEST, "read", $id);
  if($output->[0])
  {
    return $self->$orig($REQUEST, $output->[1], $output->[2]);
  }else{
    return [$output->[1]];
  }
}

around ['get_id'] => \&_can_read_okay;
around ['delete'] => \&_can_delete_okay;
around ['update'] => \&_can_update_okay;
around ['clone'] => \&_can_clone_okay;

__PACKAGE__->meta->make_immutable;
1;


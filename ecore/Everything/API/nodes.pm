package Everything::API::nodes;

use Moose;
use URI::Escape;

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
  $self->devLog("Doing node lookup for: title: $title, type: $type");

  $type = uri_unescape($type);
  $title = uri_unescape($title);

  # Works around an ecore bug which throws an ISE on non-existent nodetype
  my $nodetype = $self->APP->node_by_name($type,"nodetype");
  unless($nodetype)
  {
    return [$self->HTTP_NOT_FOUND];
  }

  my $node = $self->APP->node_by_name(uri_unescape($title), uri_unescape($type));

  unless($node)
  {
    return [$self->HTTP_NOT_FOUND];
  }

  my $user = $self->APP->node_by_id($REQUEST->USER->{user_id});
  if($node->can_read_node($user))
  {
    return [$self->HTTP_OK, $node->json_display($user)];
  }else{
    $self->devLog("Could not read node per can_read_node. Returning FORBIDDEN");
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
      $self->devLog("Node class of ".$node->typeclass." does not match API class $class (and is not node). Returning NOT FOUND");
      return [$self->HTTP_NOT_FOUND];
    }
  }

  return [$self->HTTP_OK, $node->json_display($user)];
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $user = $self->APP->node_by_id($REQUEST->USER->{node_id});

  if($user->is_guest)
  {
    $self->devLog("Guest cannot access create endpoint");
    return [$self->HTTP_UNAUTHORIZED];
  }

  unless($self->CREATE_ALLOWED)
  {
    $self->devLog("Creation flag explicitly off for API, returning UNIMPLEMENTED");
    return [$self->HTTP_UNIMPLEMENTED];
  }

  my $newnode = $self->APP->node_new($self->node_type);

  unless($newnode)
  {
    $self->devLog("Returning unimplemented due to lack of good node skeleton for type: ".$self->node_type);
    return [$self->HTTP_UNIMPLEMENTED];
  }

  unless($newnode->can_create_type($user))
  {
    $self->devLog("User ".$user->title." can't create node for of type ".$self->node_type.". Returning FORBIDDEN");
    return [$self->HTTP_FORBIDDEN];
  }

  my $postdata = $REQUEST->JSON_POSTDATA;
  my $allowed_data = {};

  foreach my $key (@{$self->field_whitelist},"title")
  {
    if(exists($postdata->{$key}))
    {
      $allowed_data->{$key} = $postdata->{$key};
    }
  }

  unless(exists $allowed_data->{title})
  {
    $self->devLog("No title in POST data for node creation. Returning BAD REQUEST");
    return [$self->HTTP_BAD_REQUEST];
  }

  my $node = $newnode->insert($user, $allowed_data);

  unless($node)
  {
    $self->devLog("Didn't get a good node back from the insert routine, having to return UNAUTHORIZED");
    return [$self->HTTP_UNAUTHORIZED];
  }

  return [$self->HTTP_OK, $node->json_display($user)];
}

sub update
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $self->APP->node_by_id($REQUEST->USER->{node_id});
  
  if($user->is_guest)
  { 
    $self->devLog("Guest cannot access update endpoint");
    return [$self->HTTP_UNAUTHORIZED];
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

  my $node = $self->APP->node_by_id(int($id));

  # We need a cleanly blessed node object to continue
  unless($node)
  {
    $self->devLog("Could not get blessed node reference for id: $id. Returning UNIMPLEMENTED");
    return [$self->HTTP_UNIMPLEMENTED];
  }

  my $user = $self->APP->node_by_id($REQUEST->USER->{user_id});
  if($node->can_read_node($user))
  {
    return $self->$orig($node,$user);
  }else{
    $self->devLog("Could not read node per can_read_node. Returning FORBIDDEN");
    return [$self->HTTP_FORBIDDEN];
  }

}

sub delete
{
  my ($self, $REQUEST, $id) = @_;

  my $node = $self->APP->node_by_id($id);

  unless($node)
  {
    $self->devLog("Could not get blessed node reference for id: $id. Returning NOT FOUND");
    return [$self->HTTP_NOT_FOUND];
  }

  my $user = $self->APP->node_by_id($REQUEST->USER->{user_id});
  my $node_id = $node->node_id;
  if($node->can_delete_node($user))
  {
    $node->delete($user);
    return [$self->HTTP_OK, {"deleted" => $node_id}];
  }else{
    $self->devLog("Could not delete node per can_delete_node. Returning FORBIDDEN");
    return [$self->HTTP_FORBIDDEN];
  }
}

sub field_whitelist
{
  my ($self) = @_;
  return [];
}

around ['get_id'] => \&_can_read_okay;
 
__PACKAGE__->meta->make_immutable;
1;


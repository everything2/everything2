package Everything::API::nodes;

use strict;
use Moose;

extends 'Everything::API';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 0);

sub routes
{ 
  return {
  "/" => "get",
  "/:id" => "get_id(:id)",
  "/:id/action/delete" => "delete(:id)",
  "create" => "create"
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
  my ($self, $REQUEST, $version) = @_;

  my $user = $self->APP->node_by_id($REQUEST->USER->{node_id});

  if($user->is_guest)
  {
    $self->devLog("Guest cannot access create endpoint");
    return [$self->HTTP_UNAUTHORIZED] if $user->is_guest;
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
  my $node = $newnode->insert($user, $self->parse_postdata($REQUEST));

  unless($node)
  {
    $self->devLog("Didn't get a good node back from the insert routine, having to return UNAUTHORIZED");
    return [$self->HTTP_UNAUTHORIZED] unless $node;
  }

  return [$self->HTTP_OK, $node->json_display($user)];
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
  my ($orig, $self, $REQUEST, $version, $id) = @_;

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
  my ($self, $REQUEST, $verison, $id) = @_;

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

around ['get_id'] => \&_can_read_okay;
 
__PACKAGE__->meta->make_immutable;
1;


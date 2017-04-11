package Everything::API::messages;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes
{ 
  return {
  ":id/action/archive" => "archive(:id)",
  ":id/action/delete" => "delete(:id)",
  ":id/action/unarchive" => "unarchive(:id)",
  "create" => "create",
  "/" => "get_all",
  "/:id" => "get_single_message(:id)"
  }
}

sub get_all
{
  my ($self, $REQUEST, $version, $id) = @_;
  if($self->APP->isGuest($REQUEST->USER))
  {
    return [$self->HTTP_FORBIDDEN];
  }
  my $limit = int($REQUEST->cgi->param("limit")) || undef;
  my $offset = int($REQUEST->cgi->param("offset")) || undef;
  return [$self->HTTP_OK, $self->APP->get_messages($REQUEST->USER,$limit, $offset)];
}

sub get_single_message
{
  my($self, $REQUEST, $version, $id) = @_;
  if($self->APP->isGuest($REQUEST->USER))
  {
    $self->devLog("Can't access message due to being Guest");
    return [$self->HTTP_FORBIDDEN];
  }
  my $message = $self->APP->get_message(int($id));
  unless($message)
  {
    $self->devLog("Can't access message due to it not being a valid message");
    return [$self->HTTP_FORBIDDEN];
  }

  if($self->APP->can_see_message($REQUEST->USER, $message))
  {
    return [$self->HTTP_OK, $message];
  }else{
    $self->devLog("Can't see the message due to it failing can_see_message");
    return [$self->HTTP_FORBIDDEN];
  }
}

sub archive
{
  my ($self, $REQUEST, $version, $id) = @_;
  if($self->APP->isGuest($REQUEST->USER))
  {
    return [$self->HTTP_FORBIDDEN];
  }

  return [$self->HTTP_OK, ["Got archive: $id"]];
}

sub unarchive
{
  my ($self, $REQUEST, $version, $id) = @_;

  return [$self->HTTP_OK, ["Got unarchive: $id"]];
}

sub delete
{
  my ($self, $REQUEST, $version, $id) = @_;

  return [$self->HTTP_OK, ["Got delete: $id"]];
}
1;

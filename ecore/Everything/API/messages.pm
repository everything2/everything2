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
  "/" => "get",
  "/:id" => "get(:id)"
  }
}

sub get
{
  my ($self, $REQUEST, $version, $id) = @_;
  if($self->APP->isGuest($REQUEST->USER))
  {
    return [$self->HTTP_FORBIDDEN];
  }
  return [$self->HTTP_OK, $self->APP->get_messages($REQUEST->USER)];
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

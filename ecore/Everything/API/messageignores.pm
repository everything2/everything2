package Everything::API::messageignores;

use strict;
use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes
{ 
  return {
  ":id/action/delete" => "delete(:id)",
  "create" => "create",
  "/" => "get_all",
  "/:id" => "get_single(:id)"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  return [$self->HTTP_OK, $self->APP->get_message_ignores($REQUEST->USER)];
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $data = $self->parse_postdata($REQUEST);

  if($data->{ignore})
  {
    $data->{ignore_id} = $self->DB->getNode($data->{ignore},"usergroup") || 
      $self->DB->getNode($data->{ignore},"user");
  }

  if(int($data->{ignore_id}))
  {
    return [$self->HTTP_OK, $self->APP->message_ignore_set($REQUEST->USER, $data->{ignore_id},1)];
  }else{
    return [$self->HTTP_BAD_REQUEST];
  }

  return [$self->HTTP_OK];
}

sub get_single
{
  my ($self, $REQUEST, $id) = @_;

  my $ignore = $self->APP->is_ignoring_messages($REQUEST->USER,int($id));
  if($ignore)
  {
    return [$self->HTTP_OK, $ignore];
  }else{
    return [$self->HTTP_NOT_FOUND];
  }
}

sub delete
{
  my ($self, $REQUEST, $id) = @_;

  return [$self->HTTP_OK, $self->APP->message_ignore_set($REQUEST->USER,int($id),0)];
}

around ['get_all','create','get_single','delete'] => \&Everything::API::unauthorized_if_guest;
__PACKAGE__->meta->make_immutable;
1;

package Everything::API::messageignores;

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

  return [$self->HTTP_OK, $REQUEST->user->message_ignores];
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;

  if($data->{ignore})
  {
    $data->{ignore_id} = $self->DB->getNode($data->{ignore},"usergroup") || 
      $self->DB->getNode($data->{ignore},"user");
  }

  if(int($data->{ignore_id}))
  {
    return [$self->HTTP_OK, $REQUEST->user->set_message_ignore($data->{ignore_id}, 1)];
  }else{
    return [$self->HTTP_BAD_REQUEST];
  }

  return [$self->HTTP_OK];
}

sub get_single
{
  my ($self, $REQUEST, $id) = @_;

  my $ignore = $REQUEST->user->is_ignoring_messages(int($id));
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

  return [$self->HTTP_OK, $REQUEST->user->set_message_ignore(int($id),0)];
}

around ['get_all','create','get_single','delete'] => \&Everything::API::unauthorized_if_guest;
__PACKAGE__->meta->make_immutable;
1;

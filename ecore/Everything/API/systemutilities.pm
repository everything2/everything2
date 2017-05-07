package Everything::API::systemutilities;

use Moose;
extends 'Everything::API';

sub routes
{
  return {"/roompurge" => "roompurge"};
}

sub roompurge
{
  my ($self, $REQUEST) = @_;
  $self->devLog("Received roompurge request from ".$REQUEST->user->title);
  if(!$REQUEST->user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN];
  }
  my $to_delete = $self->DB->sqlSelect("count(*)","room");
  $self->devLog("Purging ".$self->JSON->encode([$to_delete])." from room");

  $self->DB->sqlDelete("room","");
  return [$self->HTTP_OK, {purged => $to_delete}];
}

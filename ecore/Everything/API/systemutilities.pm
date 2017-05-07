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
  my $user = $self->APP->node_by_id($REQUEST->USER->{user_id});
  $self->devLog("Received roompurge request from ".$user->title);
  if(!$user or !$user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN];
  }
  my $to_delete = $self->DB->sqlSelect("count(*)","room");
  $self->devLog("Purging ".$self->JSON->encode([$to_delete])." from room");

  $self->DB->sqlDelete("room","");
  return [$self->HTTP_OK, {purged => $to_delete}];
}

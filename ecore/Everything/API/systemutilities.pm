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

  if(!$REQUEST->user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN];
  }
  my $to_delete = $self->DB->sqlSelect("count(*)","room");

  $self->DB->sqlDelete("room","");
  return [$self->HTTP_OK, {purged => $to_delete}];
}

1;

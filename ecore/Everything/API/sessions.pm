package Everything::API::sessions;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes
{
  return {
  "create" => "create",
  "destroy" => "destroy",
  "/" => "get",
  }
}
sub get
{
  my ($self, $REQUEST) = @_;

  my $userinfo = {
    "user_id" => $REQUEST->USER->{user_id},
    "username" => $REQUEST->USER->{title},
    "is_guest" => ($self->APP->isGuest($REQUEST->USER) || 0)
  };

  unless($userinfo->{is_guest})
  {
    $userinfo->{level} = $self->APP->getLevel($REQUEST->USER) || 0;
    $userinfo->{cools} = $REQUEST->USER->{cools} || 0;
    $userinfo->{votes} = $REQUEST->USER->{votesleft} || 0;
  }

  return [$self->HTTP_OK, $userinfo]
}

sub create
{
  my ($self, $REQUEST) = @_;
  my $data = $self->parse_postdata($REQUEST);

  if($data->{username} and $data->{passwd})
  {
    my $user = $self->DB->getNode($data->{username},"user");
    my $salted = $self->APP->hashString($data->{passwd}, $user->{salt});
    if($salted eq $user->{passwd})
    {
      return [$self->HTTP_OK, {"user_id" => $user->{user_id}, "username" => $user->{title}}];
    }else{
      return [$self->HTTP_FORBIDDEN];
    }
  }else{
    return [$self->HTTP_BAD_REQUEST];
  }
}

sub destroy
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

1;

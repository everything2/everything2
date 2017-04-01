package Everything::API::login;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub get
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_OK,
    {
      "user_id" => $REQUEST->USER->{user_id},
      "username" => $REQUEST->USER->{title},
    }
  ];
}

sub post
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

1;

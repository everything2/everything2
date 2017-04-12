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

sub user_api_structure
{
  my ($self, $REQUEST) = @_;

  my $userinfo = {
    "user_id" => int($REQUEST->USER->{user_id}),
    "username" => $REQUEST->USER->{title},
    "is_guest" => ($self->APP->isGuest($REQUEST->USER) || 0)
  };

  unless($userinfo->{is_guest})
  {
    my $level = $self->APP->getLevel($REQUEST->USER) || 0;

    $userinfo->{level} = int($level);
    $userinfo->{leveltitle} = $self->APP->getLevelTitle($level);
    $userinfo->{cools} = int($REQUEST->VARS->{cools}) || 0;
    $userinfo->{votes} = int($REQUEST->USER->{votesleft}) || 0;

    my $bookmarks = $self->APP->get_bookmarks($REQUEST->USER) || [];
    if(scalar @$bookmarks)
    {
      $userinfo->{bookmarks} = $bookmarks;
    }

    my $powers = [];
    push @$powers, "ed" if $self->APP->isEditor($REQUEST->USER);
    push @$powers, "admin", if $self->APP->isAdmin($REQUEST->USER);
    push @$powers, "chanop" if $self->APP->isChanop($REQUEST->USER);

    # Admins don't have these powers by default, not because they can't, but because not all care.
    push @$powers, "client" if $self->APP->isClientDeveloper($REQUEST->USER, "nogods");
    push @$powers, "dev", if $self->APP->isDeveloper($REQUEST->USER, "nogods");
    if(scalar @$powers)
    {
      $userinfo->{powers} = $powers;
    }

    my $numwriteups = $REQUEST->VARS->{numwriteups};
    if($numwriteups)
    {
      $userinfo->{numwriteups} = int($numwriteups);
    }
  }

  return $userinfo;
}

sub get
{
  my ($self, $REQUEST, $version) = @_;
  return [$self->HTTP_OK, $self->user_api_structure($REQUEST)];
}

sub create
{
  my ($self, $REQUEST, $version) = @_;
  my $data = $self->parse_postdata($REQUEST);

  if($data->{username} and $data->{passwd})
  {
    if($REQUEST->login(username => $data->{username}, pass => $data->{passwd}))
    {
      if(!$self->APP->isGuest($REQUEST->USER))
      {
        return [$self->HTTP_OK, $self->user_api_structure($REQUEST), {-cookie => $self->make_cookie($REQUEST)}];
      }else{
        $self->devLog("Login came back as guest user, meaning bad password, returning 403 FORBIDDEN");
        return [$self->HTTP_FORBIDDEN];
      }
    }else{
      $self->devLog("Everything::Request::login returned false, returning 400 BAD REQUEST");
      return [$self->HTTP_BAD_REQUEST];
    }
  }else{
    $self->devLog("Could not find username and passwd in JSON, returning 400 BAD REQUEST");
    return [$self->HTTP_BAD_REQUEST];
  }
}

sub make_cookie
{
  my ($self, $REQUEST) = @_;
  return $REQUEST->cookie(-name => $self->CONF->cookiepass, -value => $REQUEST->USER->{title}."|".$REQUEST->USER->{passwd});
}

sub destroy
{
  my ($self, $REQUEST, $version) = @_;

  # We only need to destroy the cookie; the API exit point is user neutral after this point
  $REQUEST->USER($self->DB->getNodeById($self->CONF->guest_user));
  return [$self->HTTP_OK,$self->user_api_structure($REQUEST), {"cookie" => $REQUEST->cookie(-name => $self->CONF->cookiepass, -value => "")}];
}

1;

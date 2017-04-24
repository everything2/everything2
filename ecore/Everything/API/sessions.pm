package Everything::API::sessions;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes
{
  return {
  "create" => "create",
  "delete" => "delete",
  "/" => "get",
  }
}

sub user_api_structure
{
  my ($self, $REQUEST) = @_;

  my $user = $self->APP->node_by_id($REQUEST->USER->{node_id});
  my $is_guest = $user->is_guest;

  my $userinfo = {
    "display" => {"is_guest" => int($is_guest)}
  };

  unless($user->is_guest)
  {
    my $powers = [];
    push @$powers, "ed" if $user->is_editor;
    push @$powers, "admin", if $user->is_admin;
    push @$powers, "chanop" if $user->is_chanop;
    push @$powers, "client" if $user->is_clientdev;
    push @$powers, "dev", if $user->is_developer;
    if(scalar @$powers)
    {
      $userinfo->{display}->{powers} = $powers;
    }
    foreach my $spend("coolsleft","votesleft")
    {
      my $s = $user->$spend;
      if($s)
      {
        $userinfo->{display}->{$spend} = $s;
      }
    } 
     
    $userinfo->{user} = $user->json_display;
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

sub delete
{
  my ($self, $REQUEST, $version) = @_;

  # We only need to delete the cookie; the API exit point is user neutral after this point
  $REQUEST->USER($self->DB->getNodeById($self->CONF->guest_user));
  return [$self->HTTP_OK,$self->user_api_structure($REQUEST), {"cookie" => $REQUEST->cookie(-name => $self->CONF->cookiepass, -value => "")}];
}

1;

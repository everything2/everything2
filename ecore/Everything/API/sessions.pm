package Everything::API::sessions;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

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

  my $is_guest = $REQUEST->is_guest;

  my $user = $REQUEST->user;
  my $userinfo = {
    "display" => {"is_guest" => int($is_guest)}
  };

  unless($user->is_guest)
  {
    my $powers = [];
    push @$powers, "ed" if $REQUEST->is_editor;
    push @$powers, "admin", if $REQUEST->is_admin;
    push @$powers, "chanop" if $REQUEST->is_chanop;
    push @$powers, "client" if $REQUEST->is_clientdev;
    push @$powers, "dev", if $REQUEST->is_developer;
    if(scalar @$powers)
    {
      $userinfo->{display}->{powers} = $powers;
    }
    foreach my $property ("coolsleft","votesleft","infravision","newgp","newxp","writeups_to_level","xp_to_level")
    {
      my $p = $user->$property;
      if($p)
      {
        $userinfo->{display}->{$property} = $p;
      }
    } 
     
    $userinfo->{user} = $user->json_display;
  }

  return $userinfo;
}

sub get
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_OK, $self->user_api_structure($REQUEST)];
}

sub create
{
  my ($self, $REQUEST) = @_;
  my $data = $REQUEST->JSON_POSTDATA;

  if($data->{username} and $data->{passwd})
  {
    if($REQUEST->login(username => $data->{username}, pass => $data->{passwd}))
    {
      if(!$REQUEST->is_guest)
      {
        return [$self->HTTP_OK, $self->user_api_structure($REQUEST)];
      }else{
        # Login came back as guest user, meaning bad password, returning 403 FORBIDDEN
        return [$self->HTTP_FORBIDDEN];
      }
    }else{
      # Everything::Request::login returned false, returning 400 BAD REQUEST
      return [$self->HTTP_BAD_REQUEST];
    }
  }else{
    # Could not find username and passwd in JSON, returning 400 BAD REQUEST
    return [$self->HTTP_BAD_REQUEST];
  }
}


sub delete
{
  my ($self, $REQUEST) = @_;

  # We only need to delete the cookie; the API exit point is user neutral after this point
  $REQUEST->logout;
  return [$self->HTTP_OK,$self->user_api_structure($REQUEST), {"cookie" => $REQUEST->cookie(-name => $self->CONF->cookiepass, -value => "")}];
}

1;

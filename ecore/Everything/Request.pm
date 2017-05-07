package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use CGI;

with 'Everything::Globals';

has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "CGI", handles => ["param", "header", "cookie","url","request_method","path_info"], is => "rw");
has 'USER' => (lazy => 1, builder => "_build_user", isa => "HashRef", is => "rw", "trigger" => \&_user_trigger);
has 'VARS' => (lazy => 1, builder => "_build_vars", isa => "HashRef", is => "rw");

has 'user' => (lazy => 1, builder => "_build_blessed_user", isa => "Everything::Node::user", is => "rw", handles => ["is_guest","is_admin","is_developer","is_chanop","is_clientdev","is_editor"]);

# Pageload is going to go away
has 'PAGELOAD' => (isa => "HashRef", builder => "_build_pageload", is => "rw");

has 'NODE' => (is => "rw", isa => "HashRef");

sub POSTDATA
{
  my $self = shift;
  my $encoding = $ENV{CONTENT_TYPE};

  if($encoding eq "application/json")
  {
    return $self->param("POSTDATA");
  }elsif($encoding eq "application/x-www-form-urlencoded")
  {
    return $self->param("data");
  }
}

sub JSON_POSTDATA
{
  my $self = shift;
  my $postdata = $self->POSTDATA;
  $self->devLog("Parsing POST data: ".$postdata);
  return {} unless $postdata;
  return $self->JSON->decode($postdata);
}

sub _build_user
{
  my $self = shift;
  return $self->get_current_user;
}

sub _user_trigger
{
  my ($self, $user, $old_user) = @_;
  $self->user($self->APP->node_by_id($user->{node_id}));
}

sub _build_blessed_user
{
  my $self = shift;

  return $self->APP->node_by_id($self->USER->{node_id});
}

sub _build_pageload
{
  my $self = shift;
  return {};
}

sub _build_vars
{
  my $self = shift;
  return Everything::getVars($self->USER);
}

sub _build_cgi
{
  my $self = shift;

  my $cgi;
	
  if ($ENV{SCRIPT_NAME}) { 
    $cgi = new CGI;
  } else {
    $cgi = new CGI(\*STDIN);
  }

  if (not defined ($cgi->param("op")))
  {
    $cgi->param("op", "");
  }

  return $cgi;
}

sub isGuest
{
  my $self = shift;
  return $self->APP->isGuest($self->USER);
}

sub isAdmin
{
  my $self = shift;
  return $self->APP->isAdmin($self->USER);
}

sub isEditor
{
  my $self = shift;
  return $self->APP->isEditor($self->USER);
}

sub isDeveloper
{
  my $self = shift;
  return $self->APP->isDeveloper($self->USER);
}

sub isClientDeveloper
{
  my $self = shift;
  return $self->APP->isClientDeveloper($self->USER);
}

sub login
{
  my $self = shift;
  $self->USER($self->get_current_user(@_));
  $self->VARS(Everything::getVars($self->USER));
  return $self->USER;
}

# Completely reimplements the CGI-entangled logic of Everything::Application::confirmUser

sub get_current_user
{
  my $self = shift;
  my $inputs = {@_};

  my $username = $inputs->{username};
  my $pass = $inputs->{pass};
  my $originalpass = $pass;
  my $cookie = undef;

  $self->devLog("Got get_current_user with u/p: $username, $pass");

  unless ($username && $pass)
  {
    $cookie = $self->cookie($self->CONF->cookiepass);
    if($cookie)
    {
      ($username, $pass) = split(/\|/, $cookie);
      $self->devLog("Cookie found for '$username', attempting login from that");
    }
  }

  my $user = undef;

  if($username)
  {
    $user = $self->APP->node_by_name($username, "user");
    unless($user)
    {
      $self->devLog("Could not get blessed node for user: '$username'");
    }
  }

  if($user)
  {
    if($user->locked)
    {
      $self->devLog("Account is locked: $username");
    }else{
       unless($cookie)
       {
          # Check for a password reset token
          if($self->param('token'))
          {
            $self->APP->checkToken($user->NODEDATA, $self->cgi);
          }

          if($pass)
          {
            $pass = $self->APP->hashString($pass, $user->salt);
          }
       }
      if($username && ($pass || $originalpass))
      {
        if($pass eq $user->passwd)
        {
          $self->devLog("Salted password accepted for user: ".$user->title); 
          $user = $user->NODEDATA;
          unless($cookie)
          {
            print $self->header({-cookie => $self->make_login_cookie($user)});
          }
        }else{
          $self->devLog("Salted password not accepted by default for user: ".$user->title);
          if($user->salt)
          {
            $self->devLog("User has salt available, therefore bad login");
            $user = undef;
          }else{
            $self->devLog("No salt available, therefore legacy password method");
            if(substr($originalpass, 0, 10) ne $user->passwd && $self->APP->urlDecode($cookie) ne $user->title.'|'.crypt($user->passwd, $user->title))
            {
                $self->devLog("Could not verify password with legacy method '".substr($originalpass, 0, 10)."' vs '".$user->passwd."'");
                $user = undef;
            }else{
                $user = $user->NODEDATA;
                $self->APP->updatePassword($user, $user->{passwd});
                unless($cookie)
                {
                  print $self->header({-cookie => $self->make_login_cookie($user)});
                }
                $self->devLog("Successfully updated password and logged in as: ".$user->{title});
            }
          }
        }
      }else{
        $self->devLog("Username and password not present, could not go any further. Username: $username Pass: $pass");
      }
    }
  }
  
  $user ||= $self->DB->getNodeById($self->CONF->guest_user);

  

  return $user if !$user || $self->APP->isGuest($user) || $self->param('ajaxIdle');
  
  # If we don't assign VARS here, then we will loop forever trying to bootstrap it
  $self->VARS(Everything::getVars($user));

  my $TIMEOUT_SECONDS = 4 * 60;

  my $sth = $self->DB->getDatabaseHandle()->prepare("CALL update_lastseen($$user{node_id});");
  $sth->execute();
  my ($seconds_since_last, $now) = $sth->fetchrow_array();
  $user->{lastseen} = $now;

  $self->APP->insertIntoRoom($$user{in_room}, $user, $self->VARS) if $seconds_since_last > $TIMEOUT_SECONDS;

  $self->APP->logUserIp($user, $self->VARS);
  return $user;
}

sub get_api_version
{
  my ($self) = @_;
 
  my $accept_header = $ENV{HTTP_ACCEPT}; 
  if(defined($accept_header) and my ($version) = $accept_header =~ /application\/vnd\.e2\.v(\d+)/)
  {
    $self->devLog("Explicitly requesting API version $version");
    return $version;
  }
  $self->devLog("No API version requested, defaulting to CURRENT_VERSION");
  return undef;
}

sub make_login_cookie
{
  my ($self, $user) = @_;
  my $expires = "";
  if($self->cgi->param("expires"))
  {
    $expires = $self->cgi->param("expires");
    $self->devLog("Got expires checkbox: $expires");
  }
  return $self->cookie(-name => $self->CONF->cookiepass, -value => $user->{title}."|".$user->{passwd}, -expires => $expires);
}

__PACKAGE__->meta->make_immutable;

1;

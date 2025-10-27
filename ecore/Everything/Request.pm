package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use CGI qw(-utf8);

with 'Everything::Globals';

has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "CGI", handles => ["param", "header", "cookie","url","request_method","path_info","script_name"], is => "rw");
has 'user' => (lazy => 1, builder => "_build_user", isa => "Everything::Node::user", is => "rw", handles => ["is_guest","is_admin","is_developer","is_chanop","is_clientdev","is_editor","VARS"]);

# Pageload is going to go away
has 'PAGELOAD' => (isa => "HashRef", default => sub { {} }, is => "rw");
has 'NODE' => (is => "rw", isa => "HashRef");

sub POSTDATA
{
  my $self = shift;
  my $encoding = $ENV{CONTENT_TYPE};

  $self->devLog("POST data encoding: $encoding");

  if($encoding =~ m|^application/json|)
  {
    $self->devLog("Detected 'application/json'");
    return $self->param("POSTDATA");
  }elsif($encoding =~ m|^application/x-www-form-urlencoded|)
  {
    $self->devLog("Detected x-www-form-urlencoded");
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

sub login
{
  my $self = shift;
  $self->user($self->get_current_user(@_));
  return $self->user;
}

sub logout
{
  my $self = shift;
  $self->user($self->APP->node_by_id($self->CONF->guest_user));
  return $self->user;
}

sub get_ip
{
  my $self = shift;
  return $self->APP->getIp;
}

sub get_current_user
{
  my $self = shift;
  my $inputs = {@_};

  my $username = $inputs->{username} || "";
  my $pass = $inputs->{pass} || "";
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
      $user = undef;
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
                $self->APP->updatePassword($user->NODEDATA, $user->passwd);
                unless($cookie)
                {
                  print $self->header({-cookie => $self->make_login_cookie($user)});
                }
                $self->devLog("Successfully updated password and logged in as: ".$user->title);
            }
          }
        }
      }else{
        $self->devLog("Username and password not present, could not go any further. Username: $username Pass: $pass");
  	$user = $self->APP->node_by_id($self->CONF->guest_user);
      }
    }
  }
  
  $user ||= $self->APP->node_by_id($self->CONF->guest_user);

  return $user if !$user || $user->is_guest || $self->param('ajaxIdle');
  
  my $TIMEOUT_SECONDS = 4 * 60;

  my $sth = $self->DB->getDatabaseHandle()->prepare("CALL update_lastseen(".$user->node_id.");");
  $sth->execute();
  my ($seconds_since_last, $now) = $sth->fetchrow_array();

  my $force_room_insert = 0;

  # User has never logged in before, so update_lastseen returns undef as first result
  if(not defined($seconds_since_last))
  {
    $force_room_insert = 1;
    $seconds_since_last = 0;
  }

  $user->NODEDATA->{lastseen} = $now;

  $self->APP->insertIntoRoom($user->in_room, $user->NODEDATA, $user->VARS) if($force_room_insert || $seconds_since_last > $TIMEOUT_SECONDS || $self->APP->inDevEnvironment);
  if($ENV{HTTP_USER_AGENT})
  {
    $user->VARS->{browser} = $ENV{HTTP_USER_AGENT};
  }

  # Upon successful log-in, write current browser to VARS
  $self->APP->logUserIp($user->NODEDATA, $user->VARS);
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
  return;
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
  return $self->cookie(-name => $self->CONF->cookiepass, -value => $user->title."|".$user->passwd, -expires => $expires);
}

sub truncated_params
{
  my ($self) = @_;

  my @params = $self->cgi->multi_param;

  my $outparams = {};

  foreach my $item (@params)
  {
    my $value = $self->cgi->param($item);
    $value = "" if not defined($value);
    $outparams->{$item} = substr($value,0,1024);
  }

  return $outparams;
}

__PACKAGE__->meta->make_immutable;

1;

package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use CGI;

has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "CGI", handles => ["param", "header", "cookie","url","request_method","path_info"], is => "rw");
has 'USER' => (lazy => 1, builder => "_build_user", isa => "HashRef", is => "rw");
has 'VARS' => (lazy => 1, builder => "_build_vars", isa => "HashRef", is => "rw");
has 'CONF' => (isa => "Everything::Configuration", is => "ro", required => 1);
has 'DB' => (isa => "Everything::NodeBase", is => "ro", required => 1);
has 'APP' => (isa => "Everything::Application", is => "ro", required => 1);


# Pageload is going to go away
has 'PAGELOAD' => (isa => "HashRef", builder => "_build_pageload", is => "rw");

has 'NODE' => (is => "rw", isa => "HashRef");

sub POSTDATA
{
  my $self = shift;
  return $self->cgi->param("POSTDATA");
}

sub _build_user
{
  my $self = shift;
  Everything::printLog("In _build_user");
  return $self->get_current_user;
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
  Everything::printLog("In get_current_user");
  $self->USER($self->get_current_user(@_));
  $self->VARS(Everything::getVars($self->USER));
}

sub get_current_user
{
  my $self = shift;
  my $inputs = {@_};

  Everything::printLog("In get_current_user");

  my $username = $inputs->{username};
  my $pass = $inputs->{pass};
  my $cookie = $inputs->{cookie};

  unless ($username && $pass)
  {
    $cookie = $self->cookie($self->CONF->cookiepass);
    ($username, $pass) = split(/\|/, $cookie) if $cookie;
  }

  my $user;
  if($username && $pass)
  {
    Everything::printLog("Trying confirmUser for: $username, $pass, $cookie");
    $user = $self->APP->confirmUser($username, $pass, $cookie, $self->cgi);
  }
  
  $user ||= $self->DB->getNodeById($self->CONF->guest_user);
  Everything::printLog("confirmUser returned: $user->{title}");

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

__PACKAGE__->meta->make_immutable;

1;

package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use CGI;

has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "CGI", handles => ["param", "header", "cookie"], is => "rw");
has 'USER' => (lazy => 1, builder => "_build_user", isa => "HashRef", is => "rw");
has 'VARS' => (lazy => 1, builder => "_build_vars", isa => "HashRef", is => "rw");
has 'CONF' => (isa => "HashRef", is => "rw");
has 'DB' => (isa => "Everything::NodeBase", is => "rw");
has 'APP' => (isa => "Everything::Application", is => "ro");
has 'PAGELOAD' => (isa => "HashRef", builder => "_build_pageload", is => "rw");

sub _build_user
{
  my $self = shift;
  return $self->login;
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

sub login
{
  my $self = shift;
  my $inputs = {@_};

  my $username = $inputs->{username};
  my $pass = $inputs->{pass};
  my $cookie = $inputs->{cookie};

  unless ($username && $pass)
  {
    $cookie = $self->cookie($self->CONF->{cookiepass}) || $self->param($self->CONF->{cookiepass});
    ($username, $pass) = split(/\|/, $cookie) if $cookie;
  }

  my $user = $self->APP->confirmUser($username, $pass, $cookie, $self->cgi) if $username && $pass;
  $user ||= $self->DB->getNodeById($self->CONF->{system}->{guest_user});

  $self->VARS(Everything::getVars($user));

  return $user if !$user || $self->APP->isGuest($user) || $self->param('ajaxIdle');

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

package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use CGI qw(-utf8);
use Encode qw(decode_utf8);

with 'Everything::Globals';

has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "CGI", handles => ["param", "header", "cookie","url","request_method","path_info","script_name"], is => "rw");
has 'user' => (lazy => 1, builder => "_build_user", isa => "Everything::Node::user", is => "rw", handles => ["is_guest","is_admin","is_developer","is_chanop","is_clientdev","is_editor","VARS"]);
has 'node' => (is => "rw", isa => "Everything::Node");

# Page class instance - allows reusing the same instance across display() and buildReactData()
# Critical for form-processing pages like Sign Up that cache state between calls
has 'page_class_instance' => (is => "rw");

has 'NODE' => (is => "rw", isa => "HashRef");

# Cache raw STDIN for PUT/PATCH/DELETE requests
# Must be read BEFORE CGI.pm is initialized, as CGI consumes STDIN
# This is initialized at BUILD time, not lazily
has '_raw_stdin_cache' => (is => "ro", default => '');

sub BUILD
{
  my $self = shift;
  my $method = uc($ENV{REQUEST_METHOD} || 'GET');
  my $content_length = $ENV{CONTENT_LENGTH} || 0;

  # For PUT/PATCH/DELETE with a body, read STDIN before CGI.pm can consume it
  if ($method =~ /^(PUT|PATCH|DELETE)$/ && $content_length > 0) {
    my $data = '';
    read(STDIN, $data, $content_length);
    $self->{_raw_stdin_cache} = $data;
  }

  return;
}

sub POSTDATA
{
  my $self = shift;
  my $encoding = $ENV{CONTENT_TYPE} || '';
  my $method = uc($ENV{REQUEST_METHOD} || 'GET');

  if($encoding =~ m|^application/json|)
  {
    # For PUT/PATCH/DELETE, use our cached STDIN (read at BUILD time)
    if ($method =~ /^(PUT|PATCH|DELETE)$/) {
      return $self->_raw_stdin_cache;
    }

    # For POST, CGI.pm handles it fine
    return $self->param("POSTDATA");
  }elsif($encoding =~ m|^application/x-www-form-urlencoded|)
  {
    return $self->param("data");
  }
}

sub JSON_POSTDATA
{
  my $self = shift;
  my $postdata = $self->POSTDATA;
  return {} unless $postdata;

  my $encoding = $ENV{CONTENT_TYPE} || '';

  # Only decode UTF-8 for application/json requests
  # For form-urlencoded, CGI.pm already handles character decoding
  if ($encoding =~ m|^application/json|)
  {
    $postdata = decode_utf8($postdata);
  }

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
  my $expires = $inputs->{expires} || "";  # For "remember me" - e.g., '+1y'
  my $originalpass = $pass;
  my $cookie = undef;

  unless ($username && $pass)
  {
    $cookie = $self->cookie($self->CONF->cookiepass);
    if($cookie)
    {
      ($username, $pass) = split(/\|/, $cookie);
    }
  }

  my $user = undef;

  if($username)
  {
    $user = $self->APP->node_by_name($username, 'user');
  }

  if($user)
  {
    if($user->locked)
    {
      # Account is locked
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
          # Salted password accepted
          unless($cookie)
          {
            print $self->header({-cookie => $self->make_login_cookie($user, $expires)});
          }
        }else{
          # Salted password not accepted by default for user
          if($user->salt)
          {
            # User has salt available, therefore bad login
            $user = undef;
          }else{
            # No salt available, therefore legacy password method
            if(substr($originalpass, 0, 10) ne $user->passwd && $self->APP->urlDecode($cookie) ne $user->title.'|'.crypt($user->passwd, $user->title))
            {
                # Could not verify password with legacy method
                $user = undef;
            }else{
                $self->APP->updatePassword($user->NODEDATA, $user->passwd);
                unless($cookie)
                {
                  print $self->header({-cookie => $self->make_login_cookie($user, $expires)});
                }
                # Successfully updated password and logged in
            }
          }
        }
      }else{
        # Username and password not present, could not go any further.
        $user = $self->APP->node_by_id($self->CONF->guest_user);
      }
    }
  }

  $user ||= $self->APP->node_by_id($self->CONF->guest_user);

  # Skip lastseen update for background/idle requests
  # Supports both query parameter (ajaxIdle=1) and header (X-Ajax-Idle: 1)
  my $is_idle_request = $self->param('ajaxIdle') || $ENV{HTTP_X_AJAX_IDLE};
  return $user if !$user || $user->is_guest || $is_idle_request;

  my $TIMEOUT_SECONDS = 4 * 60;

  # Atomically update user's lasttime and get seconds since last seen
  # This replaces the update_lastseen stored procedure
  my $dbh = $self->DB->getDatabaseHandle();
  my $user_id = $user->node_id;
  my ($seconds_since_last, $now);

  $dbh->begin_work;
  my $txn_ok = eval {
    my $sth = $dbh->prepare("
      SELECT TIMESTAMPDIFF(SECOND, lasttime, NOW()), NOW()
      FROM user
      WHERE user_id = ?
      FOR UPDATE
    ");
    $sth->execute($user_id);
    ($seconds_since_last, $now) = $sth->fetchrow_array();

    $dbh->do("UPDATE user SET lasttime = NOW() WHERE user_id = ?", undef, $user_id);

    $dbh->commit;
    1;
  };
  if (!$txn_ok) {
    my $rollback_ok = eval { $dbh->rollback; 1 };
  }

  my $force_room_insert = 0;

  # User has never logged in before, so seconds_since_last is undef
  if (not defined($seconds_since_last))
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
    return $version;
  }
  # No API version requested, defaulting to CURRENT_VERSION
  return;
}

sub make_login_cookie
{
  my ($self, $user, $expires) = @_;
  # Accept expires as parameter (from API login) or fall back to CGI param (legacy form login)
  $expires ||= $self->cgi->param('expires') || '';
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

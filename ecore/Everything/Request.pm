package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use Plack::Request;
use Everything::Request::PlackQuery;
use Encode qw(decode_utf8);

with 'Everything::Globals';

# The PSGI environment for the current request. app.psgi threads it in with
# `local $Everything::Request::PSGI_ENV = $env;` per request so the (new)
# Plack::Request backing can be built. Package-scoped + localized rather than a
# constructor arg so existing `Everything::Request->new` call sites are
# untouched during the migration.
our $PSGI_ENV;

# Despite the historical name, `cgi` is now the Plack-backed query object
# (Everything::Request::PlackQuery), NOT a CGI.pm instance: CGI is out of the
# request-parsing path. The accessor name and the $query global are kept so the
# ~600 call sites (`$query->param`, `$REQUEST->cgi->...`) are untouched.
has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "Everything::Request::PlackQuery", handles => ["param", "header", "cookie","url","request_method","path_info","script_name"], is => "rw");

# NEW (additive) Plack::Request backing over the PSGI env. Nothing live reads
# from it yet -- the site still runs entirely on the CGI object above. This is
# the leverage point the migration flips to once the parity harness proves the
# read surface agrees. Lazy + isolated so building it has no effect unless asked.
# NB: do NOT call body-reading accessors (->content/->body_parameters) on this in
# the live path while CGI is primary -- both read psgi.input and the body can
# only be consumed once. Body parity is exercised in the harness with fresh input.
has 'req' => (is => 'ro', isa => 'Plack::Request', lazy => 1, builder => '_build_req');
has 'user' => (lazy => 1, builder => "_build_user", isa => "Everything::Node::user", is => "rw", handles => ["is_guest","is_admin","is_developer","is_chanop","is_clientdev","is_editor","VARS"]);
has 'node' => (is => "rw", isa => "Everything::Node");

# Cookies (Set-Cookie value strings) produced as a SIDE EFFECT of the request flow
# -- chiefly login() on an explicit credential login. Historically login() printed
# the Set-Cookie header directly into the STDOUT capture; the return-based API path
# (Everything::APIRouter::output) bypasses that capture, so it reads these off the
# request and folds them into the returned Everything::Response instead. The page
# path (HTML.pm opLogin) still uses the print, so login() does BOTH (cheap, and the
# accumulator is simply ignored by the page path). See docs/api-driven-architecture.md.
has 'response_cookies' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

sub add_response_cookie
{
  my ($self, $cookie) = @_;
  push @{$self->response_cookies}, $cookie if defined $cookie;
  return;
}

# The normalized e2 blob, stashed by Everything::Controller::layout during a render.
# Everything::API::pagestate drives the real render path (route_node) and reads this off
# the request, so the facade serves the IDENTICAL payload the inline page emits -- for
# controller-class nodes (user/e2node/category/*_edit) whose contentData is built inside
# the controller, not by buildNodeInfoStructure. The render's HTML is discarded; only the
# blob is wanted. See docs/pagestate-design.md (2a).
has 'pagestate_e2' => (is => "rw", isa => "Maybe[HashRef]");

# The page <head> metadata PRODUCER (an Everything::PageMetadata), stashed by
# Everything::Controller::layout. We stash the producer, not its computed hashref, so a
# normal pageload never pays for ->as_hashref (which rebuilds the JSON-LD graph -- and runs
# a category member COUNT) when nothing reads it. Everything::API::pagestate calls
# ->as_hashref and merges the result into the blob it returns -- the API path is the only
# consumer (React setting <head> on client navigation). Kept OUT of the e2 blob on purpose:
# the inline server render already emits the <head> in HTML, so inlining meta would just
# duplicate the JSON-LD bytes in every hydration payload. See docs/pagestate-design.md.
has 'pagestate_meta' => (is => "rw", isa => "Maybe[Object]");

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

    # For POST, read the raw JSON body from the Plack request. CGI.pm used to
    # expose an unparsed body as the pseudo-param 'POSTDATA'; Plack::Request has
    # no such pseudo-param, so go to the body directly via ->content. (This is
    # the change the CGI->Plack backing flip requires for JSON POSTs -- the
    # sessions/login + every JSON-body API endpoint depends on it.)
    return $self->req->content;
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

# The PSGI env for this request: the threaded one under Starman, or a minimal
# env synthesized from %ENV for non-PSGI contexts (cron/CLI/tests that did not
# thread one). Body reads in the fallback default to empty -- callers that need a
# real body in those contexts thread a proper env (the harness/tests do).
sub psgi_env
{
  my $self = shift;
  return $PSGI_ENV if $PSGI_ENV;

  my %env = %ENV;
  unless ($env{'psgi.input'})
  {
    open(my $in, '<', \(my $empty = '')) or die "psgi_env input: $!";
    $env{'psgi.input'} = $in;
  }
  $env{'psgi.url_scheme'} //= ($ENV{HTTPS} ? 'https' : 'http');
  $env{'REQUEST_METHOD'}  //= 'GET';
  return \%env;
}

sub _build_req
{
  my $self = shift;
  return Plack::Request->new($self->psgi_env);
}

sub _build_cgi
{
  my $self = shift;

  # The query object is now Plack-backed. It shares the one Plack::Request with
  # $self->req (a single request parse). CGI.pm is no longer constructed here;
  # the old `new CGI` / `new CGI(\*STDIN)` SCRIPT_NAME gate is obsolete because
  # Plack::Request reads the body from the PSGI env's psgi.input directly.
  my $query = Everything::Request::PlackQuery->new(req => $self->req);

  # Preserve the historical default: `op` is always defined. Many call sites do
  # `$query->param('op') eq '...'`, which would warn/misbehave on undef. CGI's
  # _build_cgi set this; keep it on the mutable param table.
  if (not defined($query->param("op")))
  {
    $query->param("op", "");
  }

  return $query;
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
            my $login_cookie = $self->make_login_cookie($user, $expires);
            print $self->header({-cookie => $login_cookie});  # page path (HTML.pm opLogin -> capture)
            $self->add_response_cookie($login_cookie);        # return-based API path
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
                  my $login_cookie = $self->make_login_cookie($user, $expires);
                  print $self->header({-cookie => $login_cookie});  # page path (HTML.pm opLogin -> capture)
                  $self->add_response_cookie($login_cookie);        # return-based API path
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
  # IMPORTANT: Always set path=/ so cookie works site-wide and matches opLogout
  # SameSite=Lax is explicit to prevent privacy extensions from stripping cookies
  # without clear SameSite attributes (browsers default to Lax but extensions may not)
  return $self->cookie(-name => $self->CONF->cookiepass, -value => $user->title."|".$user->passwd, -expires => $expires, -path => '/', -samesite => 'Lax');
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

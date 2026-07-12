package Everything::API::users;

use Moose;
extends 'Everything::API::nodes';

has 'UPDATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

around 'routes' => sub {
  my ($orig, $self) = @_;

  my $routes = $self->$orig;
  $routes->{'lookup'} = 'lookup';
  $routes->{'confirm'} = 'confirm';

  return $routes;
};

# POST /api/users/confirm
# Finalize an account activation or password reset from an emailed token link.
# Body: { username, passwd, token, action ('activate'|'reset'), expiry }
# Validates the token, sets the password, logs the user in, and on activation
# sends the Virgil welcome PM. Replaces the legacy op=login confirm flow (the
# ConfirmPassword superdoc). #4335
sub confirm
{
  my ($self, $REQUEST) = @_;

  my $APP = $self->APP;
  my $DB  = $self->DB;

  my $data = $REQUEST->JSON_POSTDATA;
  $data = {} unless ref $data eq 'HASH';

  my $username = defined $data->{username} ? $data->{username} : '';
  my $passwd   = defined $data->{passwd}   ? $data->{passwd}   : '';
  my $token    = defined $data->{token}    ? $data->{token}    : '';
  my $action   = defined $data->{action}   ? $data->{action}   : '';
  my $expiry   = defined $data->{expiry}   ? $data->{expiry}   : '';
  my $expires  = defined $data->{expires}  ? $data->{expires}  : '';  # "stay logged in" cookie duration

  # This endpoint returns only { success, state } (+ backend-derived profileUrl on activation).
  # The human-readable copy for each state lives in React (ConfirmPassword STATE_COPY, #4511),
  # keyed on state -- the same map the server-rendered Page path uses.

  # Required parameters
  unless ($token && $action && $username) {
    return [$self->HTTP_OK, { success => 0, state => 'missing_params' }];
  }

  # Valid action
  unless ($action eq 'activate' || $action eq 'reset') {
    return [$self->HTTP_OK, { success => 0, state => 'invalid_action' }];
  }

  my $user = $DB->getNode($username, 'user');

  # Expired link. We no longer delete the unactivated account (policy: stop nuking expired
  # accounts on the request path -- cleanup is deferred to a safe/phased maintenance job,
  # #4476). Just report the expiry.
  if ($expiry && time() > $expiry) {
    return [$self->HTTP_OK, { success => 0, state => 'expired' }];
  }

  unless ($user) {
    return [$self->HTTP_OK, { success => 0, state => 'no_user' }];
  }

  if ($action eq 'activate' && $user->{acctlock}) {
    return [$self->HTTP_OK, { success => 0, state => 'locked' }];
  }

  # Validate the token + finalize (sets the password, security-logs the action).
  unless ($APP->checkToken($user, $action, $expiry, $passwd, $token)) {
    return [$self->HTTP_OK, { success => 0, state => 'login_required' }];
  }

  # Log in with the now-set password (login() adds the response cookie).
  my %login_args = (username => $username, pass => $passwd);
  $login_args{expires} = $expires if $expires;
  $REQUEST->login(%login_args);
  if ($REQUEST->is_guest || $REQUEST->user->title ne $username) {
    return [$self->HTTP_OK, { success => 0, state => 'login_required' }];
  }

  if ($action eq 'reset') {
    return [$self->HTTP_OK, { success => 1, state => 'success_reset' }];
  }

  # Account activation: send the Virgil welcome PM.
  my $virgil = $DB->getNode('Virgil', 'user');
  if ($virgil) {
    # sendPrivateMessage($author_user_hashref, $recipient_node_id, $message)
    $APP->sendPrivateMessage(
      $virgil,
      $REQUEST->user->NODEDATA->{node_id},
      q|Welcome to E2! We hope you're enjoying the site. If you haven't already done so, we recommend reading both [E2 Quick Start] and [Links on Everything2] before you start writing anything. If you have any questions or need help, feel free to ask any editor (editors have a $ next to their names in the Other Users list)|,
    );
  }

  return [$self->HTTP_OK, {
    success => 1, state => 'success_activate',
    profileUrl => "/node/" . $REQUEST->user->NODEDATA->{node_id},
  }];
}

# Look up a user by username
# GET /api/users/lookup?username=foo
sub lookup
{
  my ($self, $REQUEST) = @_;

  my $username = $REQUEST->cgi->param('username') || '';
  $username =~ s/^\s+|\s+$//g;

  unless ($username) {
    return [$self->HTTP_OK, { success => 0, error => 'Missing username parameter' }];
  }

  # Look up the user by exact title match
  my $user = $self->DB->getNode($username, 'user');
  unless ($user) {
    return [$self->HTTP_OK, { success => 0, error => "User '$username' not found" }];
  }

  return [$self->HTTP_OK, {
    success => 1,
    user_id => int($user->{node_id}),
    username => $user->{title}
  }];
}

__PACKAGE__->meta->make_immutable;
1;

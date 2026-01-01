package Everything::API::sanctify;

use Moose;
extends 'Everything::API';

=head1 Everything::API::sanctify

API for the Sanctify feature - allows users to gift GP to other users.

Requirements:
- User must be Level 11+ (or Editor)
- User must have at least 10 GP
- User must not have GPoptout enabled
- Cannot sanctify yourself (unless admin)

Actions:
- Transfers 10 GP from giver to recipient
- Increments recipient's sanctity count
- Sends Cool Man Eddie notification

=cut

sub route {
  my ($self, $REQUEST, $extra) = @_;
  my $method = lc($REQUEST->request_method());

  my %routes = (
    'status' => 'status',
    'give'   => 'give',
  );

  if (exists $routes{$extra}) {
    my $handler = $routes{$extra};
    return $self->$handler($REQUEST);
  }

  return [$self->HTTP_NOT_FOUND, { error => 'Unknown route' }];
}

# GET /api/sanctify/status - Get user's sanctify eligibility
sub status {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;

  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in to sanctify users.'
    }];
  }

  my $USER = $user->NODEDATA;
  my $VARS = $user->VARS;
  my $level = $APP->getLevel($USER);
  my $is_editor = $APP->isEditor($USER);

  my $min_level = 11;
  my $sanctify_amount = 10;

  my $can_sanctify = 1;
  my $reason = '';

  if ($VARS->{GPoptout}) {
    $can_sanctify = 0;
    $reason = 'You have opted out of the GP system.';
  } elsif ($level < $min_level && !$is_editor) {
    $can_sanctify = 0;
    $reason = "You must be at least Level $min_level to sanctify users.";
  } elsif ($USER->{GP} < $sanctify_amount) {
    $can_sanctify = 0;
    $reason = "You need at least $sanctify_amount GP to sanctify a user.";
  }

  return [$self->HTTP_OK, {
    success => 1,
    canSanctify => $can_sanctify ? \1 : \0,
    reason => $reason,
    gp => int($USER->{GP} || 0),
    level => $level,
    sanctifyAmount => $sanctify_amount,
    minLevel => $min_level,
    gpOptOut => $VARS->{GPoptout} ? \1 : \0,
  }];
}

# POST /api/sanctify/give - Sanctify another user (gift 10 GP)
sub give {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be logged in.' }];
  }

  my $USER = $user->NODEDATA;
  my $VARS = $user->VARS;
  my $level = $APP->getLevel($USER);
  my $is_editor = $APP->isEditor($USER);
  my $is_admin = $APP->isAdmin($USER);

  my $min_level = 11;
  my $sanctify_amount = 10;

  # Check GPoptout
  if ($VARS->{GPoptout}) {
    return [$self->HTTP_OK, { success => 0, error => 'You have opted out of the GP system.' }];
  }

  # Check level
  if ($level < $min_level && !$is_editor) {
    return [$self->HTTP_OK, { success => 0, error => "You must be at least Level $min_level to sanctify users." }];
  }

  # Check GP
  if ($USER->{GP} < $sanctify_amount) {
    return [$self->HTTP_OK, { success => 0, error => "You need at least $sanctify_amount GP to sanctify a user." }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $recipient_name = $data->{recipient};
  my $anonymous = $data->{anonymous} ? 1 : 0;

  unless ($recipient_name) {
    return [$self->HTTP_OK, { success => 0, error => 'You must specify a recipient.' }];
  }

  my $recipient = $DB->getNode($recipient_name, 'user');
  unless ($recipient) {
    return [$self->HTTP_OK, { success => 0, error => "User '$recipient_name' not found." }];
  }

  # Can't sanctify yourself (unless admin)
  if ($recipient->{user_id} == $USER->{user_id} && !$is_admin) {
    return [$self->HTTP_OK, { success => 0, error => 'You cannot sanctify yourself.' }];
  }

  # Perform the sanctification
  # 1. Increment recipient's sanctity
  $recipient->{sanctity} = ($recipient->{sanctity} || 0) + 1;
  $DB->updateNode($recipient, -1);

  # 2. Transfer GP
  $APP->adjustGP($recipient, $sanctify_amount);
  $APP->adjustGP($USER, -$sanctify_amount);

  # Refresh USER to get updated GP
  $DB->{cache}->removeNode($USER) if $DB->{cache};
  $USER = $DB->getNode($USER->{node_id});

  # 3. Log the action
  my $sanctify_node = $DB->getNode('Sanctify user', 'superdoc');
  $APP->securityLog($sanctify_node, $USER, "$USER->{title} sanctified $recipient->{title} with $sanctify_amount GP.");

  # 4. Send Cool Man Eddie message
  my $from = $anonymous ? '!' : " by [$USER->{title}]!";
  $self->_send_eddie_message(
    $recipient->{user_id},
    "Whoa! You've been [Sanctify|sanctified]$from"
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "You have sanctified $recipient->{title} with $sanctify_amount GP!",
    newGP => int($USER->{GP}),
    recipientSanctity => int($recipient->{sanctity}),
  }];
}

# Helper: Send Cool Man Eddie message
sub _send_eddie_message {
  my ($self, $recipient_id, $message) = @_;

  my $eddie = $self->DB->getNode('Cool Man Eddie', 'user');
  return unless $eddie;

  $self->APP->sendPrivateMessage(
    $eddie,
    { user_id => $recipient_id },
    $message
  );

  return;
}

__PACKAGE__->meta->make_immutable;

1;

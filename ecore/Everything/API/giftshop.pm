package Everything::API::giftshop;

use Moose;
use POSIX qw(floor);
use Time::Local qw(timelocal);
extends 'Everything::API';

=head1 Everything::API::giftshop

API for the E2 Gift Shop - allows users to purchase and give gifts using GP.

Features:
- Give stars to users (costs 25-75 GP based on level)
- Buy additional votes (1 GP per vote)
- Give votes to other users
- Give/buy C!s
- Buy/use topic tokens
- Buy/give easter eggs

=cut

sub route {
  my ($self, $REQUEST, $extra) = @_;
  my $method = lc($REQUEST->request_method());

  my %routes = (
    'status'    => 'status',
    'star'      => 'give_star',
    'buyvotes'  => 'buy_votes',
    'givevotes' => 'give_votes',
    'giveching' => 'give_ching',
    'buyching'  => 'buy_ching',
    'buytoken'  => 'buy_token',
    'settopic'  => 'set_topic',
    'buyeggs'   => 'buy_eggs',
    'giveegg'   => 'give_egg',
  );

  if (exists $routes{$extra}) {
    my $handler = $routes{$extra};
    return $self->$handler($REQUEST);
  }

  return [$self->HTTP_NOT_FOUND, { error => 'Unknown route' }];
}

# Helper: Calculate star cost based on user level
sub _star_cost {
  my ($self, $level) = @_;
  my $cost = 75 - (($level - 1) * 5);
  return $cost < 25 ? 25 : $cost;
}

# Helper: Check if user can buy a ching (24hr cooldown)
sub _can_buy_ching {
  my ($self, $VARS) = @_;
  return 1 unless $VARS->{chingbought};

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time - 86400);
  my $hours24 = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
    $year+1900, $mon+1, $mday, $hour, $min, $sec;

  return $VARS->{chingbought} le $hours24 ? 1 : 0;
}

# Helper: Get remaining cooldown time in minutes
sub _ching_cooldown_remaining {
  my ($self, $VARS) = @_;
  return 0 unless $VARS->{chingbought};

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time - 86400);
  my $hours24 = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
    $year+1900, $mon+1, $mday, $hour, $min, $sec;

  return 0 if $VARS->{chingbought} le $hours24;

  # Parse the chingbought timestamp
  my ($d, $t) = split(' ', $VARS->{chingbought});
  my ($chinghour, $chingmin, $chingsec) = split(':', $t);
  my ($chingyear, $chingmonth, $chingday) = split('-', $d);
  my $ching_time = timelocal($chingsec, $chingmin, $chinghour, $chingday, $chingmonth-1, $chingyear);

  # Parse hours24
  ($d, $t) = split(' ', $hours24);
  ($chinghour, $chingmin, $chingsec) = split(':', $t);
  ($chingyear, $chingmonth, $chingday) = split('-', $d);
  my $hour_time = timelocal($chingsec, $chingmin, $chinghour, $chingday, $chingmonth-1, $chingyear);

  my $timeDiff = $ching_time - $hour_time;
  return floor($timeDiff / 60);  # Return minutes
}

# Helper: Send Cool Man Eddie message
sub _send_eddie_message {
  my ($self, $recipient_id, $message) = @_;

  my $eddie = $self->DB->getNode('Cool Man Eddie', 'user');
  return unless $eddie;

  # sendPrivateMessage expects: ($author, $recipients, $message, $options)
  $self->APP->sendPrivateMessage(
    $eddie,                        # author (Cool Man Eddie user node)
    { user_id => $recipient_id },  # recipient
    $message                       # message text
  );

  return;
}

# GET /api/giftshop/status - Get user's gift shop status
sub status {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;

  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in to view the gift shop.'
    }];
  }

  my $USER = $user->NODEDATA;
  my $VARS = $user->VARS;
  my $level = $APP->getLevel($USER);

  return [$self->HTTP_OK, {
    success => 1,
    gp => int($USER->{GP} || 0),
    level => $level,
    votesLeft => int($USER->{votesleft} || 0),
    coolsLeft => int($VARS->{cools} || 0),
    tokens => int($VARS->{tokens} || 0),
    easterEggs => int($VARS->{easter_eggs} || 0),
    starCost => $self->_star_cost($level),
    canBuyChing => $self->_can_buy_ching($VARS) ? \1 : \0,
    chingCooldownMinutes => $self->_ching_cooldown_remaining($VARS),
    topicSuspended => $APP->isSuspended($USER, "topic") ? \1 : \0,
    gpOptOut => $VARS->{GPoptout} ? \1 : \0,
  }];
}

# POST /api/giftshop/star - Give a star to another user
sub give_star {
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

  if ($VARS->{GPoptout}) {
    return [$self->HTTP_OK, { success => 0, error => 'Your vow of poverty prevents you from giving stars.' }];
  }

  if ($level < 1) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 1 to give stars.' }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $recipient_name = $data->{recipient};
  my $color = $data->{color} || 'Gold';
  my $reason = $data->{reason};

  unless ($recipient_name) {
    return [$self->HTTP_OK, { success => 0, error => 'You must specify a recipient.' }];
  }

  unless ($reason) {
    return [$self->HTTP_OK, { success => 0, error => 'You must specify a reason for giving the star.' }];
  }

  my $recipient = $DB->getNode($recipient_name, 'user');
  unless ($recipient) {
    return [$self->HTTP_OK, { success => 0, error => "User '$recipient_name' not found." }];
  }

  if ($recipient->{user_id} == $USER->{user_id}) {
    return [$self->HTTP_OK, { success => 0, error => 'You cannot give a star to yourself.' }];
  }

  my $cost = $self->_star_cost($level);
  if ($USER->{GP} < $cost) {
    return [$self->HTTP_OK, { success => 0, error => "You need at least $cost GP to give a star." }];
  }

  # Deduct GP and update recipient
  $USER->{GP} -= $cost;
  $recipient->{stars} = ($recipient->{stars} || 0) + 1;

  $DB->updateNode($USER, -1);
  $DB->updateNode($recipient, -1);

  # Determine article
  my $article = ($color =~ /^\s*[aeiou]/i) ? 'an' : 'a';

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "[$USER->{title}] gave $article $color Star to [$recipient->{title}] at the [E2 Gift Shop].");

  # Send Cool Man Eddie message
  $self->_send_eddie_message(
    $recipient->{user_id},
    "Sweet! [$USER->{title}] just awarded you $article [Star|$color Star], because \"$reason\""
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "$article $color Star has been awarded to $recipient->{title}.",
    newGP => int($USER->{GP}),
  }];
}

# POST /api/giftshop/buyvotes - Buy additional votes with GP
sub buy_votes {
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

  if ($VARS->{GPoptout}) {
    return [$self->HTTP_OK, { success => 0, error => 'Your vow of poverty prevents you from buying votes.' }];
  }

  if ($level < 2) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 2 to buy votes.' }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $amount = int($data->{amount} || 0);

  if ($amount < 1) {
    return [$self->HTTP_OK, { success => 0, error => 'You must specify a positive number of votes.' }];
  }

  my $cost = $amount;  # 1 GP per vote
  if ($USER->{GP} < $cost) {
    return [$self->HTTP_OK, { success => 0, error => "You need at least $cost GP to buy $amount votes." }];
  }

  # Deduct GP and add votes
  $USER->{GP} -= $cost;
  $USER->{votesleft} = ($USER->{votesleft} || 0) + $amount;

  $DB->updateNode($USER, -1);

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "$USER->{title} purchased $amount votes at the [E2 Gift Shop].");

  return [$self->HTTP_OK, {
    success => 1,
    message => "You purchased $amount votes.",
    newGP => int($USER->{GP}),
    votesLeft => int($USER->{votesleft}),
  }];
}

# POST /api/giftshop/givevotes - Give votes to another user
sub give_votes {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be logged in.' }];
  }

  my $USER = $user->NODEDATA;
  my $level = $APP->getLevel($USER);

  if ($level < 9) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 9 to give votes.' }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $recipient_name = $data->{recipient};
  my $amount = int($data->{amount} || 0);
  my $anonymous = $data->{anonymous} ? 1 : 0;

  unless ($recipient_name) {
    return [$self->HTTP_OK, { success => 0, error => 'You must specify a recipient.' }];
  }

  if ($amount < 1 || $amount > 25) {
    return [$self->HTTP_OK, { success => 0, error => 'You must give between 1 and 25 votes.' }];
  }

  if (($USER->{votesleft} || 0) < $amount) {
    return [$self->HTTP_OK, { success => 0, error => "You don't have enough votes to give." }];
  }

  my $recipient = $DB->getNode($recipient_name, 'user');
  unless ($recipient) {
    return [$self->HTTP_OK, { success => 0, error => "User '$recipient_name' not found." }];
  }

  # Transfer votes
  $USER->{votesleft} -= $amount;
  $recipient->{votesleft} = ($recipient->{votesleft} || 0) + $amount;
  $recipient->{sanctity} = ($recipient->{sanctity} || 0) + 1;

  $DB->updateNode($USER, -1);
  $DB->updateNode($recipient, -1);

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "$USER->{title} gave $amount of their votes to $recipient->{title} at the [E2 Gift Shop].");

  # Send Cool Man Eddie message
  my $from = $anonymous ? "someone mysterious" : "[$USER->{title}]";
  my $vote_word = $amount == 1 ? "vote" : "votes";
  $self->_send_eddie_message(
    $recipient->{user_id},
    "Whoa! $from just [E2 Gift Shop|gave you] $amount $vote_word to spend. You'd better use 'em by midnight, baby!"
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "$amount $vote_word given to $recipient->{title}.",
    votesLeft => int($USER->{votesleft}),
  }];
}

# POST /api/giftshop/giveching - Give a C! to another user
sub give_ching {
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

  if ($level < 4) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 4 to give C!s.' }];
  }

  if (!$VARS->{cools} || $VARS->{cools} < 1) {
    return [$self->HTTP_OK, { success => 0, error => "You don't have any C!s to give away." }];
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

  # Note: Legacy code did not enforce recipient level requirements for C! gifts

  # Transfer C!
  $VARS->{cools}--;
  $user->set_vars($VARS);

  my $recipient_vars = $APP->getVars($recipient);
  $recipient_vars->{cools} = ($recipient_vars->{cools} || 0) + 1;
  Everything::setVars($recipient, $recipient_vars);

  $recipient->{sanctity} = ($recipient->{sanctity} || 0) + 1;
  $DB->updateNode($recipient, -1);

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "$USER->{title} gave a C! to $recipient->{title} at the [E2 Gift Shop].");

  # Send Cool Man Eddie message
  my $from = $anonymous ? "someone mysterious" : "[$USER->{title}]";
  $self->_send_eddie_message(
    $recipient->{user_id},
    "Hey, $from just [E2 Gift Shop|gave you] a C! to spend. Use it to rock someone's world!"
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "A C! has been given to $recipient->{title}.",
    coolsLeft => int($VARS->{cools}),
  }];
}

# POST /api/giftshop/buyching - Buy a C! for 100 GP (24hr cooldown)
sub buy_ching {
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

  if ($VARS->{GPoptout}) {
    return [$self->HTTP_OK, { success => 0, error => 'Your vow of poverty prevents you from buying C!s.' }];
  }

  if ($level < 12) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 12 to buy C!s.' }];
  }

  my $cost = 100;
  if ($USER->{GP} < $cost) {
    return [$self->HTTP_OK, { success => 0, error => "You need at least $cost GP to buy a C!." }];
  }

  unless ($self->_can_buy_ching($VARS)) {
    my $mins = $self->_ching_cooldown_remaining($VARS);
    my $hours = floor($mins / 60);
    my $remaining_mins = $mins % 60;
    return [$self->HTTP_OK, {
      success => 0,
      error => "You can only buy one C! every 24 hours. You can buy another in $hours hours, $remaining_mins minutes."
    }];
  }

  # Deduct GP and add C!
  $USER->{GP} -= $cost;
  $DB->updateNode($USER, -1);

  $VARS->{cools} = ($VARS->{cools} || 0) + 1;

  # Record purchase time
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  $VARS->{chingbought} = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
    $year+1900, $mon+1, $mday, $hour, $min, $sec;

  $user->set_vars($VARS);

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "$USER->{title} purchased a C! at the [E2 Gift Shop] for $cost GP.");

  return [$self->HTTP_OK, {
    success => 1,
    message => "You purchased a C!",
    newGP => int($USER->{GP}),
    coolsLeft => int($VARS->{cools}),
  }];
}

# POST /api/giftshop/buytoken - Buy a topic token
sub buy_token {
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

  if ($VARS->{GPoptout}) {
    return [$self->HTTP_OK, { success => 0, error => 'Your vow of poverty prevents you from buying tokens.' }];
  }

  if ($level < 6) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 6 to buy tokens.' }];
  }

  my $cost = 25;
  if ($USER->{GP} < $cost) {
    return [$self->HTTP_OK, { success => 0, error => "You need at least $cost GP to buy a token." }];
  }

  # Deduct GP and add token
  $USER->{GP} -= $cost;
  $DB->updateNode($USER, -1);

  $VARS->{tokens} = ($VARS->{tokens} || 0) + 1;
  $VARS->{tokens_bought} = ($VARS->{tokens_bought} || 0) + 1;
  $user->set_vars($VARS);

  return [$self->HTTP_OK, {
    success => 1,
    message => "You purchased a token.",
    newGP => int($USER->{GP}),
    tokens => int($VARS->{tokens}),
  }];
}

# POST /api/giftshop/settopic - Use a token to set the room topic
sub set_topic {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be logged in.' }];
  }

  my $USER = $user->NODEDATA;
  my $VARS = $user->VARS;
  my $is_editor = $APP->isEditor($USER);

  # Editors can change topic for free
  if (!$is_editor && (!$VARS->{tokens} || $VARS->{tokens} < 1)) {
    return [$self->HTTP_OK, { success => 0, error => "You don't have any tokens." }];
  }

  if ($APP->isSuspended($USER, "topic")) {
    return [$self->HTTP_OK, { success => 0, error => 'Your topic privileges have been suspended.' }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $new_topic = $data->{topic};

  unless ($new_topic && $new_topic =~ /\S/) {
    return [$self->HTTP_OK, { success => 0, error => 'You must specify a topic.' }];
  }

  # Sanitize topic
  $new_topic = $APP->htmlScreen($new_topic);

  # Don't allow empty or "No information" topics
  if ($new_topic eq '' || $new_topic =~ /^No information/i) {
    return [$self->HTTP_OK, { success => 0, error => 'Invalid topic.' }];
  }

  # Update room topic
  my $settingsnode = $DB->getNode('Room topics', 'setting');
  my $topics = $APP->getVars($settingsnode);
  my $room = 0;  # Outside room
  $topics->{$room} = $new_topic;
  Everything::setVars($settingsnode, $topics);

  # Deduct token (unless editor)
  unless ($is_editor) {
    $VARS->{tokens}--;
    $user->set_vars($VARS);
  }

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "$USER->{title} changed room topic to '$new_topic'");

  return [$self->HTTP_OK, {
    success => 1,
    message => "The topic has been updated.",
    tokens => int($VARS->{tokens} || 0),
  }];
}

# POST /api/giftshop/buyeggs - Buy easter eggs
sub buy_eggs {
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

  if ($VARS->{GPoptout}) {
    return [$self->HTTP_OK, { success => 0, error => 'Your vow of poverty prevents you from buying eggs.' }];
  }

  if ($level < 7) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 7 to buy easter eggs.' }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $amount = int($data->{amount} || 1);

  if ($amount < 1 || $amount > 5) {
    return [$self->HTTP_OK, { success => 0, error => 'You can buy between 1 and 5 eggs at a time.' }];
  }

  my $cost_per_egg = 25;
  my $total_cost = $cost_per_egg * $amount;

  if ($USER->{GP} < $total_cost) {
    return [$self->HTTP_OK, { success => 0, error => "You need at least $total_cost GP to buy $amount eggs." }];
  }

  # Deduct GP and add eggs
  $USER->{GP} -= $total_cost;
  $DB->updateNode($USER, -1);

  $VARS->{easter_eggs} = ($VARS->{easter_eggs} || 0) + $amount;
  $VARS->{easter_eggs_bought} = ($VARS->{easter_eggs_bought} || 0) + $amount;
  $user->set_vars($VARS);

  my $egg_word = $amount == 1 ? "egg" : "eggs";
  return [$self->HTTP_OK, {
    success => 1,
    message => "You purchased $amount easter $egg_word.",
    newGP => int($USER->{GP}),
    easterEggs => int($VARS->{easter_eggs}),
  }];
}

# POST /api/giftshop/giveegg - Give an easter egg to another user
sub give_egg {
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

  if ($level < 7) {
    return [$self->HTTP_OK, { success => 0, error => 'You must be at least Level 7 to give easter eggs.' }];
  }

  if (!$VARS->{easter_eggs} || $VARS->{easter_eggs} < 1) {
    return [$self->HTTP_OK, { success => 0, error => "You don't have any easter eggs to give." }];
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

  # Transfer egg
  $VARS->{easter_eggs}--;
  $user->set_vars($VARS);

  my $recipient_vars = $APP->getVars($recipient);
  $recipient_vars->{easter_eggs} = ($recipient_vars->{easter_eggs} || 0) + 1;
  Everything::setVars($recipient, $recipient_vars);

  # Log the action
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  $APP->securityLog($giftshop_node, $USER, "$USER->{title} gave an easter egg to $recipient->{title} at the [E2 Gift Shop].");

  # Send Cool Man Eddie message
  my $from = $anonymous ? "someone mysterious" : "[$USER->{title}]";
  $self->_send_eddie_message(
    $recipient->{user_id},
    "Hey, $from just gave you an [easter egg]! That means you are tastier than an omelette!"
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "An easter egg has been given to $recipient->{title}.",
    easterEggs => int($VARS->{easter_eggs}),
  }];
}

__PACKAGE__->meta->make_immutable;

1;

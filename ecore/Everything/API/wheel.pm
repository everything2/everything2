package Everything::API::wheel;

use Moose;
extends 'Everything::API';

sub route {
  my ($self, $REQUEST, $extra) = @_;
  my $method = lc($REQUEST->request_method());

  # POST /api/wheel/spin
  if ($extra eq 'spin' && $method eq 'post') {
    return $self->spin($REQUEST);
  }

  # Catchall for unmatched routes
  return $self->$method($REQUEST);
}

sub spin {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;  # Blessed object
  my $USER = $user->NODEDATA;  # Hashref for modifications
  my $VARS = $user->VARS;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check if user is logged in
  if ($APP->isGuest($user)) {
    return [$self->HTTP_FORBIDDEN, {
      success => 0,
      error => 'You must be logged in to spin the wheel.'
    }];
  }

  # Check if user has GP opt-out enabled
  if ($VARS->{GPoptout}) {
    return [$self->HTTP_FORBIDDEN, {
      success => 0,
      error => 'Your vow of poverty does not allow you to gamble. You need to opt in to the GP System in order to spin the wheel.'
    }];
  }

  # Check minimum GP requirement
  my $spinCost = 5;
  if ($USER->{GP} < $spinCost) {
    return [$self->HTTP_FORBIDDEN, {
      success => 0,
      error => 'You need at least 5 GP to spin the wheel. Come back when you have GP to burn.'
    }];
  }

  # Deduct spin cost
  $USER->{GP} -= $spinCost;

  # Increment spin counter
  $VARS->{spin_wheel} ||= 0;
  $VARS->{spin_wheel} += 1;

  # Generate random prize (0-9999)
  my $rnd = int(rand(10000));
  my $resultMessage = '';
  my $prizeType = '';

  # Prize distribution (same as wheel_of_surprise delegation)
  if ($rnd < 3800) {
    $resultMessage = 'nothing! Too bad ...';
    $prizeType = 'nothing';
  }
  elsif ($rnd < 3850) {
    $resultMessage = 'a coupon for a free Butterfinger McFlurry. Alas, they no longer make them.';
    $prizeType = 'nothing';
  }
  elsif ($rnd < 3910) {
    $resultMessage = 'a porcupine egg! I wonder what will hatch. Probably nothing.';
    $prizeType = 'nothing';
  }
  elsif ($rnd < 3915) {
    $resultMessage = 'a tin of fair trade caviar! The perfect gift for the up-and-coming hippie plutocrat!';
    $prizeType = 'nothing';
  }
  elsif ($rnd < 3930) {
    $resultMessage = 'an easter ostrich egg! This has to be worth three ordinary easter eggs! I wonder what\'s inside.';
    $VARS->{easter_eggs} ||= 0;
    $VARS->{easter_eggs_bought} ||= 0;
    $VARS->{easter_eggs} += 3;
    $VARS->{easter_eggs_bought} += 3;
    $prizeType = 'easter_egg';
  }
  elsif ($rnd < 3935) {
    $resultMessage = 'a Christmas egg! It\'s red and green and plays Jingle Bells when you open it. That\'s about all that it does. Is that not enough!?';
    $VARS->{easter_eggs} ||= 0;
    $VARS->{easter_eggs_bought} ||= 0;
    $VARS->{easter_eggs} += 1;
    $VARS->{easter_eggs_bought} += 1;
    $prizeType = 'easter_egg';
  }
  elsif ($rnd < 3940) {
    $resultMessage = 'a passover egg! I wonder what\'s inside. Probably a matzo ball.';
    $VARS->{easter_eggs} ||= 0;
    $VARS->{easter_eggs_bought} ||= 0;
    $VARS->{easter_eggs} += 1;
    $VARS->{easter_eggs_bought} += 1;
    $prizeType = 'easter_egg';
  }
  elsif ($rnd < 3950) {
    $resultMessage = 'five counterfeit GP! You pawn them off on some unsuspecting noder in exchange for a shiny new easter egg.';
    $VARS->{easter_eggs} ||= 0;
    $VARS->{easter_eggs_bought} ||= 0;
    $VARS->{easter_eggs} += 1;
    $VARS->{easter_eggs_bought} += 1;
    $prizeType = 'easter_egg';
  }
  elsif ($rnd < 4000) {
    $resultMessage = 'an anvil! At least that\'s what it feels like when you drop it on your foot. Hmm. Maybe it\'s a strange form of easter egg.';
    $VARS->{easter_eggs} ||= 0;
    $VARS->{easter_eggs_bought} ||= 0;
    $VARS->{easter_eggs} += 1;
    $VARS->{easter_eggs_bought} += 1;
    $prizeType = 'easter_egg';
  }
  elsif ($rnd < 4950) {
    $resultMessage = 'an easter egg! I wonder what\'s inside.';
    $VARS->{easter_eggs} ||= 0;
    $VARS->{easter_eggs_bought} ||= 0;
    $VARS->{easter_eggs} += 1;
    $VARS->{easter_eggs_bought} += 1;
    $prizeType = 'easter_egg';
  }
  elsif ($rnd < 4999) {
    $resultMessage = 'a C!! Coolness!';
    $VARS->{cools} ||= 0;
    $VARS->{cools} += 1;
    $prizeType = 'cool';
  }
  elsif ($rnd == 4999) {
    $resultMessage = '5 C!s! Hurry up and spend \'em while you got \'em!';
    $VARS->{cools} ||= 0;
    $VARS->{cools} += 5;
    $prizeType = 'cool';
  }
  elsif ($rnd == 5000) {
    $resultMessage = '500 GP! Jackpot!';
    $USER->{GP} += 500;
    $prizeType = 'gp';
  }
  elsif ($rnd < 5006) {
    $resultMessage = '158 GP! That\'s 100 GP adjusted for inflation.';
    $USER->{GP} += 158;
    $prizeType = 'gp';
  }
  elsif ($rnd < 5011) {
    $resultMessage = '42 GP! That\'s 100 GP after taxes. You get the feeling that it\'s also the answer to something.';
    $USER->{GP} += 42;
    $prizeType = 'gp';
  }
  elsif ($rnd < 5100) {
    $resultMessage = '100 GP! Sweet!';
    $USER->{GP} += 100;
    $prizeType = 'gp';
  }
  elsif ($rnd < 5200) {
    $resultMessage = 'a token! Go spend it at the gift shop!';
    $VARS->{tokens} ||= 0;
    $VARS->{tokens_bought} ||= 0;
    $VARS->{tokens} += 1;
    $VARS->{tokens_bought} += 1;
    $prizeType = 'token';
  }
  elsif ($rnd < 5240) {
    $resultMessage = 'a New York City subway token! Free ride! Expires April 13, 2003.';
    $prizeType = 'nothing';
  }
  elsif ($rnd < 5500) {
    $resultMessage = '25 GP! Hooray!';
    $USER->{GP} += 25;
    $prizeType = 'gp';
  }
  elsif ($rnd < 6500) {
    $resultMessage = '10 GP! Spin it again!';
    $USER->{GP} += 10;
    $prizeType = 'gp';
  }
  elsif ($rnd < 6750) {
    $resultMessage = '5 GP! You also find one GP that the last player left behind.';
    $USER->{GP} += 6;
    $prizeType = 'gp';
  }
  elsif ($rnd < 7000) {
    $resultMessage = 'nothing as it comes to a creaking, chattering, jerky halt. You complain to the manager about the wheel\'s condition and get your nickel back.';
    $USER->{GP} += 5;
    $prizeType = 'refund';
  }
  elsif ($rnd < 9000) {
    $resultMessage = 'your 5 GP nickel back! Spin it again!';
    $USER->{GP} += 5;
    $prizeType = 'refund';
  }
  else {
    $resultMessage = '1 GP! (Wah-wah-wah!)';
    $USER->{GP} += 1;
    $prizeType = 'gp';
  }

  # Save user data
  $DB->updateNode($USER, -1);
  $user->set_vars($VARS);

  # Log the spin (for security/audit trail)
  $APP->securityLog(
    $DB->getNode('Wheel of Surprise', 'superdoc'),
    $USER,
    "[$USER->{title}] spun the [Wheel of Surprise]."
  );

  # Check for achievements
  $APP->checkAchievementsByType('miscellaneous', $USER->{user_id});

  return [$self->HTTP_OK, {
    success => 1,
    message => $resultMessage,
    prizeType => $prizeType,
    user => {
      GP => int($USER->{GP}),
      spinCount => int($VARS->{spin_wheel})
    },
    vars => {
      cools => int($VARS->{cools} || 0),
      tokens => int($VARS->{tokens} || 0),
      easter_eggs => int($VARS->{easter_eggs} || 0)
    }
  }];
}

1;

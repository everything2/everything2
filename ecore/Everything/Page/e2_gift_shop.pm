package Everything::Page::e2_gift_shop;

use Moose;
use POSIX qw(floor);
use Time::Local qw(timelocal);
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

=head1 Everything::Page::e2_gift_shop

Page controller for the E2 Gift Shop.

Provides initial data for the React component including:
- User's current GP, votes, cools, tokens, eggs
- User's level and calculated star cost
- Ching purchase cooldown status
- Topic suspension status
- Last topic change info

=cut

sub buildReactData {
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user;
  my $VARS = $USER->VARS;
  my $APP = $self->APP;
  my $DB = $self->DB;
  my $NODEDATA = $USER->NODEDATA;

  my $level = $APP->getLevel($NODEDATA);

  # Calculate star cost based on level
  my $star_cost = 75 - (($level - 1) * 5);
  $star_cost = 25 if $star_cost < 25;

  # Check ching cooldown
  my ($can_buy_ching, $ching_cooldown_minutes) = $self->_check_ching_cooldown($VARS);

  # Get last topic change
  my $last_topic_change = $self->_get_last_topic_change();

  return {
    type => 'e2_gift_shop',
    giftShop => {
      userLevel => $level,
      starCost => $star_cost,
      gp => int($NODEDATA->{GP} || 0),
      votesLeft => int($NODEDATA->{votesleft} || 0),
      coolsLeft => int($VARS->{cools} || 0),
      tokens => int($VARS->{tokens} || 0),
      easterEggs => int($VARS->{easter_eggs} || 0),
      canBuyChing => $can_buy_ching ? \1 : \0,
      chingCooldownMinutes => $ching_cooldown_minutes,
      topicSuspended => $APP->isSuspended($NODEDATA, "topic") ? \1 : \0,
      lastTopicChange => $last_topic_change,
      gpOptOut => $VARS->{GPoptout} ? \1 : \0,
      isEditor => $APP->isEditor($NODEDATA) ? \1 : \0,
    }
  };
}

sub _check_ching_cooldown {
  my ($self, $VARS) = @_;

  return (1, 0) unless $VARS->{chingbought};

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time - 86400);
  my $hours24 = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
    $year+1900, $mon+1, $mday, $hour, $min, $sec;

  if ($VARS->{chingbought} le $hours24) {
    return (1, 0);
  }

  # Calculate remaining cooldown
  my ($d, $t) = split(' ', $VARS->{chingbought});
  my ($chinghour, $chingmin, $chingsec) = split(':', $t);
  my ($chingyear, $chingmonth, $chingday) = split('-', $d);
  my $ching_time = timelocal($chingsec, $chingmin, $chinghour, $chingday, $chingmonth-1, $chingyear);

  ($d, $t) = split(' ', $hours24);
  ($chinghour, $chingmin, $chingsec) = split(':', $t);
  ($chingyear, $chingmonth, $chingday) = split('-', $d);
  my $hour_time = timelocal($chingsec, $chingmin, $chinghour, $chingday, $chingmonth-1, $chingyear);

  my $timeDiff = $ching_time - $hour_time;
  my $minutes = floor($timeDiff / 60);

  return (0, $minutes);
}

sub _get_last_topic_change {
  my ($self) = @_;
  my $DB = $self->DB;

  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  return '' unless $giftshop_node;

  my ($lastChange, $lastTime) = $DB->sqlSelect(
    "seclog_details, seclog_time",
    "seclog",
    "seclog_node = $giftshop_node->{node_id} AND seclog_details LIKE '%changed room topic%'",
    "ORDER BY seclog_id DESC LIMIT 1"
  );

  return '' unless $lastChange;

  # Escape brackets for display
  $lastChange =~ s/\[/&#91;/g;
  $lastChange =~ s/\]/&#93;/g;

  return "At $lastTime, $lastChange";
}

__PACKAGE__->meta->make_immutable;

1;

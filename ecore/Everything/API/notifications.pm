package Everything::API::notifications;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
    "/" => "get_all",
    "dismiss" => "dismiss"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $USER = $user->NODEDATA;
  my $VARS = $user->VARS;

  # Use Application.pm's getRenderedNotifications to get properly formatted data
  # This ensures periodic updates return the same structure as initial page load
  my $notifications = $self->APP->getRenderedNotifications($USER, $VARS);

  return [$self->HTTP_OK, { notifications => $notifications }];
}

sub dismiss
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;
  my $notified_id = $data->{notified_id};

  unless($notified_id && $notified_id =~ /^\d+$/)
  {
    $self->devLog("Invalid notified_id. Sending BAD REQUEST");
    return [$self->HTTP_BAD_REQUEST, {error => "Valid notified_id is required"}];
  }

  # Check if notification exists
  my $exists = $self->DB->sqlSelect("COUNT(*)", "notified", "notified_id = $notified_id");

  unless($exists)
  {
    $self->devLog("Notification $notified_id not found. Sending NOT FOUND");
    return [$self->HTTP_NOT_FOUND, {error => "Notification not found"}];
  }

  my $for_user = $self->DB->sqlSelect("user_id", "notified", "notified_id = $notified_id");

  my $user = $REQUEST->user;
  my $user_id = $user->NODEDATA->{user_id};

  # Check if this is the user's direct notification
  my $is_direct_notification = ($for_user == $user_id);

  if($is_direct_notification)
  {
    # Direct notification - mark as seen
    $self->DB->sqlUpdate("notified", {is_seen => 1}, "notified_id = $notified_id");
    $self->devLog("User $user_id dismissed their own notification $notified_id");
  }
  else
  {
    # Check if user subscribes to this notification type
    my $VARS = $user->VARS;
    my $subscribed = 0;
    my $notificationList;

    if ($$VARS{settings})
    {
      my $settings = $self->JSON->decode($$VARS{settings});
      $notificationList = $settings->{notifications} if $settings;

      if ($notificationList && ref($notificationList) eq 'HASH' && exists $notificationList->{$for_user})
      {
        $subscribed = 1;
      }
    }

    unless($subscribed)
    {
      $self->devLog("User $user_id attempted to dismiss notification $notified_id belonging to user $for_user (not subscribed). Sending FORBIDDEN");
      return [$self->HTTP_FORBIDDEN, {error => "Cannot dismiss another user's notification"}];
    }

    # Subscribed notification - create a reference record to mark it as seen for this user
    $self->DB->sqlInsert("notified", {
      user_id => $user_id,
      reference_notified_id => $notified_id,
      is_seen => 1,
      notification_id => 1,  # Dummy notification_id required by schema
      notified_time => \"NOW()",
      args => '{}'
    });
    $self->devLog("User $user_id dismissed subscribed notification $notified_id (belongs to user/type $for_user)");
  }

  # Get updated notifications list
  my $USER = $user->NODEDATA;
  my $VARS = $user->VARS;
  my $notifications = $self->APP->getRenderedNotifications($USER, $VARS);

  return [$self->HTTP_OK, {
    success => 1,
    notified_id => int($notified_id),
    notifications => $notifications
  }];
}

# Helper method: Check if user can see a notification type
# Mirrors logic from htmlcode::canseeNotification
sub _canseeNotification
{
  my ($self, $notification, $USER) = @_;

  my $uid = $$USER{node_id} || $$USER{user_id};
  my $isCE = $self->APP->isEditor($USER);
  my $isCoder = $self->APP->inUsergroup($uid,"edev","nogods") || $self->APP->inUsergroup($uid, 'e2coders', "nogods");
  my $isChanop = $self->APP->isChanop($uid, "nogods");

  return 0 if ( !$isCE && ($$notification{description} =~ /node note/) );
  return 0 if ( !$isCE && ($$notification{description} =~ /new user/) );
  return 0 if ( !$isCE && ($$notification{description} =~ /(?:blanks|removes) a writeup/) );
  return 0 if ( !$isCE && ($$notification{description} =~ /review of a draft/) );
  return 0 if ( !$isChanop && ($$notification{description} =~ /chanop/) );

  return 1;
}

around ['get_all', 'dismiss'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

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

  my $user_id = $REQUEST->user->NODEDATA->{user_id};

  # Query notified table for unseen notifications
  my $query = q{
    SELECT notified.notified_id, notified.notification_id, notified.args,
           notified.notified_time
    FROM notified
    WHERE notified.user_id = ?
      AND notified.is_seen = 0
    ORDER BY notified.notified_time DESC
  };

  my $notifications = $self->DB->getDatabaseHandle->selectall_arrayref(
    $query,
    { Slice => {} },
    $user_id
  );

  $self->devLog("Fetched " . scalar(@$notifications) . " notifications for user $user_id");

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

  # Check if notification belongs to current user
  my $for_user = $self->DB->sqlSelect("user_id", "notified", "notified_id = $notified_id");

  unless($for_user)
  {
    $self->devLog("Notification $notified_id not found. Sending NOT FOUND");
    return [$self->HTTP_NOT_FOUND, {error => "Notification not found"}];
  }

  my $user_id = $REQUEST->user->NODEDATA->{user_id};

  unless($for_user == $user_id)
  {
    $self->devLog("User $user_id attempted to dismiss notification $notified_id belonging to user $for_user. Sending FORBIDDEN");
    return [$self->HTTP_FORBIDDEN, {error => "Cannot dismiss another user's notification"}];
  }

  # Mark notification as seen
  $self->DB->sqlUpdate("notified", {is_seen => 1}, "notified_id = $notified_id");

  $self->devLog("User $user_id dismissed notification $notified_id");

  # Query remaining unseen notifications
  my $query = q{
    SELECT notified.notified_id, notified.notification_id, notified.args,
           notified.notified_time
    FROM notified
    WHERE notified.user_id = ?
      AND notified.is_seen = 0
    ORDER BY notified.notified_time DESC
  };

  my $notifications = $self->DB->getDatabaseHandle->selectall_arrayref(
    $query,
    { Slice => {} },
    $user_id
  );

  return [$self->HTTP_OK, {
    success => 1,
    notified_id => int($notified_id),
    notifications => $notifications,
    count => scalar(@$notifications)
  }];
}

around ['get_all', 'dismiss'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

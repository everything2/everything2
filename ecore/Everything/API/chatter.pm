package Everything::API::chatter;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
  "create" => "create",
  "/" => "get_all",
  "clear" => "clear",
  "clear_all" => "clear_all"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  my $limit = $REQUEST->cgi->param("limit");
  $limit = defined($limit) ? int($limit) : 30;

  my $offset = $REQUEST->cgi->param("offset");
  $offset = defined($offset) ? int($offset) : 0;

  my $room = $REQUEST->cgi->param("room");
  $room = defined($room) ? int($room) : 0;

  my $since = $REQUEST->cgi->param("since") || undef;

  my $params = {
    limit => $limit,
    offset => $offset,
    room => $room,
    since => $since,
    user => $REQUEST->user ? $REQUEST->user->NODEDATA : undef
  };

  return [$self->HTTP_OK, $self->APP->getRecentChatter($params)];
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;

  unless($data->{message})
  {
    $self->devLog("Can't send chatter due to blank message text. Sending BAD REQUEST");
    return [$self->HTTP_BAD_REQUEST, {error => "Message text is required"}];
  }

  # Get user variables
  my $vars = $self->APP->getVars($REQUEST->user->NODEDATA);

  # Process message command (handles /flip, /roll, /me, /msg, etc.)
  # Now returns: { success => 1 } or { success => 0, error => "specific message" }
  my $result = $self->APP->processMessageCommand($REQUEST->user->NODEDATA, $data->{message}, $vars);

  # Check if result is a hashref with error details
  if (ref($result) eq 'HASH')
  {
    if ($result->{success})
    {
      # Success - return the recent chatter to update the client
      my $chatter = $self->APP->getRecentChatter({
        limit => 1,
        user => $REQUEST->user ? $REQUEST->user->NODEDATA : undef
      });
      my $response = {success => 1, chatter => $chatter};

      # If command needs immediate message poll (e.g., /help), signal to client
      $response->{poll_messages} = 1 if $result->{poll_messages};

      # Pass through warnings (e.g., partial usergroup blocks)
      $response->{warning} = $result->{warning} if $result->{warning};

      # Pass through info messages (e.g., macro execution results)
      $response->{info} = $result->{info} if $result->{info};

      return [$self->HTTP_OK, $response];
    }
    else
    {
      # Failed with specific error message
      $self->devLog("Message not posted: " . ($result->{error} || "unknown error"));
      return [$self->HTTP_OK, {success => 0, error => $result->{error} || "Message not posted"}];
    }
  }

  # Legacy behavior: truthy/falsy result (for backward compatibility)
  if ($result)
  {
    my $chatter = $self->APP->getRecentChatter({
      limit => 1,
      user => $REQUEST->user ? $REQUEST->user->NODEDATA : undef
    });
    return [$self->HTTP_OK, {success => 1, chatter => $chatter}];
  }
  else
  {
    return [$self->HTTP_OK, {success => 0, error => "Message not posted"}];
  }
}

# Flush public chatter. Body: { scope => 'room' | 'all' } (defaults to 'room').
#   room -> a chanop clears their CURRENT room (room taken server-side, not from
#           the client); all -> an admin clears every room. SECLOG_CATBOX_FLUSH
#   is written on success. Backs /flushchatter and /flushallchatter.
sub clear
{
  my ($self, $REQUEST) = @_;

  my $data  = $REQUEST->JSON_POSTDATA || {};
  my $scope = (defined $data->{scope} && $data->{scope} eq 'all') ? 'all' : 'room';

  my $result = $self->APP->flushChatter($REQUEST->user->NODEDATA, $scope);
  unless($result->{success})
  {
    $self->devLog("chatter clear ($scope) denied: $result->{error}");
    return [$self->HTTP_FORBIDDEN, {error => $result->{error}}];
  }

  $self->devLog("Flushed chatter (scope=$result->{scope}, deleted=$result->{deleted})");
  return [$self->HTTP_OK, {success => 1, deleted => int($result->{deleted}), scope => $result->{scope}}];
}

# Back-compat alias for the legacy /clearchatter client command: clear all rooms.
sub clear_all
{
  my ($self, $REQUEST) = @_;

  my $result = $self->APP->flushChatter($REQUEST->user->NODEDATA, 'all');
  unless($result->{success})
  {
    return [$self->HTTP_FORBIDDEN, {error => $result->{error}}];
  }

  return [$self->HTTP_OK, {success => 1, deleted => int($result->{deleted}), scope => 'all'}];
}

around ['get_all','create'] => \&Everything::API::unauthorized_if_guest;
around ['clear','clear_all'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

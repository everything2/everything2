package Everything::API::chatter;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
  "create" => "create",
  "/" => "get_all"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  my $limit = int($REQUEST->cgi->param("limit")) || 30;
  my $offset = int($REQUEST->cgi->param("offset")) || 0;
  my $room = int($REQUEST->cgi->param("room")) || 0;
  my $since = $REQUEST->cgi->param("since") || undef;

  my $params = {
    limit => $limit,
    offset => $offset,
    room => $room,
    since => $since
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

  # Send the public chatter
  my $result = $self->APP->sendPublicChatter($REQUEST->user->NODEDATA, $data->{message}, $vars);

  if($result)
  {
    # Success - return the recent chatter to update the client
    my $chatter = $self->APP->getRecentChatter({limit => 1});
    return [$self->HTTP_OK, {success => 1, chatter => $chatter}];
  }else{
    # Failed - could be due to duplicate, suspension, etc.
    # Return success but with a flag indicating message wasn't posted
    return [$self->HTTP_OK, {success => 0, error => "Message not posted"}];
  }
}

around ['get_all','create'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

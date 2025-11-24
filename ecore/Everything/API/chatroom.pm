package Everything::API::chatroom;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes
{
  return {
    'change_room' => 'change_room',
    'set_cloaked' => 'set_cloaked',
    'create_room' => 'create_room',
    '/' => 'get_other_users',
  }
}

sub get_other_users {
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user->NODEDATA;
  my $otherUsersData = $self->APP->buildOtherUsersData($USER);

  return [$self->HTTP_OK, $otherUsersData];
}

sub change_room {
  my ($self, $REQUEST) = @_;

  my $USER_BLESSED = $REQUEST->user;
  my $USER = $USER_BLESSED->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Authorization: Must not be "everyone"
  if ($USER_BLESSED->title eq 'everyone') {
    return [$self->HTTP_FORBIDDEN, { error => 'This user cannot change rooms' }];
  }

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data) {
    return [$self->HTTP_BAD_REQUEST, { error => 'Request body is required' }];
  }

  # Get room_id from POST data
  my $room_id = $data->{room_id};

  # Validate room_id is provided
  unless (defined $room_id) {
    return [$self->HTTP_BAD_REQUEST, { error => 'room_id is required' }];
  }

  # room_id 0 means "outside" - no node needed
  my $room_node = undef;
  if ($room_id != 0) {
    $room_node = $DB->getNodeById($room_id);
    unless ($room_node && $room_node->{type}{title} eq 'room') {
      return [$self->HTTP_NOT_FOUND, { error => 'Room not found' }];
    }
  }

  # Check if user is suspended from changing rooms
  my $suspension = $APP->isSuspended($USER, "changeroom");
  if ($suspension) {
    my $message;
    if (defined($suspension->{ends}) && $suspension->{ends} != 0) {
      my $seconds = $APP->convertDateToEpoch($suspension->{ends}) - time();
      $message = "You are locked here for $seconds seconds";
    } else {
      $message = "You are locked here indefinitely";
    }
    return [$self->HTTP_FORBIDDEN, { error => $message }];
  }

  # Check if user can enter the room
  if ($room_node) {
    my $VARS = $APP->getVars($USER);
    unless ($APP->canEnterRoom($room_node, $USER, $VARS)) {
      return [$self->HTTP_FORBIDDEN, { error => 'You cannot enter this room' }];
    }
  }

  # Change the room
  $APP->changeRoom($USER, $room_node);

  # Return success with new room info and full otherUsersData
  my $new_room_title = $room_node ? $room_node->{title} : 'outside';
  my $otherUsersData = $APP->buildOtherUsersData($USER);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Changed to room: ' . $new_room_title,
    room_id => int($room_id),
    room_title => $new_room_title,
    otherUsersData => $otherUsersData
  }];
}

sub set_cloaked {
  my ($self, $REQUEST) = @_;

  my $USER_BLESSED = $REQUEST->user;
  my $USER = $USER_BLESSED->NODEDATA;
  my $APP = $self->APP;

  # Authorization: Must be able to cloak
  unless ($APP->userCanCloak($USER)) {
    return [$self->HTTP_FORBIDDEN, { error => 'You do not have permission to cloak' }];
  }

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data) {
    return [$self->HTTP_BAD_REQUEST, { error => 'Request body is required' }];
  }

  # Get cloaked status from POST data
  my $cloaked = $data->{cloaked};

  unless (defined $cloaked) {
    return [$self->HTTP_BAD_REQUEST, { error => 'cloaked parameter is required' }];
  }

  # Set cloak status
  my $VARS = $APP->getVars($USER);
  if ($cloaked) {
    $APP->cloak($USER, $VARS);
  } else {
    $APP->uncloak($USER, $VARS);
  }
  # Save vars to persist cloak status across page loads
  Everything::setVars($USER, $VARS);

  # Get updated otherUsersData after cloak status change
  my $otherUsersData = $APP->buildOtherUsersData($USER);

  return [$self->HTTP_OK, {
    success => 1,
    message => $cloaked ? 'You are now cloaked' : 'You are now visible',
    cloaked => $cloaked ? 1 : 0,
    otherUsersData => $otherUsersData
  }];
}

sub create_room {
  my ($self, $REQUEST) = @_;

  my $USER_BLESSED = $REQUEST->user;
  my $USER = $USER_BLESSED->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;
  my $CONF = $self->CONF;

  # Authorization: Must not be "everyone"
  if ($USER_BLESSED->title eq 'everyone') {
    return [$self->HTTP_FORBIDDEN, { error => 'This user cannot create rooms' }];
  }

  # Check level requirement
  my $required_level = $CONF->create_room_level || 0;

  # Use blessed node methods
  if ($USER_BLESSED->level < $required_level && !$USER_BLESSED->is_admin && !$USER_BLESSED->is_chanop) {
    return [$self->HTTP_FORBIDDEN, { error => 'Too young, my friend. You need level ' . $required_level . ' to create rooms.' }];
  }

  # Check if suspended from creating rooms
  if ($APP->isSuspended($USER, 'room')) {
    return [$self->HTTP_FORBIDDEN, { error => 'You have been suspended from creating new rooms' }];
  }

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data) {
    return [$self->HTTP_BAD_REQUEST, { error => 'Request body is required' }];
  }

  # Get room title from POST data
  my $room_title = $data->{room_title};

  unless ($room_title && $room_title =~ /\S/) {
    return [$self->HTTP_BAD_REQUEST, { error => 'room_title is required and cannot be empty' }];
  }

  # Trim whitespace
  $room_title =~ s/^\s+|\s+$//g;

  # Safety check: Prevent creating rooms with reserved names
  my $lowercase_title = lc($room_title);
  if ($lowercase_title eq 'outside' || $lowercase_title eq 'go outside') {
    return [$self->HTTP_BAD_REQUEST, { error => 'This room name is reserved and cannot be used' }];
  }

  # Validate room title length (80 chars like original form)
  if (length($room_title) > 80) {
    return [$self->HTTP_BAD_REQUEST, { error => 'Room title must be 80 characters or less' }];
  }

  # Get optional room description
  my $room_doctext = $data->{room_doctext} || '';

  # Check if room already exists (case-sensitive check)
  my $existing = $DB->getNode($room_title, 'room');
  if ($existing) {
    # If user is already in this room, give a more specific error
    my $current_room_id = $USER->{in_room} || 0;
    if ($current_room_id == $existing->{node_id}) {
      return [$self->HTTP_OK, { error => 'You are already in this room' }];
    }
    return [$self->HTTP_OK, { error => 'A room with this title already exists' }];
  }

  # Create the room node
  my $room_type = $DB->getType('room');
  unless ($room_type) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { error => 'Room nodetype not found' }];
  }

  # insertNode signature: ($title, $TYPE, $USER, $NODEDATA, $skip_maintenance)
  my $room_node_id = $DB->insertNode($room_title, $room_type, $USER, {
    roomlocked => 0,
    doctext => $room_doctext,
  }, 'skip maintenance');

  unless ($room_node_id) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { error => 'Failed to create room' }];
  }

  # Double-check that we actually created a new room and didn't get an existing one
  my $room_node = $DB->getNodeById($room_node_id);
  unless ($room_node) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { error => 'Failed to create room' }];
  }

  # Verify the author is the current user (meaning we just created it)
  if ($room_node->{author_user} != $USER->{node_id}) {
    # This room was created by someone else - we got back an existing room
    return [$self->HTTP_OK, { error => 'A room with this title already exists' }];
  }

  # Move user to the new room
  $APP->changeRoom($USER, $room_node);

  # Get updated otherUsersData after room creation and change
  my $otherUsersData = $APP->buildOtherUsersData($USER);

  # Return success
  return [$self->HTTP_OK, {
    success => 1,
    message => 'Room created successfully',
    room_id => int($room_node->{node_id}),
    room_title => $room_node->{title},
    otherUsersData => $otherUsersData
  }];
}

around ['get_other_users', 'change_room', 'set_cloaked', 'create_room'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;

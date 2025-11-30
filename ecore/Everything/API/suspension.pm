package Everything::API::suspension;

use Moose;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
    "user/:username" => "get_user_suspensions(:username)",
    "suspend" => "suspend_user",
    "unsuspend" => "unsuspend_user"
  };
}

=head1 Everything::API::suspension

API for managing user suspensions (chat, room, topic, posting, etc.)

Migrated from document.pm suspension_info() delegation function.

Security levels:
- Chanops: Can manage chat/room/topic suspensions only
- Editors + Admins: Can manage all suspension types

=head2 get_user_suspensions

GET /api/suspension/user/:username

Returns all suspension information for a user.

Returns:
{
  "username": "someuser",
  "suspensions": [
    {
      "type": "chat",
      "type_id": 123,
      "description": "Chat suspension description",
      "suspended": true,
      "suspended_by": "admin_user",
      "started": "2025-11-29 12:34:56"
    }
  ],
  "available_types": [...]
}

=cut

sub get_user_suspensions
{
  my ($self, $REQUEST, $username) = @_;

  my $USER = $REQUEST->user->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check permission - must be Chanop, Editor, or Admin
  unless ($self->_has_suspension_access($USER)) {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Access denied',
      message => 'You do not have permission to view suspension information'
    }];
  }

  unless ($username) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Username required',
      message => 'Please provide a username parameter'
    }];
  }

  my $target_user = $DB->getNode($username, 'user');
  unless ($target_user) {
    return [$self->HTTP_NOT_FOUND, {
      error => 'User not found',
      message => "User '$username' does not exist"
    }];
  }

  # Get available suspension types based on user permissions
  my $available_types = $self->_get_available_suspension_types($USER);

  # Get current suspensions for this user
  my @suspensions;
  foreach my $type_info (@$available_types) {
    my $suspension = $DB->sqlSelectHashref(
      '*',
      'suspension',
      "suspension_user = $target_user->{node_id} AND suspension_sustype = $type_info->{node_id}"
    );

    my $suspended_by_user;
    if ($suspension && $suspension->{suspendedby_user}) {
      my $suspender = $DB->getNodeById($suspension->{suspendedby_user});
      $suspended_by_user = $suspender ? $suspender->{title} : undef;
    }

    push @suspensions, {
      type => $type_info->{title},
      type_id => $type_info->{node_id},
      description => $type_info->{description},
      suspended => $suspension ? 1 : 0,
      suspended_by => $suspended_by_user,
      started => $suspension ? $suspension->{started} : undef
    };
  }

  return [$self->HTTP_OK, {
    username => $target_user->{title},
    user_id => $target_user->{node_id},
    suspensions => \@suspensions,
    available_types => $available_types
  }];
}

=head2 suspend_user

POST /api/suspension/suspend
{
  "username": "someuser",
  "sustype_id": 123
}

Suspends a user from a specific activity type.

=cut

sub suspend_user
{
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check permission
  unless ($self->_has_suspension_access($USER)) {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Access denied',
      message => 'You do not have permission to suspend users'
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $username = $data->{username};
  my $sustype_id = $data->{sustype_id};

  unless ($username && $sustype_id) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Missing parameters',
      message => 'Both username and sustype_id are required'
    }];
  }

  my $target_user = $DB->getNode($username, 'user');
  unless ($target_user) {
    return [$self->HTTP_NOT_FOUND, {
      error => 'User not found',
      message => "User '$username' does not exist"
    }];
  }

  my $sustype = $DB->getNodeById($sustype_id);
  unless ($sustype) {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Suspension type not found',
      message => 'Invalid suspension type ID'
    }];
  }

  # Verify user has access to this suspension type
  unless ($self->_can_manage_suspension_type($USER, $sustype)) {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Permission denied',
      message => "You do not have permission to manage '$sustype->{title}' suspensions"
    }];
  }

  # Check if already suspended
  my $existing = $DB->sqlSelectHashref(
    '*',
    'suspension',
    "suspension_user = $target_user->{node_id} AND suspension_sustype = $sustype_id"
  );

  if ($existing) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Already suspended',
      message => "$target_user->{title} is already suspended from $sustype->{title}"
    }];
  }

  # Create suspension
  $DB->sqlInsert('suspension', {
    suspension_user => $target_user->{node_id},
    suspension_sustype => $sustype_id,
    suspendedby_user => $USER->{node_id}
  });

  # Security log (use Suspension Info superdoc as context node for API calls)
  $APP->securityLog(
    $DB->getNode('Suspension Info', 'superdoc'),
    $USER,
    "$target_user->{title} was suspended from $sustype->{title} by $USER->{title}"
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "Suspension imposed: $target_user->{title} suspended from $sustype->{title}"
  }];
}

=head2 unsuspend_user

POST /api/suspension/unsuspend
{
  "username": "someuser",
  "sustype_id": 123
}

Removes a suspension from a user.

=cut

sub unsuspend_user
{
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check permission
  unless ($self->_has_suspension_access($USER)) {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Access denied',
      message => 'You do not have permission to unsuspend users'
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $username = $data->{username};
  my $sustype_id = $data->{sustype_id};

  unless ($username && $sustype_id) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Missing parameters',
      message => 'Both username and sustype_id are required'
    }];
  }

  my $target_user = $DB->getNode($username, 'user');
  unless ($target_user) {
    return [$self->HTTP_NOT_FOUND, {
      error => 'User not found',
      message => "User '$username' does not exist"
    }];
  }

  my $sustype = $DB->getNodeById($sustype_id);
  unless ($sustype) {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Suspension type not found',
      message => 'Invalid suspension type ID'
    }];
  }

  # Verify user has access to this suspension type
  unless ($self->_can_manage_suspension_type($USER, $sustype)) {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Permission denied',
      message => "You do not have permission to manage '$sustype->{title}' suspensions"
    }];
  }

  # Delete suspension
  my $deleted = $DB->sqlDelete(
    'suspension',
    "suspension_user = $target_user->{node_id} AND suspension_sustype = $sustype_id"
  );

  unless ($deleted) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Not suspended',
      message => "$target_user->{title} is not suspended from $sustype->{title}"
    }];
  }

  # Security log (use Suspension Info superdoc as context node for API calls)
  $APP->securityLog(
    $DB->getNode('Suspension Info', 'superdoc'),
    $USER,
    "$target_user->{title} was unsuspended from $sustype->{title} by $USER->{title}"
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => "Suspension repealed: $target_user->{title} unsuspended from $sustype->{title}"
  }];
}

=head2 Private helper methods

=cut

sub _has_suspension_access
{
  my ($self, $USER) = @_;
  my $APP = $self->APP;

  return $APP->isChanop($USER) || $APP->isEditor($USER) || $APP->isAdmin($USER);
}

sub _can_manage_suspension_type
{
  my ($self, $USER, $sustype) = @_;
  my $APP = $self->APP;

  # Chanops can only manage chat/room/topic suspensions
  my %chanop_types = ('room' => 1, 'topic' => 1, 'chat' => 1);

  my $is_editor = $APP->isEditor($USER);
  my $is_admin = $APP->isAdmin($USER);
  my $is_chanop = $APP->isChanop($USER);

  # Editors and admins can manage all types
  return 1 if $is_editor || $is_admin;

  # Chanops can only manage specific types
  return $chanop_types{$sustype->{title}} ? 1 : 0;
}

sub _get_available_suspension_types
{
  my ($self, $USER) = @_;
  my $APP = $self->APP;
  my $DB = $self->DB;

  my $is_editor = $APP->isEditor($USER);
  my $is_admin = $APP->isAdmin($USER);
  my $is_chanop = $APP->isChanop($USER);

  my $sustype_type_id = $DB->getId($DB->getType('sustype'));

  my $where = "type_nodetype = $sustype_type_id AND title != 'email'";

  # Chanops can only see chat/room/topic types
  if ($is_chanop && !$is_editor && !$is_admin) {
    my @chanop_types = ('chat', 'room', 'topic');
    my $types_sql = join(', ', map { $DB->quote($_) } @chanop_types);
    $where .= " AND title IN ($types_sql)";
  }

  my $csr = $DB->sqlSelectMany(
    'node_id, title, doctext',
    'node LEFT JOIN document ON node_id = document_id',
    $where
  );

  my @types;
  while (my $row = $csr->fetchrow_hashref) {
    push @types, {
      node_id => $row->{node_id},
      title => $row->{title},
      description => $row->{doctext}
    };
  }

  return \@types;
}

__PACKAGE__->meta->make_immutable;
1;

package Everything::API::registrations;

use Moose;
extends 'Everything::API';

=head1 NAME

Everything::API::registrations - API for managing registry entries

=head1 DESCRIPTION

Provides REST API endpoints for managing user submissions to registries.

Routes:
  POST :registry_id/action/submit - Submit or update user's own entry
  POST :registry_id/action/delete - Delete user's own entry
  POST :registry_id/action/admin_delete - Admin delete any user's entry (admin only)
  GET  :registry_id/entries - Get all entries for a registry

=cut

around 'routes' => sub {
  my ($orig, $self) = @_;
  my $routes = $self->$orig;

  $routes->{':id/action/submit'} = 'submit(:id)';
  $routes->{':id/action/delete'} = 'delete_entry(:id)';
  $routes->{':id/action/admin_delete'} = 'admin_delete(:id)';
  $routes->{':id/entries'} = 'get_entries(:id)';

  return $routes;
};

=head2 get_entries

Get all entries for a registry.

=cut

sub get_entries {
  my ($self, $REQUEST, $registry_id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $APP->{db};

  # Check if user is logged in
  if ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in to view registry entries'
    }];
  }

  # Verify registry exists
  my $registry = $DB->getNodeById($registry_id);
  unless ($registry && $registry->{type}{title} eq 'registry') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Registry not found'
    }];
  }

  # Fetch all entries
  my $entries = $self->_fetch_entries($registry_id);

  # Check if current user has an entry
  my $user_entry = $self->_get_user_entry($user->node_id, $registry_id);

  return [$self->HTTP_OK, {
    success => 1,
    entries => $entries,
    user_entry => $user_entry
  }];
}

=head2 submit

Submit or update user's own registry entry.

POST body:
  { data: "value", comments: "optional", in_user_profile: 0|1 }

For date input_style, data can be:
  - "YYYY-MM-DD" for full date
  - "MM-DD" for date without year (secret year)

=cut

sub submit {
  my ($self, $REQUEST, $registry_id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $APP->{db};

  # Check if user is logged in
  if ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in to submit a registry entry'
    }];
  }

  # Verify registry exists
  my $registry = $DB->getNodeById($registry_id);
  unless ($registry && $registry->{type}{title} eq 'registry') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Registry not found'
    }];
  }

  # Get POST data
  my $postdata = $REQUEST->JSON_POSTDATA || {};
  my $data = $postdata->{data};
  my $comments = $postdata->{comments} // '';
  my $in_user_profile = $postdata->{in_user_profile} ? 1 : 0;

  unless (defined $data && length($data) > 0) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Data field is required'
    }];
  }

  # Validate data length
  if (length($data) > 255) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Data must be 255 characters or less'
    }];
  }

  # Validate comments length
  if (length($comments) > 512) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Comments must be 512 characters or less'
    }];
  }

  # Check if user already has an entry
  my $existing = $self->_get_user_entry($user->node_id, $registry_id);

  my $success;
  my $action;

  if ($existing) {
    # Update existing entry
    $success = $DB->sqlUpdate(
      'registration',
      {
        data => $data,
        comments => $comments,
        in_user_profile => $in_user_profile
      },
      "from_user = " . $user->node_id . " AND for_registry = $registry_id"
    );
    $action = 'updated';
  } else {
    # Insert new entry
    $success = $DB->sqlInsert(
      'registration',
      {
        from_user => $user->node_id,
        for_registry => $registry_id,
        data => $data,
        comments => $comments,
        in_user_profile => $in_user_profile
      }
    );
    $action = 'created';
  }

  unless ($success) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Failed to save entry'
    }];
  }

  # Return updated entry and all entries
  my $entries = $self->_fetch_entries($registry_id);
  my $user_entry = $self->_get_user_entry($user->node_id, $registry_id);

  return [$self->HTTP_OK, {
    success => 1,
    message => "Entry $action successfully",
    action => $action,
    entries => $entries,
    user_entry => $user_entry
  }];
}

=head2 delete_entry

Delete user's own registry entry.

=cut

sub delete_entry {
  my ($self, $REQUEST, $registry_id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $APP->{db};

  # Check if user is logged in
  if ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in'
    }];
  }

  # Verify registry exists
  my $registry = $DB->getNodeById($registry_id);
  unless ($registry && $registry->{type}{title} eq 'registry') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Registry not found'
    }];
  }

  # Delete the entry
  my $success = $DB->sqlDelete(
    'registration',
    "from_user = " . $user->node_id . " AND for_registry = $registry_id"
  );

  # Return updated entries
  my $entries = $self->_fetch_entries($registry_id);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Entry removed successfully',
    entries => $entries,
    user_entry => undef
  }];
}

=head2 admin_delete

Admin delete any user's registry entry.

POST body:
  { user_id: 12345 }

=cut

sub admin_delete {
  my ($self, $REQUEST, $registry_id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $APP->{db};

  # Admin only
  unless ($user->is_admin) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Permission denied: admin access required'
    }];
  }

  # Verify registry exists
  my $registry = $DB->getNodeById($registry_id);
  unless ($registry && $registry->{type}{title} eq 'registry') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Registry not found'
    }];
  }

  # Get target user_id
  my $postdata = $REQUEST->JSON_POSTDATA || {};
  my $target_user_id = $postdata->{user_id};

  unless ($target_user_id && $target_user_id =~ /^\d+$/) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'user_id is required'
    }];
  }

  # Verify target user exists
  my $target_user = $DB->getNodeById($target_user_id);
  unless ($target_user && $target_user->{type}{title} eq 'user') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'User not found'
    }];
  }

  # Delete the entry
  my $deleted = $DB->sqlDelete(
    'registration',
    "from_user = $target_user_id AND for_registry = $registry_id"
  );

  unless ($deleted) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Entry not found or already deleted'
    }];
  }

  $APP->devLog("Admin $user->{title} deleted registry entry for user $target_user->{title} from registry $registry_id");

  # Return updated entries
  my $entries = $self->_fetch_entries($registry_id);

  return [$self->HTTP_OK, {
    success => 1,
    message => "Deleted entry for $target_user->{title}",
    entries => $entries
  }];
}

=head2 _fetch_entries

Fetch all entries for a registry with user info.

=cut

sub _fetch_entries {
  my ($self, $registry_id) = @_;

  my $DB = $self->APP->{db};

  my $csr = $DB->sqlSelectMany(
    'r.*, n.title as username',
    'registration r JOIN node n ON r.from_user = n.node_id',
    "r.for_registry = $registry_id",
    'ORDER BY r.tstamp DESC'
  );

  return [] unless $csr;

  my @entries;
  while (my $row = $csr->fetchrow_hashref()) {
    push @entries, {
      user_id => $row->{from_user},
      username => $row->{username},
      data => $row->{data},
      comments => $row->{comments},
      in_user_profile => $row->{in_user_profile} ? 1 : 0,
      timestamp => $row->{tstamp}
    };
  }
  $csr->finish();

  return \@entries;
}

=head2 _get_user_entry

Get a specific user's entry for a registry.

=cut

sub _get_user_entry {
  my ($self, $user_id, $registry_id) = @_;

  my $DB = $self->APP->{db};

  my $row = $DB->sqlSelectHashref(
    'data, comments, in_user_profile, tstamp',
    'registration',
    "from_user = $user_id AND for_registry = $registry_id"
  );

  return unless $row;

  return {
    data => $row->{data},
    comments => $row->{comments},
    in_user_profile => $row->{in_user_profile} ? 1 : 0,
    timestamp => $row->{tstamp}
  };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 AUTHOR

Everything2 Development Team

=cut

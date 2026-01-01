package Everything::API::user;

use Moose;
extends 'Everything::API';

sub route {
  my ($self, $REQUEST, $extra) = @_;
  my $method = lc($REQUEST->request_method());

  # GET /api/user/sanctity?username=<name>
  if ($extra eq 'sanctity' && $method eq 'get') {
    return $self->sanctity($REQUEST);
  }

  # GET /api/user/available/<username>
  if ($extra =~ m{^available/(.+)$} && $method eq 'get') {
    return $self->check_available($REQUEST, $1);
  }

  # POST /api/user/edit - Update user profile
  if ($extra eq 'edit' && $method eq 'post') {
    return $self->edit_profile($REQUEST);
  }

  # Catchall for unmatched routes
  return $self->$method($REQUEST);
}

sub sanctity {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $query = $REQUEST->Vars;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Admin-only endpoint
  unless ($APP->isAdmin($user)) {
    return [$self->HTTP_FORBIDDEN, {
      success => 0,
      error => 'Admin access required'
    }];
  }

  # Get username parameter
  my $username = $query->{username};
  unless ($username) {
    return [$self->HTTP_BAD_REQUEST, {
      success => 0,
      error => 'Username parameter required'
    }];
  }

  # Look up user
  my $target_user = $DB->getNode($username, 'user');
  unless ($target_user) {
    # Try with underscores converted to spaces
    $username =~ s/_/ /g;
    $target_user = $DB->getNode($username, 'user');
  }

  unless ($target_user) {
    return [$self->HTTP_NOT_FOUND, {
      success => 0,
      error => "User '$username' not found"
    }];
  }

  return [$self->HTTP_OK, {
    success => 1,
    username => $target_user->{title},
    sanctity => int($target_user->{sanctity} || 0)
  }];
}

=head2 GET /api/user/available/<username>

Check if a username is available for registration.

Response:
{
  "available": true|false,
  "username": "the_username"
}

=cut

sub check_available
{
  my ($self, $REQUEST, $username) = @_;

  my $APP = $self->APP;

  unless ($username) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Username required'
    }];
  }

  # URL decode the username
  $username =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

  # Check username format first
  my $invalidName = '^\W+$|[\[\]\<\>\&\{\}\|\/\\\]| .*_|_.* |\s\s|^\s|\s$';
  if ($username =~ /$invalidName/) {
    return [$self->HTTP_OK, {
      available => 0,
      username => $username,
      reason => 'invalid_format'
    }];
  }

  # Check if username is taken
  my $taken = $APP->is_username_taken($username);

  return [$self->HTTP_OK, {
    available => $taken ? 0 : 1,
    username => $username
  }];
}

=head2 POST /api/user/edit

Update user profile information.

Accepts JSON with the following fields:
- realname: User's real name
- email: User's email address
- passwd: New password (optional, leave blank to keep current)
- user_doctext: User's bio/homenode text
- mission: Mission drive within everything
- specialties: User's specialties
- employment: School/company
- motto: User's motto
- remove_image: Set to true to remove user image
- bookmark_remove: Array of node IDs of bookmarks to remove
- bookmark_order: Array of node IDs in desired order (reorders bookmarks)

Response:
{
  "success": true|false,
  "changes": ["field1", "field2", ...],
  "error": "Error message if failed"
}

=cut

sub edit_profile {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Must be logged in
  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in to edit your profile'
    }];
  }

  # Parse JSON POST data
  my $data = $REQUEST->JSON_POSTDATA;
  unless ($data) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Missing or invalid JSON POST data'
    }];
  }

  # Get the node_id of the user being edited
  my $node_id = $data->{node_id};
  unless ($node_id) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Missing node_id parameter'
    }];
  }

  # Load the target user node
  my $target_user = $APP->node_by_id($node_id);
  unless ($target_user && $target_user->type->title eq 'user') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Invalid user node'
    }];
  }

  # Check permission: can only edit own profile (or admin)
  unless ($user->node_id == $node_id || $user->is_admin) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You can only edit your own profile'
    }];
  }

  my $nodedata = $target_user->NODEDATA;
  my $vars = $target_user->VARS || {};
  my @changes = ();

  # Update text fields in user table
  foreach my $field ('realname', 'email') {
    if (exists $data->{$field}) {
      $nodedata->{$field} = $data->{$field} // '';
      push @changes, $field;
    }
  }

  # Update doctext (bio)
  if (exists $data->{user_doctext}) {
    $nodedata->{doctext} = $data->{user_doctext} // '';
    push @changes, 'doctext';
  }

  # Update password if provided
  my $password_changed = 0;
  if ($data->{passwd} && length($data->{passwd}) > 0) {
    $target_user->set_password($data->{passwd});
    push @changes, 'password';
    $password_changed = 1;
  }

  # Update VARS fields (mission, specialties, employment, motto)
  foreach my $varfield ('mission', 'specialties', 'employment', 'motto') {
    if (exists $data->{$varfield}) {
      my $value = $data->{$varfield} // '';
      if (length($value) > 0) {
        $vars->{$varfield} = $value;
      } else {
        delete $vars->{$varfield};
      }
      push @changes, $varfield;
    }
  }

  # Handle image removal
  if ($data->{remove_image}) {
    if ($nodedata->{imgsrc}) {
      my $old_image = '/var/everything/www/' . $nodedata->{imgsrc};
      unlink($old_image) if -f $old_image;
      $nodedata->{imgsrc} = '';
      push @changes, 'image_removed';
    }
  }

  # Handle bookmark removal
  if ($data->{bookmark_remove}) {
    my @bookmarks_to_remove = ref($data->{bookmark_remove}) eq 'ARRAY'
      ? @{$data->{bookmark_remove}}
      : ($data->{bookmark_remove});
    if (@bookmarks_to_remove) {
      my $bookmark_linktype = $APP->node_by_name('bookmark', 'linktype');
      foreach my $bm_id (@bookmarks_to_remove) {
        $DB->sqlDelete('links',
          'from_node=' . $node_id . ' AND to_node=' . int($bm_id) .
          ' AND linktype=' . $bookmark_linktype->node_id);
      }
      push @changes, 'bookmarks_removed:' . scalar(@bookmarks_to_remove);
    }
  }

  # Handle bookmark reordering
  if ($data->{bookmark_order}) {
    my @bookmark_order = ref($data->{bookmark_order}) eq 'ARRAY'
      ? @{$data->{bookmark_order}}
      : ($data->{bookmark_order});
    if (@bookmark_order) {
      my $bookmark_linktype = $APP->node_by_name('bookmark', 'linktype');
      my $linktype_id = $bookmark_linktype->node_id;
      my $order_value = 10;  # Start at 10, increment by 10
      foreach my $bm_id (@bookmark_order) {
        $DB->sqlUpdate('links',
          { food => $order_value },
          'from_node=' . int($node_id) . ' AND to_node=' . int($bm_id) .
          ' AND linktype=' . $linktype_id);
        $order_value += 10;
      }
      push @changes, 'bookmarks_reordered:' . scalar(@bookmark_order);
    }
  }

  # Save the changes
  $DB->updateNode($nodedata, $user->NODEDATA);
  $target_user->set_vars($vars);

  my $response = [$self->HTTP_OK, {
    success => 1,
    changes => \@changes
  }];

  # If password was changed and user is editing their own profile,
  # return a new login cookie to keep them logged in
  if ($password_changed && $user->node_id == $node_id) {
    my $new_cookie = $REQUEST->cookie(
      -name => $self->CONF->cookiepass,
      -value => $target_user->title . '|' . $nodedata->{passwd}
    );
    $response->[2] = { cookie => $new_cookie };
  }

  return $response;
}

1;

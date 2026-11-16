package Everything::API::user;

use Moose;
extends 'Everything::API';

use Scalar::Util ();

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

  # POST /api/user/upload-image - Upload homenode image
  if ($extra eq 'upload-image' && $method eq 'post') {
    return $self->upload_image($REQUEST);
  }

  # POST /api/user/cure - Cure user infection (admin only)
  if ($extra eq 'cure' && $method eq 'post') {
    return $self->cure_infection($REQUEST);
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

  # Changing your own password or email needs your current password, so a session alone
  # can't take the account over. Admins editing someone else's profile aren't asked.
  if ($user->node_id == $node_id) {
    my $changing_password = defined $data->{passwd} && length $data->{passwd};
    my $changing_email = exists $data->{email}
      && ($data->{email} // '') ne ($target_user->NODEDATA->{email} // '');
    if ($changing_password || $changing_email) {
      my $current = $data->{current_password} // '';
      unless (length $current) {
        return [$self->HTTP_OK, {
          success => 0,
          code => 'current_password_required',
          error => 'Enter your current password to change your password or email.'
        }];
      }
      unless ($target_user->password_matches($current)) {
        return [$self->HTTP_OK, {
          success => 0,
          code => 'current_password_incorrect',
          error => 'Your current password is incorrect.'
        }];
      }
    }
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
    # Same cookie as login issues (Request::make_login_cookie): path=/ so it replaces the
    # site-wide cookie carrying the old password hash, plus SameSite, HttpOnly and Secure.
    $response->[2] = { cookie => $REQUEST->make_login_cookie($target_user) };
  }

  return $response;
}

=head2 POST /api/user/upload-image

Upload a homenode image. Accepts multipart/form-data with:
- imgsrc_file: The image file (JPEG, PNG, GIF, WebP or HEIC; up to 12MB)

The image is processed by Everything::HomenodeImage:
- Format identified from the file's contents (not its name or claimed type)
- Auto-oriented, metadata stripped
- Resized if exceeding dimension limits (200x400 normal, 400x800 for level>4 or gods)
- Re-encoded (JPEG, PNG or GIF; WebP becomes PNG, HEIC becomes JPEG)
- Uploaded to S3 with the content type of what was stored
- Queued for moderator approval (except admin uploads for another user)

Response:
{
  "success": true|false,
  "message": "Status message",
  "error": "Error message if failed"
}

=cut

sub upload_image {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;
  my $query = $REQUEST->cgi;

  # Must be logged in
  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in to upload an image'
    }];
  }

  # Determine target user (admins can upload for other users)
  my $target_user_id = $query->param('target_user_id');
  my $target_user;
  my $is_admin_action = 0;

  if ($target_user_id && $target_user_id != $user->node_id) {
    # Uploading for another user - must be admin
    unless ($user->is_admin) {
      return [$self->HTTP_OK, {
        success => 0,
        error => 'Only admins can upload images for other users'
      }];
    }
    $target_user = $APP->node_by_id($target_user_id);
    unless ($target_user && $target_user->type->title eq 'user') {
      return [$self->HTTP_OK, {
        success => 0,
        error => 'Invalid target user'
      }];
    }
    $is_admin_action = 1;
  } else {
    $target_user = $user;
  }

  my $nodedata = $target_user->NODEDATA;

  # Check if target user is suspended from homenode pics (skip for admin actions)
  if (!$is_admin_action && $APP->isSuspended($nodedata, 'homenodepic')) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Your homenode image privilege has been suspended'
    }];
  }

  # Check if user is allowed to have an image (admins bypass this check)
  unless ($is_admin_action) {
    my $can_have_image = 0;
    my $users_with_image = $DB->getNode('users with image', 'nodegroup');
    if ($users_with_image && Everything::isApproved($nodedata, $users_with_image)) {
      $can_have_image = 1;
    } elsif ($APP->getLevel($nodedata) >= 1) {
      $can_have_image = 1;
    }

    unless ($can_have_image) {
      return [$self->HTTP_OK, {
        success => 0,
        error => 'You must be level 1 or higher to upload a homenode image'
      }];
    }
  }

  # Get uploaded file
  my $fname = $query->upload('imgsrc_file');
  unless ($fname) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'No image file uploaded'
    }];
  }

  # Read the upload. Under the Plack request backing (#4129) it's a Plack::Request::Upload
  # spooled to a temp file; a legacy CGI filehandle is handled defensively.
  my $buf;
  if (ref($fname) && eval { $fname->can('path') }) {
    if (open(my $ufh, '<', $fname->path)) {
      binmode($ufh);
      local $/ = undef;
      $buf = <$ufh>;
      close($ufh);
    }
  } else {
    binmode($fname);
    local $/ = undef;
    $buf = <$fname>;
  }

  my $is_upload = Scalar::Util::blessed($fname) ? 1 : 0;
  my $client_name = ($is_upload && $fname->can('filename')) ? ($fname->filename // '') : '';
  my ($client_ext) = $client_name =~ /\.(\w{1,8})$/;
  $self->_upload_log(
    bytes       => length($buf // ''),
    client_type => ($is_upload && $fname->can('content_type')) ? $fname->content_type : undef,
    client_ext  => lc($client_ext // ''),
  );

  # Identify, decode, orient, strip, resize and re-encode (Everything::HomenodeImage). The
  # browser's file name and claimed type are ignored; the format comes from the bytes.
  my $is_god = $is_admin_action || $APP->isAdmin($nodedata);
  my $user_level = $APP->getLevel($nodedata);
  require Everything::HomenodeImage;
  my $processed = Everything::HomenodeImage->process($buf,
    max_width  => ($user_level > 4 || $is_god) ? 400 : 200,
    max_height => ($user_level > 4 || $is_god) ? 800 : 400,
  );
  unless ($processed->{ok}) {
    return [$self->HTTP_OK, { success => 0, error => $processed->{error} }];
  }
  $self->_upload_log(
    detected => $processed->{format},
    stored_type => $processed->{content_type},
    width => $processed->{width}, height => $processed->{height}, resized => $processed->{resized},
  );

  # Storing needs the production S3 bucket. Elsewhere, report what processing produced so the
  # whole pipeline can still be exercised by hand.
  unless ($self->CONF->environment eq 'production') {
    return [$self->HTTP_OK, {
      success => 0,
      error => "This image is fine ($processed->{width}x$processed->{height} $processed->{content_type}), "
        . 'but uploads are only stored in production.'
    }];
  }

  require Everything::S3;
  my $s3 = Everything::S3->new('homenodeimages');
  unless ($s3) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Could not connect to image storage'
    }];
  }

  # Build S3 key name from target user's username
  my $basename = $target_user->title;
  $basename =~ s/\W/_/gs;

  # Upload to S3
  unless ($s3->upload_data($basename, $processed->{data}, { content_type => $processed->{content_type} })) {
    $self->_upload_log(outcome => 'storage_failed');
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Failed to upload image. Please try again.'
    }];
  }

  # Update user node with image path
  $nodedata->{imgsrc} = "/$basename";
  $DB->updateNode($nodedata, $nodedata);

  # Queue for moderator approval (skip for admin actions - trust the admin)
  unless ($is_admin_action) {
    $DB->getDatabaseHandle()->do(
      'REPLACE INTO newuserimage SET newuserimage_id = ?',
      undef,
      $target_user->node_id
    );
  }

  my $message = 'Image saved.';
  if ($processed->{resized}) {
    $message = "Image saved, resized to $processed->{width}x$processed->{height}.";
  }
  if ($is_admin_action) {
    $message .= " Image uploaded for " . $target_user->title . ".";
  } else {
    $message .= ' Your image will be reviewed by moderators.';
  }

  return [$self->HTTP_OK, {
    success => 1,
    message => $message,
    imgsrc => "/$basename"
  }];
}

=head2 POST /api/user/cure

Cure a user's infection (remove bot flag). Admin-only endpoint.

Infection is a primitive bot detection mechanism that flags accounts
created with suspicious characteristics (e.g., from known bad IPs,
or sharing cookies with locked accounts).

Request body (JSON):
{
  "user_id": <node_id of user to cure>
}

Response:
{
  "success": true|false,
  "message": "Status message",
  "error": "Error message if failed"
}

=cut

# Every upload attempt leaves one log line (Application::log_event): who, what came in, what
# happened. Refusals are HTTP 200 with success 0, so nothing else would record them.
around 'upload_image' => sub {
  my ($orig, $self, $REQUEST) = @_;
  local $self->{upload_log} = {};
  my $response = $self->$orig($REQUEST);

  my $body = (ref($response) eq 'ARRAY' && ref($response->[1]) eq 'HASH') ? $response->[1] : {};
  my %fields = (
    user    => ($REQUEST->user ? $REQUEST->user->title : undef),
    outcome => $body->{success} ? 'stored' : 'refused',
    ($body->{success} ? () : (reason => $body->{error})),
    %{ $self->{upload_log} },
  );
  my $target = eval { $REQUEST->cgi->param('target_user_id') };
  $fields{target_user_id} = int($target) if $target;
  $self->APP->log_event('homenode_image_upload', \%fields);

  return $response;
};

sub _upload_log {
  my ($self, %fields) = @_;
  $self->{upload_log} = { %{ $self->{upload_log} || {} }, %fields };
  return;
}

sub cure_infection {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Must be logged in
  if ($APP->isGuest($user)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'You must be logged in'
    }];
  }

  # Admin-only endpoint
  unless ($user->is_admin) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Admin access required to cure infections'
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

  # Get user_id parameter
  my $target_user_id = $data->{user_id};
  unless ($target_user_id && $target_user_id =~ /^\d+$/) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Missing or invalid user_id parameter'
    }];
  }

  # Load target user
  my $target_user = $DB->getNodeById(int($target_user_id));
  unless ($target_user && $target_user->{type}{title} eq 'user') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'User not found'
    }];
  }

  # Check if user is actually infected
  my $target_vars = Everything::getVars($target_user);
  unless ($target_vars->{infected}) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'User is not infected'
    }];
  }

  # Cure the infection
  $target_vars->{infected} = 0;
  Everything::setVars($target_user, $target_vars);

  # Log the action
  $APP->devLog("Admin " . $user->title . " cured infection for user " . $target_user->{title});

  return [$self->HTTP_OK, {
    success => 1,
    message => "Infection cured for user " . $target_user->{title},
    username => $target_user->{title}
  }];
}

1;

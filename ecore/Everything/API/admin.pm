package Everything::API::admin;

use Moose;
extends 'Everything::API';

# Admin API for system node management
#
# Provides edit capabilities for internal system nodes (maintenance, htmlcode,
# htmlpage, nodelet, nodetype) through a modal interface in Master Control.
#
# This consolidates edit functionality for system nodes, allowing us to
# deprecate the legacy *_edit_page htmlpage delegation functions.

# Whitelist of node types that can be edited through this API
my @EDITABLE_TYPES = qw(
  maintenance
  htmlcode
  htmlpage
  nodelet
  nodetype
  superdoc
  restricted_superdoc
  oppressor_superdoc
  fullpage
);

sub routes
{
  return {
    "node/:id" => "get_node(:id)",
    "node/:id/edit" => "edit_node(:id)",
    "writeup/:id/insure" => "insure_writeup(:id)",
    "writeup/:id/remove" => "remove_writeup(:id)",
    "writeup/:id/remove_vote" => "remove_vote(:id)",
    "writeup/:id/remove_cool" => "remove_cool(:id)",
  }
}

=head1 Everything::API::admin

Admin API for system node management.

=head2 get_node

GET /api/admin/node/:id

Returns node data for editing. Only returns data for whitelisted system node types.

Response:
{
  "node_id": 123,
  "title": "my maintenance node",
  "nodeType": "maintenance",
  "author_user": { "node_id": 113, "title": "root" },
  "maintainedby_user": { "node_id": 113, "title": "root" },
  "createtime": "2025-01-01 00:00:00",
  "editableFields": ["title", "maintainedby_user"]
}

=cut

sub get_node
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use admin API
  unless ($user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Admin access required',
      message => 'Only administrators can access the admin API'
    }];
  }

  my $node = $APP->node_by_id(int($id));
  unless ($node)
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Node not found',
      message => "No node found with ID $id"
    }];
  }

  my $nodetype = $node->type->title;

  # Check if this node type is editable through admin API
  unless (grep { $_ eq $nodetype } @EDITABLE_TYPES)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Node type not editable',
      message => "Node type '$nodetype' cannot be edited through the admin API"
    }];
  }

  # Get author and maintainer info
  my $author = $node->author_user ? $APP->node_by_id($node->author_user) : undef;
  my $maintainer = $node->NODEDATA->{maintainedby_user}
    ? $APP->node_by_id($node->NODEDATA->{maintainedby_user})
    : undef;

  # Determine editable fields based on node type
  my @editable_fields = ('title', 'maintainedby_user');

  return [$self->HTTP_OK, {
    node_id => $node->node_id,
    title => $node->title,
    nodeType => $nodetype,
    author_user => $author ? {
      node_id => $author->node_id,
      title => $author->title
    } : undef,
    maintainedby_user => $maintainer ? {
      node_id => $maintainer->node_id,
      title => $maintainer->title
    } : undef,
    createtime => $node->NODEDATA->{createtime},
    editableFields => \@editable_fields
  }];
}

=head2 edit_node

POST /api/admin/node/:id/edit

Update a system node's metadata.

Request body:
{
  "title": "new title",
  "maintainedby_user": 113
}

Only fields in editableFields can be updated.

=cut

sub edit_node
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use admin API
  unless ($user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Admin access required',
      message => 'Only administrators can access the admin API'
    }];
  }

  my $node = $APP->node_by_id(int($id));
  unless ($node)
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Node not found',
      message => "No node found with ID $id"
    }];
  }

  my $nodetype = $node->type->title;

  # Check if this node type is editable through admin API
  unless (grep { $_ eq $nodetype } @EDITABLE_TYPES)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Node type not editable',
      message => "Node type '$nodetype' cannot be edited through the admin API"
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  unless ($data && ref($data) eq 'HASH')
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Invalid request body',
      message => 'Request body must be a JSON object'
    }];
  }

  # Get the node hashref for direct modification
  my $NODE = $node->NODEDATA;
  my @updated_fields;

  # Update title if provided
  if (exists $data->{title})
  {
    my $new_title = $data->{title};

    # Validate title
    if (!defined($new_title) || length($new_title) == 0)
    {
      return [$self->HTTP_BAD_REQUEST, {
        error => 'Invalid title',
        message => 'Title cannot be empty'
      }];
    }

    if (length($new_title) > 240)
    {
      return [$self->HTTP_BAD_REQUEST, {
        error => 'Invalid title',
        message => 'Title cannot exceed 240 characters'
      }];
    }

    # Check for duplicate title of same type
    if ($new_title ne $node->title)
    {
      my $existing = $APP->node_by_name($new_title, $nodetype);
      if ($existing && $existing->node_id != $node->node_id)
      {
        return [$self->HTTP_CONFLICT, {
          error => 'Duplicate title',
          message => "A $nodetype with title '$new_title' already exists"
        }];
      }
    }

    $NODE->{title} = $new_title;
    push @updated_fields, 'title';
  }

  # Update maintainedby_user if provided
  if (exists $data->{maintainedby_user})
  {
    my $maintainer_id = $data->{maintainedby_user};

    if (defined($maintainer_id))
    {
      # Validate maintainer exists and is a user
      my $maintainer = $APP->node_by_id(int($maintainer_id));
      unless ($maintainer && $maintainer->type->title eq 'user')
      {
        return [$self->HTTP_BAD_REQUEST, {
          error => 'Invalid maintainer',
          message => 'maintainedby_user must be a valid user node ID'
        }];
      }
    }

    $NODE->{maintainedby_user} = $maintainer_id;
    push @updated_fields, 'maintainedby_user';
  }

  # If nothing to update
  unless (@updated_fields)
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'No changes',
      message => 'No editable fields provided in request'
    }];
  }

  # Save the node
  $DB->updateNode($NODE, -1);

  # Log the edit
  $APP->securityLog(
    $node->NODEDATA,
    $user->NODEDATA,
    $user->title . " edited $nodetype '" . $node->title . "' via admin API. Fields: " . join(', ', @updated_fields)
  );

  # Return updated node data
  my $maintainer = $NODE->{maintainedby_user}
    ? $APP->node_by_id($NODE->{maintainedby_user})
    : undef;

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Node updated successfully',
    node_id => $node->node_id,
    title => $NODE->{title},
    nodeType => $nodetype,
    maintainedby_user => $maintainer ? {
      node_id => $maintainer->node_id,
      title => $maintainer->title
    } : undef,
    updatedFields => \@updated_fields
  }];
}

=head2 insure_writeup

POST /api/admin/writeup/:id/insure

Insure or uninsure a writeup. If already insured, will uninsure it.
Editors only.

=cut

sub insure_writeup
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only editors can insure writeups
  unless ($user->is_editor)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Editor access required',
      message => 'Only editors can insure writeups'
    }];
  }

  my $writeup = $APP->node_by_id(int($id));
  unless ($writeup && $writeup->type->title eq 'writeup')
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Writeup not found',
      message => "No writeup found with ID $id"
    }];
  }

  my $NODE = $writeup->NODEDATA;
  my $author = $APP->node_by_id($NODE->{author_user});

  # Get insured publication status ID
  my $insured_status = $DB->getNode('insured', 'publication_status');
  unless ($insured_status)
  {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      error => 'Configuration error',
      message => 'insured publication_status node not found'
    }];
  }

  # Get current publication status from draft table
  my $current_status = $DB->sqlSelect('publication_status', 'draft', "draft_id=" . $NODE->{node_id});
  $current_status ||= 0;

  my $action;
  if ($current_status == $insured_status->{node_id})
  {
    # Uninsure
    $DB->sqlUpdate('draft', {publication_status => 0}, "draft_id=" . $NODE->{node_id});
    $action = 'uninsured';

    # Remove from publish table
    $DB->sqlDelete("publish", "publish_id=" . $NODE->{node_id});

    # Add nodenote
    $APP->addNodeNote($writeup, "Uninsured by [$user->{title}\[user]]", $user);

    # Security log
    $APP->securityLog(
      $DB->getNode("insure", "opcode"),
      $user->NODEDATA,
      $user->title . " uninsured \"$NODE->{title}\" by " . ($author ? $author->title : "unknown")
    );
  }
  else
  {
    # Insure
    $DB->sqlUpdate('draft', {publication_status => $insured_status->{node_id}}, "draft_id=" . $NODE->{node_id});
    $action = 'insured';

    # Add to publish table (check if not already there)
    my $existing = $DB->sqlSelect('publish_id', 'publish', "publish_id=" . $NODE->{node_id});
    if (!$existing) {
      $DB->sqlInsert("publish", {
        publish_id => $NODE->{node_id},
        publisher => $user->node_id
      });
    }

    # Add nodenote
    $APP->addNodeNote($writeup, "Insured by [$user->{title}\[user]]", $user);

    # Security log
    $APP->securityLog(
      $DB->getNode("insure", "opcode"),
      $user->NODEDATA,
      $user->title . " insured \"$NODE->{title}\" by " . ($author ? $author->title : "unknown")
    );
  }

  my $response = {
    success => 1,
    message => "Writeup $action",
    node_id => $writeup->node_id,
    action => $action
  };

  # Include insured_by info if action was 'insured'
  if ($action eq 'insured')
  {
    $response->{insured_by} = {
      node_id => $user->node_id,
      title => $user->title
    };
  }

  return [$self->HTTP_OK, $response];
}

=head2 remove_writeup

POST /api/admin/writeup/:id/remove

Remove a writeup (return to draft status) or delete it.
Authors can remove their own writeups. Editors can remove any writeup with a reason.

Request body:
{
  "reason": "reason for removal" (required for editors removing others' writeups)
}

=cut

sub remove_writeup
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Guest users cannot remove writeups
  if ($user->is_guest)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Login required',
      message => 'You must be logged in to remove a writeup'
    }];
  }

  my $writeup = $APP->node_by_id(int($id));
  unless ($writeup && $writeup->type->title eq 'writeup')
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Writeup not found',
      message => "No writeup found with ID $id"
    }];
  }

  my $NODE = $writeup->NODEDATA;
  my $is_author = $NODE->{author_user} == $user->node_id;
  my $is_editor = $user->is_editor;

  # Only author or editor can remove
  unless ($is_author || $is_editor)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Access denied',
      message => 'Only the author or an editor can remove this writeup'
    }];
  }

  # Get reason from request body (required for editors removing others' writeups)
  my $data = $REQUEST->JSON_POSTDATA;
  my $reason = $data->{reason} || '';

  if ($is_editor && !$is_author && !$reason)
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Reason required',
      message => 'Editors must provide a reason when removing writeups by other users'
    }];
  }

  # Get draft type and private publication status
  my $draft_type = $DB->getType('draft');
  unless ($draft_type)
  {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      error => 'Configuration error',
      message => 'draft nodetype not found'
    }];
  }

  my $private_status = $DB->getNode('private', 'publication_status');
  unless ($private_status)
  {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      error => 'Configuration error',
      message => 'private publication_status node not found'
    }];
  }

  # Get parent e2node before we start modifying the writeup
  my $node_id = $NODE->{node_id};
  my $E2NODE = $NODE->{parent_e2node} ? $APP->node_by_id($NODE->{parent_e2node}) : undef;

  # Convert writeup to draft - combined update on node and draft tables
  # This matches legacy unpublishwriteup behavior
  my $update_result = $DB->sqlUpdate('node, draft', {
    type_nodetype => $draft_type->{node_id},
    publication_status => $private_status->{node_id}
  }, "node_id=$node_id AND draft_id=$node_id");

  # Explicitly commit the transaction
  $DB->{dbh}->commit() unless $DB->{dbh}->{AutoCommit};

  # Update the NODE hashref to reflect the changes
  $NODE->{type_nodetype} = $draft_type->{node_id};
  $NODE->{type} = $draft_type;

  # Delete from writeup table (writeup-specific data no longer needed)
  $DB->sqlDelete('writeup', "writeup_id=$node_id");

  # Remove from parent e2node's nodegroup BEFORE cache operations
  if ($E2NODE)
  {
    $DB->removeFromNodegroup($E2NODE->NODEDATA, $NODE, -1);
  }

  # Cache management - increment version and remove from cache
  # The node is now in the wrong type cache (was writeup, now draft)
  $DB->getCache->incrementGlobalVersion($NODE);
  $DB->getCache->removeNode($NODE);

  # Delete from newwriteup table and update
  $DB->sqlDelete('newwriteup', "node_id=$node_id");
  $APP->updateNewWriteups();

  # Delete from publish table
  $DB->sqlDelete('publish', "publish_id=$node_id");

  # Delete category links
  my $category_linktype = $DB->getNode('category', 'linktype');
  if ($category_linktype)
  {
    $DB->sqlDelete('links',
      "to_node=$node_id OR (from_node=$node_id AND linktype=" . $category_linktype->{node_id} . ")");
  }

  # Add nodenote
  my $user_title = $user->title // 'unknown';
  my $note_success = eval {
    if ($is_author && !$is_editor)
    {
      $APP->addNodeNote($writeup, "Returned to drafts by author [$user_title\[user]]", $user);
    }
    elsif ($reason)
    {
      $APP->addNodeNote($writeup, "Removed by [$user_title\[user]]: $reason", $user);
    }
    else
    {
      $APP->addNodeNote($writeup, "Returned to drafts by [$user_title\[user]]", $user);
    }
    return 1;
  };
  unless ($note_success)
  {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      error => 'Failed to add nodenote',
      message => "addNodeNote failed: $@"
    }];
  }

  # Security log for editor removals
  if ($is_editor)
  {
    my $author = $APP->node_by_id($NODE->{author_user});
    my $log_msg = $user->title . " removed \"$NODE->{title}\" by " . ($author ? $author->title : "unknown");
    $log_msg .= ": $reason" if $reason;

    $APP->securityLog(
      $DB->getNode("remove", "opcode") || $NODE,
      $user->NODEDATA,
      $log_msg
    );
  }

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Writeup removed and returned to draft status',
    node_id => $writeup->node_id
  }];
}

=head2 remove_vote

POST /api/admin/writeup/:id/remove_vote

Remove the current user's vote on a writeup (admin only, for testing).

=cut

sub remove_vote
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use this testing endpoint
  unless ($user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Admin access required',
      message => 'Only administrators can remove votes'
    }];
  }

  my $writeup = $APP->node_by_id(int($id));
  unless ($writeup && $writeup->type->title eq 'writeup')
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Writeup not found',
      message => "No writeup found with ID $id"
    }];
  }

  # Check if user has voted
  my $vote = $DB->sqlSelectHashref("*", "vote", "voter_user=" . $user->node_id . " AND vote_id=" . $writeup->node_id);
  unless ($vote)
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'No vote found',
      message => 'You have not voted on this writeup'
    }];
  }

  # Remove the vote
  $DB->sqlDelete("vote", "voter_user=" . $user->node_id . " AND vote_id=" . $writeup->node_id);

  # Update reputation
  my $NODE = $writeup->NODEDATA;
  $NODE->{reputation} = ($NODE->{reputation} || 0) - $vote->{weight};
  $DB->updateNode($NODE, -1);

  # Restore user's vote
  my $USER = $user->NODEDATA;
  $USER->{votesleft} = ($USER->{votesleft} || 0) + 1;
  $DB->updateNode($USER, -1);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Vote removed',
    node_id => $writeup->node_id,
    vote_removed => $vote->{weight}
  }];
}

=head2 remove_cool

POST /api/admin/writeup/:id/remove_cool

Remove the current user's C! on a writeup (admin only, for testing).

=cut

sub remove_cool
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use this testing endpoint
  unless ($user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Admin access required',
      message => 'Only administrators can remove C!s'
    }];
  }

  my $writeup = $APP->node_by_id(int($id));
  unless ($writeup && $writeup->type->title eq 'writeup')
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Writeup not found',
      message => "No writeup found with ID $id"
    }];
  }

  # Check if user has C!ed
  my $cool = $DB->sqlSelectHashref("*", "coolwriteups", "cooledby_user=" . $user->node_id . " AND coolwriteups_id=" . $writeup->node_id);
  unless ($cool)
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'No C! found',
      message => 'You have not C!ed this writeup'
    }];
  }

  # Remove the C!
  $DB->sqlDelete("coolwriteups", "cooledby_user=" . $user->node_id . " AND coolwriteups_id=" . $writeup->node_id);

  # Decrement the cooled count on the writeup
  my $WRITEUP = $writeup->NODEDATA;
  $WRITEUP->{cooled} = ($WRITEUP->{cooled} || 0) - 1;
  $WRITEUP->{cooled} = 0 if $WRITEUP->{cooled} < 0;  # Prevent negative
  $DB->updateNode($WRITEUP, -1);

  # Restore user's C!
  my $vars = Everything::getVars($user->NODEDATA);
  $vars->{cools} = ($vars->{cools} || 0) + 1;
  Everything::setVars($user->NODEDATA, $vars);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'C! removed',
    node_id => $writeup->node_id
  }];
}

around ['insure_writeup', 'remove_writeup', 'remove_vote', 'remove_cool'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

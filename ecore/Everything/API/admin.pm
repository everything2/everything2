package Everything::API::admin;
use Everything::SecurityLog qw(:events);
use Everything qw(setVars);

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
    "node/:id/basicedit" => "basicedit_node(:id)",
    "writeup/:id/insure" => "insure_writeup(:id)",
    "writeup/:id/remove" => "remove_writeup(:id)",
    "remove_writeups" => "remove_writeups",
    "writeup/:id/remove_vote" => "remove_vote(:id)",
    "writeup/:id/remove_cool" => "remove_cool(:id)",
    "user/:id/lock" => "lock_user(:id)",
    "user/:id/unlock" => "unlock_user(:id)",
    "users/cleanup" => "cleanup_users",
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
  $APP->securityLog(SECLOG_NODE_EDIT,
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
  my $e2node = $NODE->{parent_e2node} ? $APP->node_by_id($NODE->{parent_e2node}) : undef;

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

    # Add nodenote to e2node (user attribution is added automatically by addNodeNote)
    if ($e2node)
    {
      $APP->addNodeNote($e2node, "Uninsured", $user);
    }

    # Security log
    $APP->securityLog(SECLOG_WRITEUP_INSURANCE,
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

    # Add nodenote to e2node (user attribution is added automatically by addNodeNote)
    if ($e2node)
    {
      $APP->addNodeNote($e2node, "Insured", $user);
    }

    # Security log
    $APP->securityLog(SECLOG_WRITEUP_INSURANCE,
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

  # Determine which publication status to use:
  # - Author removing their own writeup -> private (they can continue editing)
  # - Editor removing someone else's writeup -> removed (can be republished later)
  my $status_name = ($is_editor && !$is_author) ? 'removed' : 'private';
  my $target_status = $DB->getNode($status_name, 'publication_status');
  unless ($target_status)
  {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      error => 'Configuration error',
      message => "$status_name publication_status node not found"
    }];
  }

  # Get parent e2node before we start modifying the writeup
  my $node_id = $NODE->{node_id};
  my $E2NODE = $NODE->{parent_e2node} ? $APP->node_by_id($NODE->{parent_e2node}) : undef;

  # Convert writeup to draft:
  # 1. Create draft table row (writeups don't have one, drafts do)
  # 2. Update node type to draft
  # 3. Delete writeup table row

  # Check if draft row already exists (shouldn't, but be safe)
  my $draft_exists = $DB->sqlSelect('draft_id', 'draft', "draft_id=$node_id");

  if (!$draft_exists) {
    # Create new draft row with appropriate publication status
    $DB->sqlInsert('draft', {
      draft_id => $node_id,
      publication_status => $target_status->{node_id}
    });
  } else {
    # Update existing draft row to appropriate status
    $DB->sqlUpdate('draft', {
      publication_status => $target_status->{node_id}
    }, "draft_id=$node_id");
  }

  # Update node type to draft
  $DB->sqlUpdate('node', {
    type_nodetype => $draft_type->{node_id}
  }, "node_id=$node_id");

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

    # For editor removals, create a parent_node link so we know which e2node to republish to
    if ($is_editor && !$is_author)
    {
      my $parent_linktype = $DB->getNode('parent_node', 'linktype');
      if ($parent_linktype)
      {
        # Remove any existing parent_node link first
        $DB->sqlDelete('links', "from_node=$node_id AND linktype=" . $parent_linktype->{node_id});
        # Create new parent_node link
        $DB->sqlInsert('links', {
          from_node => $node_id,
          to_node => $E2NODE->node_id,
          linktype => $parent_linktype->{node_id}
        });
      }
    }
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

  # Add nodenote to the e2node (not the writeup)
  # User attribution is added automatically by addNodeNote
  if ($E2NODE)
  {
    my $note_success = eval {
      if ($is_author && !$is_editor)
      {
        $APP->addNodeNote($E2NODE, "Returned to drafts by author", $user);
      }
      elsif ($reason)
      {
        $APP->addNodeNote($E2NODE, "Removed: $reason", $user);
      }
      else
      {
        $APP->addNodeNote($E2NODE, "Returned to drafts", $user);
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
  }

  # Reverse the +5 XP that publishing the writeup granted (#3415). The legacy
  # remove path deducted this (adjustExp(author, -5)); the React migration
  # dropped it, so XP only ever went up — publish/remove/republish could farm
  # it. Always deduct from the *author* (not the remover), matching publish
  # which credits the author. numwriteups is left alone — it's recomputed from
  # an actual count (cached hourly) in Controller/user.pm and self-heals.
  $APP->adjustExp( $NODE->{author_user}, -5 );

  # Security log for editor removals
  if ($is_editor)
  {
    my $author = $APP->node_by_id($NODE->{author_user});
    my $log_msg = $user->title . " removed \"$NODE->{title}\" by " . ($author ? $author->title : "unknown");
    $log_msg .= ": $reason" if $reason;

    $APP->securityLog(SECLOG_NODE_REMOVE,
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

=head2 remove_writeups

POST /api/admin/remove_writeups

Bulk editorial writeup removal -- the migrated `remove` opcode path used by AltarOfSacrifice.
Body: { "writeup_ids": [...], "reason": "..." } OR { "author_id": N, "reason": "..." } (remove ALL of
that author's writeups). Editor-only; a reason is required. Reuses the single-writeup remove_writeup for
each removal, and layers on the opcode's bulk policy: skip insured writeups, and Klaproth-notify each
author (with the author's `no_notify_kill` opt-out and a self-removal skip). The single-writeup endpoint
stays silent (its existing behavior is unchanged).

=cut

sub remove_writeups
{
  my ($self, $REQUEST) = @_;
  my $user = $REQUEST->user;
  my $APP  = $self->APP;
  my $DB   = $self->DB;

  return [$self->HTTP_OK, { success => 0, error => 'Editors only' }]
    unless $user->is_editor;

  my $data   = $REQUEST->JSON_POSTDATA || {};
  my $reason = $data->{reason} // '';
  $reason =~ s/^\s+|\s+$//g;
  return [$self->HTTP_OK, { success => 0, error => 'A removal reason is required' }]
    unless length $reason;

  # Resolve the target list: explicit writeup_ids, or ALL of author_id's writeups.
  my @ids;
  if (defined $data->{author_id}) {
    my $author = $APP->node_by_id(int($data->{author_id}));
    return [$self->HTTP_OK, { success => 0, error => 'Author not found' }]
      unless $author && $author->type->title eq 'user';
    @ids = @{ $DB->selectNodeWhere({ author_user => $author->node_id }, 'writeup') || [] };
  } elsif (ref $data->{writeup_ids} eq 'ARRAY') {
    @ids = map { int($_) } @{ $data->{writeup_ids} };
  }
  return [$self->HTTP_OK, { success => 0, error => 'No writeups specified' }]
    unless @ids;

  my $klaproth = $DB->getNode('Klaproth', 'user');
  my (@removed, @skipped);

  foreach my $id (@ids) {
    my $wu = $APP->node_by_id($id);
    unless ($wu && $wu->type->title eq 'writeup') {
      push @skipped, { node_id => $id, reason => 'not a writeup' };
      next;
    }
    my $NODE = $wu->NODEDATA;
    # Insured (or otherwise protected) writeups carry a non-zero draft publication_status -> skip.
    if ($DB->sqlSelect('publication_status', 'draft', "draft_id=$id")) {
      push @skipped, { node_id => $id, reason => 'insured' };
      next;
    }

    # Capture before removal -- remove_writeup turns the node into a draft.
    my $author_id = $NODE->{author_user};
    my $parent    = $NODE->{parent_e2node} ? $APP->node_by_id($NODE->{parent_e2node}) : undef;
    my $title     = ($parent ? $parent->title : undef) || $wu->title;

    my $res = $self->remove_writeup($REQUEST, $id);   # full, tested single-writeup removal
    unless (ref $res eq 'ARRAY' && $res->[0] == $self->HTTP_OK) {
      push @skipped, { node_id => $id, reason => ($res->[1]{message} || $res->[1]{error} || 'removal failed') };
      next;
    }
    push @removed, $id;

    # Author notification (opcode parity): Klaproth -> author, with opt-outs.
    next unless $klaproth && $author_id && $author_id != $user->node_id;   # skip self
    my $author = $APP->node_by_id($author_id);
    next if $author && $author->VARS->{no_notify_kill};                    # author opted out
    my $byline = $author ? " [by " . $author->title . "]" : "";
    $APP->sendPrivateMessage($klaproth, $author_id,
      "I removed your writeup [$title]$byline: $reason. It has been sent to your [Drafts[superdoc]].");
  }

  return [$self->HTTP_OK, {
    success       => 1,
    removed       => \@removed,
    removed_count => scalar(@removed),
    skipped       => \@skipped,
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

  # Sync rep from source of truth instead of delta math. See cluster
  # #4137 et al — delta accumulated drift over years from missed/concurrent
  # write paths.
  my $NODE = $writeup->NODEDATA;
  $NODE->{reputation} = $DB->sqlSelect(
      'COALESCE(SUM(weight),0)', 'vote',
      'vote_id=' . $writeup->node_id
  ) // 0;
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

  # Sync the cool count from source of truth (#4137 cluster). Was delta
  # math (`cooled - 1`, clamped to 0) which silently drifted when sibling
  # paths inserted/deleted coolwriteups rows without coming through here.
  my $WRITEUP = $writeup->NODEDATA;
  $WRITEUP->{cooled} = $DB->sqlSelect(
      'COUNT(*)', 'coolwriteups',
      'coolwriteups_id=' . $writeup->node_id
  ) // 0;
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

=head2 lock_user

POST /api/admin/user/:id/lock

Lock a user account. This prevents login and marks all their public messages for deletion.
Admin (god) only.

Response:
{
  "success": 1,
  "message": "Account locked",
  "user": { "node_id": 123, "title": "username" }
}

=cut

sub lock_user
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins (gods) can lock accounts
  unless ($user->is_admin)
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Admin access required',
      message => 'Only administrators can lock user accounts'
    }];
  }

  my $target = $APP->node_by_id(int($id));
  unless ($target && $target->type->title eq 'user')
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'User not found',
      message => "No user found with ID $id"
    }];
  }

  my $TARGET = $target->NODEDATA;

  # Check if already locked
  if ($TARGET->{acctlock})
  {
    my $locker = $APP->node_by_id($TARGET->{acctlock});
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Already locked',
      message => 'This account is already locked' . ($locker ? ' by ' . $locker->title : '')
    }];
  }

  # Lock the account (shared logic, also used by the mass-cleanup tool)
  $self->_do_lock_account($TARGET, $user->NODEDATA);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Account locked',
    user => {
      node_id => $target->node_id,
      title => $target->title
    },
    locked_by => {
      node_id => $user->node_id,
      title => $user->title
    }
  }];
}

=head2 unlock_user

POST /api/admin/user/:id/unlock

Unlock a user account.
Admin (god) only.

Response:
{
  "success": 1,
  "message": "Account unlocked",
  "user": { "node_id": 123, "title": "username" }
}

=cut

sub unlock_user
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins (gods) can unlock accounts
  unless ($user->is_admin)
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Admin access required',
      message => 'Only administrators can unlock user accounts'
    }];
  }

  my $target = $APP->node_by_id(int($id));
  unless ($target && $target->type->title eq 'user')
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'User not found',
      message => "No user found with ID $id"
    }];
  }

  my $TARGET = $target->NODEDATA;

  # Check if not locked
  unless ($TARGET->{acctlock})
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Not locked',
      message => 'This account is not locked'
    }];
  }

  # Get who locked it before we clear it
  my $locker = $APP->node_by_id($TARGET->{acctlock});

  # Unlock the account
  $TARGET->{acctlock} = 0;
  $DB->updateNode($TARGET, -1);

  # Security log
  $APP->securityLog(SECLOG_ACCOUNT_UNLOCK,
    $user->NODEDATA,
    $target->title . "'s account was unlocked by " . $user->title
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Account unlocked',
    user => {
      node_id => $target->node_id,
      title => $target->title
    },
    previously_locked_by => $locker ? {
      node_id => $locker->node_id,
      title => $locker->title
    } : undef
  }];
}

# _do_lock_account($TARGET, $locker) - the actual account-lock mutation, shared
# by lock_user (single, admin) and cleanup_users (mass, editor). Callers are
# responsible for the already-locked / permission / node-type guards. This was
# previously the htmlcode 'lock_user_account'; it now lives here only.
sub _do_lock_account
{
  my ($self, $TARGET, $locker) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;

  # Set acctlock to the locking user's node ID
  $TARGET->{acctlock} = $locker->{node_id};
  $DB->updateNode($TARGET, -1);

  # Delete all public messages from the locked user
  $DB->sqlDelete('message', "for_user = 0 AND author_user = $TARGET->{user_id}");

  # Revert all review drafts to 'findable' (not actually findable until unlock)
  my $findable_status = $DB->getNode('findable', 'publication_status');
  my $review_status = $DB->getNode('review', 'publication_status');
  if ($findable_status && $review_status)
  {
    $DB->sqlUpdate(
      'draft JOIN node ON draft_id=node_id',
      { publication_status => $findable_status->{node_id} },
      "node.author_user = $TARGET->{node_id} AND draft.publication_status = $review_status->{node_id}"
    );
  }

  $APP->securityLog(SECLOG_ACCOUNT_LOCK,
    $locker,
    "$TARGET->{title}'s account was locked by $locker->{title}"
  );

  return;
}

# _blacklist_ip($ip, $reason, $locker) - add/update an IPv4 entry in the
# ipblacklist table. Returns a human-readable result string (or an error
# string). Previously the htmlcode 'blacklistIP'.
sub _blacklist_ip
{
  my ($self, $ip, $reason, $locker) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;

  return 'No IP given to blacklist' unless $ip;
  # IPv4 only (still waiting for IPv6...)
  return "'" . $APP->encodeHTML($ip) . "' is not a valid IP address"
    unless $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;

  my $data = {
    ipblacklist_user      => $locker->{user_id},
    ipblacklist_ipaddress => $ip,
  };
  my $update = 0;
  my $result;

  my $listRef = $DB->sqlSelect('ipblacklistref_id', 'ipblacklist', "ipblacklist_ipaddress = '$ip'");
  if ($listRef)
  {
    $data->{ipblacklistref_id} = $listRef;
    $update = {
      %$data,
      -ipblacklist_comment => 'CONCAT(' . $DB->quote("$reason <br>&#91;")
        . ", ipblacklist_timestamp, ']: ', ipblacklist_comment)"
    };
    $result = "updated IP blacklist entry for $ip";
  }
  else
  {
    $DB->sqlInsert('ipblacklistref', {});
    $data->{-ipblacklistref_id} = 'LAST_INSERT_ID()';
    $data->{ipblacklist_comment} = $reason;
    $result = "added $ip to IP blacklist";
  }

  return "Error adding $ip to blacklist" unless $DB->sqlInsert('ipblacklist', $data, $update);

  $APP->securityLog(SECLOG_IP_BLACKLIST, $locker, "$locker->{title} $result: \"$reason.\"");
  $result =~ s/^(\w)/\u$1/;
  return $result;
}

=head2 cleanup_users

POST /api/admin/users/cleanup

Mass user-account review tool (the React replacement for the old "Hooked Pole"
server-side form action). Editor-gated. For each supplied username: delete the
account if it is safe to delete (valid user, never logged in, no writeups, no
nodeshells); otherwise lock it. With C<smite> set, locked spammers also get
their homenode blanked, an audit nodenote, and a same-IP-recently-locked
address blacklisted.

Request body:
{
  "usernames": ["spammer1", "spammer2"],   // or a newline-separated string
  "smite": 0                               // optional, spammer cleanup extras
}

Response:
{
  "success": 1,
  "results": [
    { "input": "spammer1", "node_id": 0, "title": "", "action": "deleted|locked|skipped",
      "reasons": ["..."], "writeup_count": 0, "nodeshell_count": 0 }
  ],
  "saved_users": ["spammer2"]
}

=cut

sub cleanup_users
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Editor-gated (preserves the old hooked-pole access level)
  unless ($user->is_editor)
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Editor access required',
      message => "You've got other things to snoop on, don't ya."
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA || {};
  my $smite = $data->{smite} ? 1 : 0;

  # usernames: accept an array or a newline-separated string
  my @usernames;
  if (ref($data->{usernames}) eq 'ARRAY')
  {
    @usernames = @{$data->{usernames}};
  }
  else
  {
    my $s = $data->{usernames} // '';
    $s =~ s/[\[\]]//g;
    @usernames = split(/\s*[\n\r]\s*/, $s);
  }
  @usernames = grep { length } map { my $u = $_; $u =~ s/^\s+|\s+$//g; $u } @usernames;

  unless (@usernames)
  {
    return [$self->HTTP_OK, { success => 1, results => [], saved_users => [] }];
  }

  my $ip_trauma = '1 MONTH';
  my $type_id_user    = $DB->getType('user')->{node_id};
  my $type_id_writeup = $DB->getType('writeup')->{node_id};
  my $type_id_e2node  = $DB->getType('e2node')->{node_id};

  my $ordinal = 1;
  my $input_table = join "\n    UNION ALL\n",
    map { "    SELECT " . $DB->quote($_) . " AS title, " . ($ordinal++) . " AS ordinal" } @usernames;

  my $user_query = qq|
SELECT input.title 'input', node.title, node.node_id, user.lasttime
  , user.acctlock
  , (SELECT COUNT(writeups.node_id) FROM node writeups
      WHERE node.node_id = writeups.author_user
      AND writeups.type_nodetype = $type_id_writeup) 'writeup_count'
  , (SELECT COUNT(nodeshells.node_id) FROM node AS nodeshells
      WHERE node.node_id = nodeshells.author_user
      AND nodeshells.type_nodetype = $type_id_e2node) 'nodeshell_count'
  , input.ordinal
  FROM (
$input_table
  ) input
  LEFT JOIN node ON node.title = input.title AND node.type_nodetype = $type_id_user
  LEFT JOIN user ON node.node_id = user.user_id
  ORDER BY input.ordinal|;

  my $users_to_nail = $DB->{dbh}->selectall_hashref($user_query, 'ordinal');

  my @results = ();
  my @saved_users = ();
  my $locker = $user->NODEDATA;

  # nukeNode/updateNode below fire node maintenance (user_delete, etc.) which
  # read the acting user from the $Everything::HTML::USER global. The page flow
  # sets that global; the API dispatcher does not -- so without this, the
  # delete-maintenance securityLog writes a null seclog_user. Establish it for
  # this request. (This coupling disappears when maintenance moves to the model.)
  local $Everything::HTML::USER = $locker;

  foreach my $ord (sort { $a <=> $b } keys %$users_to_nail)
  {
    my $target = $users_to_nail->{$ord};
    my $target_name = $APP->encodeHTML($target->{input});
    my $safe_to_whack = 1;
    my $safe_to_lock = 1;
    my @reasons = ();

    if (!$target->{node_id})
    {
      push @reasons, "$target_name isn't a valid user";
      $safe_to_whack = 0;
      $safe_to_lock = 0;
    }
    if ($target->{lasttime} && $target->{lasttime} ne "0" && $target->{lasttime} ne "")
    {
      push @reasons, "Logged in at $target->{lasttime}!";
      $safe_to_whack = 0;
    }
    if ($target->{nodeshell_count} && $target->{nodeshell_count} > 0)
    {
      push @reasons, "Has $target->{nodeshell_count} nodeshells!";
      $safe_to_whack = 0;
    }
    if ($target->{writeup_count} && $target->{writeup_count} > 0)
    {
      push @reasons, "Has $target->{writeup_count} writeups!";
      $safe_to_whack = 0;
    }

    my $action = '';
    # nukeNode honours canDeleteNode (only the user type's deleters_user -- gods --
    # may delete a user node). If the actor can't delete, nukeNode is a no-op and
    # returns false; we then fall through and lock instead, so a non-god editor
    # neutralises the account rather than getting a misleading "deleted" (the old
    # page reported "deleted" unconditionally even when nothing was removed).
    if ($safe_to_whack && $DB->nukeNode($target->{node_id}, $locker))
    {
      $action = 'deleted';
    }
    elsif ($safe_to_lock)
    {
      if (!$target->{acctlock})
      {
        my $TARGET = $APP->node_by_id($target->{node_id})->NODEDATA;
        $self->_do_lock_account($TARGET, $locker);
        push @reasons, "Locked account.";
      }
      else
      {
        push @reasons, "Account already locked.";
      }

      if ($smite && $target->{node_id})
      {
        my $spammer = $APP->node_by_id($target->{node_id});
        if ($spammer)
        {
          my $SPAMMER = $spammer->NODEDATA;
          $SPAMMER->{doctext} = '';
          $DB->updateNode($SPAMMER, -1);
          my $uservars = $APP->getVars($SPAMMER);
          setVars($SPAMMER, { ipaddy => $uservars->{ipaddy} });
          push @reasons, "Blanked homenode";

          # Audit note. Faithful to the old smite: noter_user 0, no notification.
          $DB->sqlInsert('nodenote', {
            nodenote_nodeid => $target->{node_id},
            noter_user      => 0,
            notetext        => "Spammer: smitten by [$locker->{title}\[user]]"
          });

          # Blacklist a recently-locked same-IP account's address
          my $bad_ip = $DB->sqlSelect(
            'myIP.iplog_ipaddy',
            "iplog myIP JOIN iplog badIP JOIN user
                ON myIP.iplog_ipaddy = badIP.iplog_ipaddy
                AND myIP.iplog_ipaddy != 'unknown'
                AND user_id = badIP.iplog_user
                AND user_id != myIP.iplog_user",
            "myIP.iplog_user = $target->{node_id}
                AND acctlock != 0
                AND lasttime > DATE_SUB(NOW(), INTERVAL $ip_trauma)"
          );
          if ($bad_ip)
          {
            my $bl = $self->_blacklist_ip($bad_ip,
              "Spammer $target->{input} using same IP as recently locked account", $locker);
            push @reasons, "Blacklisted IP: $bad_ip"
              if $bl && $bl !~ /^(No IP|'|Error)/;
          }
        }
      }

      $action = 'locked';
      push @saved_users, $target->{input};
    }
    else
    {
      $action = 'skipped';
      push @saved_users, $target->{input};
    }

    push @results, {
      input           => $target_name,
      node_id         => $target->{node_id} || 0,
      title           => $target->{title} || '',
      action          => $action,
      reasons         => \@reasons,
      writeup_count   => $target->{writeup_count} || 0,
      nodeshell_count => $target->{nodeshell_count} || 0,
    };
  }

  return [$self->HTTP_OK, {
    success => 1,
    results => \@results,
    saved_users => \@saved_users
  }];
}

=head2 basicedit_node

POST /api/admin/node/:id/basicedit

Update any field on a node. Gods (superusers) only.
This is the React equivalent of node_basicedit_page.

Request body:
{
  "fields": {
    "field_name": "value",
    ...
  }
}

Response:
{
  "success": 1,
  "message": "Node updated",
  "node_id": 123,
  "updatedFields": ["field1", "field2"]
}

GET request returns node data with all editable fields and their types.

=cut

sub basicedit_node
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only gods (superusers) can use basicedit
  unless ($APP->isAdmin($user->NODEDATA))
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Superuser access required',
      message => 'Only superusers can use basic edit'
    }];
  }

  my $node = $APP->node_by_id(int($id));
  unless ($node)
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Node not found',
      message => "No node found with ID $id"
    }];
  }

  my $NODE = $node->NODEDATA;
  my $nodetype = $node->type->title;

  # GET request - return node data with field metadata
  my $method = uc($REQUEST->request_method());
  if ($method eq 'GET')
  {
    # Get all tables for this nodetype
    # Copy the array to avoid mutating the cached TYPE object
    my $tables = [@{$DB->getNodetypeTables($NODE->{type_nodetype})}];
    push @$tables, 'node';

    my %fields = ();

    foreach my $table (@$tables)
    {
      my @field_info = $DB->getFieldsHash($table);

      foreach my $field (@field_info)
      {
        my $field_name = $field->{Field};
        my $field_type = $field->{Type};

        # Determine input type based on database type
        my $input_type = 'text';
        my $max_length = 256;

        if ($field_type =~ /int/)
        {
          $input_type = 'number';
          $max_length = 15;
        }
        elsif ($field_type =~ /char\((\d+)\)/)
        {
          $input_type = 'text';
          $max_length = $1;
        }
        elsif ($field_type =~ /text|longtext/)
        {
          $input_type = 'textarea';
          $max_length = undef;
        }
        elsif ($field_type =~ /datetime|timestamp/)
        {
          $input_type = 'datetime';
          $max_length = 19;
        }

        $fields{$field_name} = {
          value => $NODE->{$field_name},
          type => $field_type,
          inputType => $input_type,
          maxLength => $max_length,
        };
      }
    }

    return [$self->HTTP_OK, {
      success => 1,
      node_id => $node->node_id,
      title => $node->title,
      nodeType => $nodetype,
      fields => \%fields,
    }];
  }

  # POST request - update node fields
  my $data = $REQUEST->JSON_POSTDATA;
  unless ($data && ref($data) eq 'HASH' && $data->{fields})
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Invalid request body',
      message => 'Request body must contain a "fields" object'
    }];
  }

  my $fields_to_update = $data->{fields};
  my @updated_fields;

  foreach my $field_name (keys %$fields_to_update)
  {
    # Skip node_id - it should never be changed
    next if $field_name eq 'node_id';

    $NODE->{$field_name} = $fields_to_update->{$field_name};
    push @updated_fields, $field_name;
  }

  unless (@updated_fields)
  {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'No changes',
      message => 'No fields provided for update'
    }];
  }

  # Save the node
  $DB->updateNode($NODE, -1);

  # Log the edit
  $APP->securityLog(SECLOG_NODE_EDIT,
    $user->NODEDATA,
    $user->title . " used basicedit on $nodetype '" . $node->title . "'. Fields: " . join(', ', sort @updated_fields)
  );

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Node updated successfully',
    node_id => $node->node_id,
    title => $NODE->{title},
    nodeType => $nodetype,
    updatedFields => \@updated_fields,
  }];
}

around ['insure_writeup', 'remove_writeup', 'remove_vote', 'remove_cool', 'lock_user', 'unlock_user', 'basicedit_node'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

package Everything::API::autosave;

use Moose;
use namespace::autoclean;
use JSON;
use Encode qw(decode_utf8);
extends 'Everything::API';

=head1 NAME

Everything::API::autosave - Editor autosave API

=head1 DESCRIPTION

Handles automatic saving of editor content. Stores drafts in the autosave
table, keeping the last 20 autosaves per user+node combination.

=head1 ENDPOINTS

=head2 POST /api/autosave

Save content for a node.

Request body (JSON):
{
  "node_id": 12345,
  "doctext": "content to save"
}

Response (JSON):
Success:
{
  "success": true,
  "autosave_id": 123,
  "createtime": "2025-01-15 12:34:56"
}

Error:
{
  "success": false,
  "error": "error_code",
  "message": "Human readable message"
}

=head2 GET /api/autosave/:node_id

Get autosaves for a specific node.

Response (JSON):
{
  "success": true,
  "autosaves": [
    {
      "autosave_id": 123,
      "doctext": "content",
      "createtime": "2025-01-15 12:34:56"
    }
  ]
}

=head2 DELETE /api/autosave/:id

Delete a specific autosave entry.

=cut

has 'max_autosaves_per_node' => (is => 'ro', default => 20);

sub routes {
    return {
        '/'            => 'create',
        '/:id'         => 'get_or_delete',
        '/:id/history' => 'get_version_history',
        '/:id/restore' => 'restore_version'
    };
}

sub get_or_delete {
    my ($self, $REQUEST, $id) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'get') {
        return $self->get_autosaves($REQUEST, $id);
    } elsif ($method eq 'delete') {
        return $self->delete_autosave($REQUEST, $id);
    }

    return [$self->HTTP_UNIMPLEMENTED, {
        success => 0,
        error => 'method_not_allowed',
        message => 'Use GET or DELETE for this endpoint'
    }];
}

sub create {
    my ($self, $REQUEST) = @_;

    my $user_id = $REQUEST->user->node_id;

    # Parse JSON body
    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    if (!$json_ok || !$data) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_json',
            message => 'Invalid JSON in request body'
        }];
    }

    my $node_id = int($data->{node_id} // 0);
    my $doctext = $data->{doctext} // '';

    unless ($node_id > 0) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_node_id',
            message => 'node_id is required and must be a positive integer'
        }];
    }

    # Verify the node exists and user has permission to edit it
    my $node = $self->DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_NOT_FOUND, {
            success => 0,
            error => 'node_not_found',
            message => 'Node not found'
        }];
    }

    # Check if user can edit this node
    my $can_edit = 0;
    if ($node->{author_user} == $user_id) {
        $can_edit = 1;
    } elsif ($self->APP->isEditor($REQUEST->user->NODEDATA)) {
        $can_edit = 1;
    } elsif ($REQUEST->user->is_admin) {
        $can_edit = 1;
    }

    unless ($can_edit) {
        return [$self->HTTP_FORBIDDEN, {
            success => 0,
            error => 'permission_denied',
            message => 'You do not have permission to edit this node'
        }];
    }

    my $dbh = $self->DB->{dbh};

    # Get current content from main document table
    my $current_doctext = $dbh->selectrow_array(
        'SELECT doctext FROM document WHERE document_id = ?',
        {}, $node_id
    );

    # Only proceed if content has actually changed
    if (defined $current_doctext && $current_doctext eq $doctext) {
        return [$self->HTTP_OK, {
            success => 1,
            message => 'no_changes',
            saved => 0
        }];
    }

    # Stash current content to version history before overwriting
    my $autosave_id;
    if (defined $current_doctext && length($current_doctext) > 0) {
        my $insert_sql = q|
            INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type)
            VALUES (?, ?, ?, NOW(), 'auto')
        |;

        my $insert_ok = eval {
            $dbh->do($insert_sql, {}, $user_id, $node_id, $current_doctext);
            1;
        };

        unless ($insert_ok) {
            $self->APP->devLog("Autosave stash failed: $@");
            return [$self->HTTP_INTERNAL_SERVER_ERROR, {
                success => 0,
                error => 'stash_failed',
                message => 'Failed to stash previous version'
            }];
        }

        $autosave_id = $dbh->last_insert_id(undef, undef, 'autosave', 'autosave_id');

        # Prune old versions - keep only the last N per user+node
        $self->_prune_old_autosaves($user_id, $node_id);
    }

    # Update the main document with new content
    my $update_ok = eval {
        $dbh->do(
            'UPDATE document SET doctext = ? WHERE document_id = ?',
            {}, $doctext, $node_id
        );
        1;
    };

    unless ($update_ok) {
        $self->APP->devLog("Autosave document update failed: $@");
        return [$self->HTTP_INTERNAL_SERVER_ERROR, {
            success => 0,
            error => 'update_failed',
            message => 'Failed to update document'
        }];
    }

    return [$self->HTTP_OK, {
        success => 1,
        saved => 1,
        autosave_id => $autosave_id,
        save_type => 'auto'
    }];
}

sub get_autosaves {
    my ($self, $REQUEST, $node_id) = @_;

    $node_id = int($node_id // 0);
    unless ($node_id > 0) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_node_id',
            message => 'node_id must be a positive integer'
        }];
    }

    my $user_id = $REQUEST->user->node_id;

    # Get autosaves for this user+node, most recent first
    my $dbh = $self->DB->{dbh};
    my $sql = q|
        SELECT autosave_id, doctext, createtime, save_type
        FROM autosave
        WHERE author_user = ? AND node_id = ?
        ORDER BY createtime DESC
        LIMIT ?
    |;

    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} },
        $user_id, $node_id, $self->max_autosaves_per_node);

    return [$self->HTTP_OK, {
        success => 1,
        node_id => $node_id,
        autosaves => $rows // []
    }];
}

# Get version history for a draft (without full doctext for list view)
sub get_version_history {
    my ($self, $REQUEST, $node_id) = @_;

    $node_id = int($node_id // 0);
    unless ($node_id > 0) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_node_id',
            message => 'node_id must be a positive integer'
        }];
    }

    my $user_id = $REQUEST->user->node_id;
    my $dbh = $self->DB->{dbh};

    # Verify user owns this draft
    my $owner = $dbh->selectrow_array(
        'SELECT author_user FROM node WHERE node_id = ?',
        {}, $node_id
    );

    unless ($owner && $owner == $user_id) {
        return [$self->HTTP_FORBIDDEN, {
            success => 0,
            error => 'permission_denied',
            message => 'You can only view history for your own drafts'
        }];
    }

    # Get version history - include content length instead of full text for list
    my $sql = q|
        SELECT autosave_id, createtime, save_type,
               LENGTH(doctext) AS content_length,
               LEFT(doctext, 100) AS preview
        FROM autosave
        WHERE author_user = ? AND node_id = ?
        ORDER BY createtime DESC
        LIMIT ?
    |;

    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} },
        $user_id, $node_id, $self->max_autosaves_per_node);

    return [$self->HTTP_OK, {
        success => 1,
        node_id => $node_id,
        versions => $rows // []
    }];
}

# Restore a version from history to the main draft
sub restore_version {
    my ($self, $REQUEST, $autosave_id) = @_;

    # Only allow POST for restore
    my $method = lc($REQUEST->request_method());
    unless ($method eq 'post') {
        return [$self->HTTP_UNIMPLEMENTED, {
            success => 0,
            error => 'method_not_allowed',
            message => 'Use POST to restore a version'
        }];
    }

    $autosave_id = int($autosave_id // 0);
    unless ($autosave_id > 0) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_id',
            message => 'autosave_id must be a positive integer'
        }];
    }

    my $user_id = $REQUEST->user->node_id;
    my $dbh = $self->DB->{dbh};

    # Get the version to restore
    my $version = $dbh->selectrow_hashref(
        'SELECT autosave_id, author_user, node_id, doctext FROM autosave WHERE autosave_id = ?',
        {}, $autosave_id
    );

    unless ($version) {
        return [$self->HTTP_NOT_FOUND, {
            success => 0,
            error => 'not_found',
            message => 'Version not found'
        }];
    }

    # Verify ownership
    unless ($version->{author_user} == $user_id) {
        return [$self->HTTP_FORBIDDEN, {
            success => 0,
            error => 'permission_denied',
            message => 'You can only restore your own versions'
        }];
    }

    my $node_id = $version->{node_id};
    my $restore_content = $version->{doctext};

    # Stash current content before restoring (as manual save)
    my $current_doctext = $dbh->selectrow_array(
        'SELECT doctext FROM document WHERE document_id = ?',
        {}, $node_id
    );

    if (defined $current_doctext && $current_doctext ne $restore_content) {
        $dbh->do(
            'INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type) VALUES (?, ?, ?, NOW(), ?)',
            {}, $user_id, $node_id, $current_doctext, 'manual'
        );

        # Prune old versions
        $self->_prune_old_autosaves($user_id, $node_id);
    }

    # Update the main document with restored content
    $dbh->do(
        'UPDATE document SET doctext = ? WHERE document_id = ?',
        {}, $restore_content, $node_id
    );

    return [$self->HTTP_OK, {
        success => 1,
        restored_from => $autosave_id,
        node_id => $node_id
    }];
}

sub delete_autosave {
    my ($self, $REQUEST, $autosave_id) = @_;

    $autosave_id = int($autosave_id // 0);
    unless ($autosave_id > 0) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_id',
            message => 'autosave_id must be a positive integer'
        }];
    }

    my $user_id = $REQUEST->user->node_id;
    my $dbh = $self->DB->{dbh};

    # Verify ownership before deleting
    my $check_sql = q|SELECT author_user FROM autosave WHERE autosave_id = ?|;
    my $row = $dbh->selectrow_hashref($check_sql, {}, $autosave_id);

    unless ($row) {
        return [$self->HTTP_NOT_FOUND, {
            success => 0,
            error => 'not_found',
            message => 'Autosave not found'
        }];
    }

    # Only author or admin can delete
    unless ($row->{author_user} == $user_id || $REQUEST->user->is_admin) {
        return [$self->HTTP_FORBIDDEN, {
            success => 0,
            error => 'permission_denied',
            message => 'You can only delete your own autosaves'
        }];
    }

    my $delete_sql = q|DELETE FROM autosave WHERE autosave_id = ?|;
    $dbh->do($delete_sql, {}, $autosave_id);

    return [$self->HTTP_OK, {
        success => 1,
        deleted => $autosave_id
    }];
}

sub _prune_old_autosaves {
    my ($self, $user_id, $node_id) = @_;

    my $dbh = $self->DB->{dbh};
    my $max = $self->max_autosaves_per_node;

    # Find IDs to keep (the N most recent)
    my $keep_sql = q|
        SELECT autosave_id
        FROM autosave
        WHERE author_user = ? AND node_id = ?
        ORDER BY createtime DESC
        LIMIT ?
    |;

    my $keep_ids = $dbh->selectcol_arrayref($keep_sql, {}, $user_id, $node_id, $max);

    if ($keep_ids && @$keep_ids) {
        my $placeholders = join(',', ('?') x scalar(@$keep_ids));
        my $delete_sql = qq|
            DELETE FROM autosave
            WHERE author_user = ? AND node_id = ? AND autosave_id NOT IN ($placeholders)
        |;
        $dbh->do($delete_sql, {}, $user_id, $node_id, @$keep_ids);
    }

    return;
}

around ['create', 'get_or_delete', 'get_version_history', 'restore_version'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;

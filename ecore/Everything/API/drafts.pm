package Everything::API::drafts;

use Moose;
use namespace::autoclean;
use JSON;
use Encode qw(decode_utf8);
extends 'Everything::API';

=head1 NAME

Everything::API::drafts - Draft management API

=head1 DESCRIPTION

Handles draft CRUD operations for the E2 Editor Beta.

=head1 ENDPOINTS

=head2 GET /api/drafts

Get list of user's drafts.

=head2 GET /api/drafts/:id

Get a specific draft's content.

=head2 POST /api/drafts

Create a new draft.

=head2 PUT /api/drafts/:id

Update an existing draft (content, title, or status).

=head2 POST /api/drafts/:id/publish

Publish a draft as a writeup. Converts the draft node to a writeup node,
adds it to the parent e2node's nodegroup, and updates all relevant tables.

Uses node locking on the e2node to prevent race conditions.

Request body:
{
  "parent_e2node": 123,
  "wrtype_writeuptype": 456,
  "feedback_policy_id": 0 (optional),
  "publishtime": "2025-01-01 00:00:00" (optional, defaults to NOW()),
  "notnew": 0 (optional, defaults to 0 - set to 1 to hide from New Writeups)
}

Returns 409 Conflict if e2node is locked by another operation.

=cut

sub routes {
    return {
        '/'            => 'list_or_create',
        '/search'      => 'search_drafts',
        '/:id'         => 'get_or_update',
        '/:id/parent'  => 'set_parent_e2node(:id)',
        '/:id/publish' => 'publish_draft(:id)',
        '/preview'     => 'render_preview'
    };
}

sub list_or_create {
    my ( $self, $REQUEST ) = @_;

    my $method = lc( $REQUEST->request_method() );

    if ( $method eq 'get' ) {
        return $self->list_drafts($REQUEST);
    }
    elsif ( $method eq 'post' ) {
        return $self->create_draft($REQUEST);
    }

    return [
        $self->HTTP_METHOD_NOT_ALLOWED,
        {
            success => 0,
            error   => 'method_not_allowed'
        }
    ];
}

sub get_or_update {
    my ( $self, $REQUEST, $id ) = @_;

    my $method = lc( $REQUEST->request_method() );

    if ( $method eq 'get' ) {
        return $self->get_draft( $REQUEST, $id );
    }
    elsif ( $method eq 'put' || $method eq 'post' ) {
        return $self->update_draft( $REQUEST, $id );
    }
    elsif ( $method eq 'delete' ) {
        return $self->delete_draft( $REQUEST, $id );
    }

    return [
        $self->HTTP_METHOD_NOT_ALLOWED,
        {
            success => 0,
            error   => 'method_not_allowed'
        }
    ];
}

sub list_drafts {
    my ( $self, $REQUEST ) = @_;

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;

    # Get pagination parameters from query string
    my $limit  = int( $REQUEST->param('limit')  || 20 );
    my $offset = int( $REQUEST->param('offset') || 0 );

    # Sanity checks
    $limit  = 20 if $limit < 1 || $limit > 100;
    $offset = 0  if $offset < 0;

    my $draft_type    = $DB->getType('draft');
    my $draft_type_id = $draft_type->{node_id};

    my $sql = q|
        SELECT node.node_id, node.title, node.createtime,
               draft.publication_status,
               ps.title AS status_title,
               document.doctext
        FROM node
        JOIN draft ON draft.draft_id = node.node_id
        JOIN document ON document.document_id = node.node_id
        LEFT JOIN node AS ps ON ps.node_id = draft.publication_status
        WHERE node.author_user = ?
        AND node.type_nodetype = ?
        ORDER BY node.createtime DESC
        LIMIT ? OFFSET ?
    |;

    my $rows = $DB->{dbh}->selectall_arrayref( $sql, { Slice => {} },
        $user_id, $draft_type_id, $limit, $offset );

    # Transform rows to match expected format (status instead of status_title)
    my @drafts = map {
        {
            node_id    => $_->{node_id},
            title      => $_->{title},
            createtime => $_->{createtime},
            status     => $_->{status_title} || 'unknown',
            doctext    => $_->{doctext}      || ''
        }
    } @$rows;

    # Get total count for pagination metadata
    my $total = $DB->{dbh}->selectrow_array(
        'SELECT COUNT(*) FROM node WHERE author_user = ? AND type_nodetype = ?',
        {}, $user_id, $draft_type_id
    );

    return [
        $self->HTTP_OK,
        {
            success    => 1,
            drafts     => \@drafts,
            pagination => {
                limit    => $limit,
                offset   => $offset,
                total    => $total || 0,
                has_more => ( $offset + $limit ) < ( $total || 0 )
            }
        }
    ];
}

=head2 GET /api/drafts/search

Search user's drafts by title or content.

Query parameters:
  q - Search query (required, min 2 characters)
  limit - Maximum results (default 20, max 50)

Returns drafts matching the query in title or doctext.

=cut

sub search_drafts {
    my ( $self, $REQUEST ) = @_;

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;

    # Get search query
    my $query = $REQUEST->param('q') || '';
    $query =~ s/^\s+|\s+$//g;  # Trim whitespace

    # Require at least 2 characters
    if ( length($query) < 2 ) {
        return [
            $self->HTTP_OK,
            {
                success => 1,
                drafts  => [],
                message => 'Search query too short (minimum 2 characters)'
            }
        ];
    }

    # Limit results
    my $limit = int( $REQUEST->param('limit') || 20 );
    $limit = 20 if $limit < 1;
    $limit = 50 if $limit > 50;

    my $draft_type    = $DB->getType('draft');
    my $draft_type_id = $draft_type->{node_id};

    # Search in both title and doctext using LIKE
    # Escape special SQL LIKE characters in the query
    my $escaped_query = $query;
    $escaped_query =~ s/([%_\\])/\\$1/g;
    my $search_pattern = '%' . $escaped_query . '%';

    my $sql = q|
        SELECT node.node_id, node.title, node.createtime,
               draft.publication_status,
               ps.title AS status_title,
               document.doctext
        FROM node
        JOIN draft ON draft.draft_id = node.node_id
        JOIN document ON document.document_id = node.node_id
        LEFT JOIN node AS ps ON ps.node_id = draft.publication_status
        WHERE node.author_user = ?
        AND node.type_nodetype = ?
        AND (node.title LIKE ? OR document.doctext LIKE ?)
        ORDER BY node.createtime DESC
        LIMIT ?
    |;

    my $rows = $DB->{dbh}->selectall_arrayref(
        $sql,
        { Slice => {} },
        $user_id, $draft_type_id, $search_pattern, $search_pattern, $limit
    );

    # Transform rows to match expected format
    my @drafts = map {
        {
            node_id    => $_->{node_id},
            title      => $_->{title},
            createtime => $_->{createtime},
            status     => $_->{status_title} || 'unknown',
            doctext    => $_->{doctext}      || ''
        }
    } @$rows;

    return [
        $self->HTTP_OK,
        {
            success => 1,
            drafts  => \@drafts,
            query   => $query
        }
    ];
}

sub get_draft {
    my ( $self, $REQUEST, $draft_id ) = @_;

    $draft_id = int( $draft_id || 0 );
    return [ $self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_id' } ]
      unless $draft_id > 0;

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;

    my $draft = $DB->getNodeById($draft_id);
    return [ $self->HTTP_NOT_FOUND, { success => 0, error => 'not_found' } ]
      unless $draft;

    # Check ownership
    unless ( $draft->{author_user} == $user_id
        || $self->APP->isEditor( $REQUEST->user->NODEDATA ) )
    {
        return [
            $self->HTTP_FORBIDDEN,
            { success => 0, error => 'permission_denied' }
        ];
    }

    # Get document text
    my $doctext =
      $DB->{dbh}
      ->selectrow_array( 'SELECT doctext FROM document WHERE document_id = ?',
        {}, $draft_id )
      || '';

    # Get publication status title
    my $status_title = $DB->{dbh}->selectrow_array(
'SELECT title FROM node WHERE node_id = (SELECT publication_status FROM draft WHERE draft_id = ?)',
        {}, $draft_id
    ) || 'unknown';

    return [
        $self->HTTP_OK,
        {
            success => 1,
            draft   => {
                node_id    => $draft->{node_id},
                title      => $draft->{title},
                doctext    => $doctext,
                status     => $status_title,
                createtime => $draft->{createtime}
            }
        }
    ];
}

sub create_draft {
    my ( $self, $REQUEST ) = @_;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [ $self->HTTP_BAD_REQUEST,
        { success => 0, error => 'invalid_json' } ]
      unless $json_ok && $data;

    my $title   = $data->{title} || 'Untitled Draft';
    my $doctext = $data->{doctext} // '';

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;
    my $APP     = $self->APP;

    # Clean the title
    $title = $APP->cleanNodeName($title) || 'untitled draft';

    # Get draft type and default status
    my $draft_type     = $DB->getType('draft');
    my $private_status = $DB->getNode( 'private', 'publication_status' );

    # Check for duplicate titles
    my $base_title = $title;
    my $count      = 1;
    while (
        $DB->{dbh}->selectrow_array(
'SELECT node_id FROM node WHERE title = ? AND type_nodetype = ? AND author_user = ?',
            {},
            $title,
            $draft_type->{node_id},
            $user_id
        )
      )
    {
        $title = "$base_title ($count)";
        $count++;
    }

# Create the draft node
# insertNode signature: ($title, $TYPE, $USER, $NODEDATA, $skip_maintenance)
# NODEDATA is passed to updateNode after creation, so we can set doctext and publication_status there
    my $nodedata = {
        doctext            => $doctext,
        publication_status => $private_status->{node_id}
    };

    my $draft_id =
      $DB->insertNode( $title, $draft_type, $REQUEST->user->NODEDATA,
        $nodedata );
    return [
        $self->HTTP_INTERNAL_SERVER_ERROR,
        { success => 0, error => 'insert_failed' }
      ]
      unless $draft_id;

    return [
        $self->HTTP_OK,
        {
            success => 1,
            draft   => {
                node_id => $draft_id,
                title   => $title,
                status  => 'private'
            }
        }
    ];
}

sub update_draft {
    my ( $self, $REQUEST, $draft_id ) = @_;

    $draft_id = int( $draft_id || 0 );
    return [ $self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_id' } ]
      unless $draft_id > 0;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [ $self->HTTP_BAD_REQUEST,
        { success => 0, error => 'invalid_json' } ]
      unless $json_ok && $data;

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;
    my $APP     = $self->APP;

    # Get the draft
    my $draft = $DB->getNodeById($draft_id);
    return [ $self->HTTP_NOT_FOUND, { success => 0, error => 'not_found' } ]
      unless $draft && $draft->{type}{title} eq 'draft';

    # Check ownership
    unless ( $draft->{author_user} == $user_id ) {
        return [
            $self->HTTP_FORBIDDEN,
            { success => 0, error => 'permission_denied' }
        ];
    }

    my $updated = {};

    # Update doctext if provided
    if ( exists $data->{doctext} ) {

        # Stash current content to version history before overwriting
        my $current_doctext =
          $DB->{dbh}->selectrow_array(
            'SELECT doctext FROM document WHERE document_id = ?',
            {}, $draft_id );

        # Only stash if there's existing content and it's different
        if ( defined $current_doctext && $current_doctext ne $data->{doctext} )
        {
            $DB->{dbh}->do(
'INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type) VALUES (?, ?, ?, NOW(), ?)',
                {}, $user_id, $draft_id, $current_doctext, 'manual'
            );

            # Prune old versions - keep last 20
            $self->_prune_version_history( $user_id, $draft_id );
        }

        # Update the main document
        $DB->{dbh}->do( 'UPDATE document SET doctext = ? WHERE document_id = ?',
            {}, $data->{doctext}, $draft_id );
        $updated->{doctext} = 1;
    }

    # Update title if provided
    if ( exists $data->{title} && $data->{title} ne $draft->{title} ) {
        my $new_title =
          $APP->cleanNodeName( $data->{title} ) || 'untitled draft';

        # Check for duplicates
        my $base_title = $new_title;
        my $count      = 1;
        while (
            $DB->{dbh}->selectrow_array(
'SELECT node_id FROM node WHERE title = ? AND type_nodetype = ? AND author_user = ? AND node_id != ?',
                {},
                $new_title,
                $draft->{type_nodetype},
                $user_id,
                $draft_id
            )
          )
        {
            $new_title = "$base_title ($count)";
            $count++;
        }

        $DB->{dbh}->do( 'UPDATE node SET title = ? WHERE node_id = ?',
            {}, $new_title, $draft_id );
        $updated->{title} = $new_title;
    }

    # Update publication status if provided
    if ( exists $data->{status} ) {
        my $status_node = $DB->getNode( $data->{status}, 'publication_status' );
        if ($status_node) {
            my $old_status =
              $DB->{dbh}->selectrow_array(
                'SELECT publication_status FROM draft WHERE draft_id = ?',
                {}, $draft_id );

            $DB->{dbh}->do(
                'UPDATE draft SET publication_status = ? WHERE draft_id = ?',
                {}, $status_node->{node_id}, $draft_id );
            $updated->{status} = $data->{status};

            # If changing to review, notify editors
            if (   $data->{status} eq 'review'
                && $old_status != $status_node->{node_id} )
            {
                $self->_notify_review( $draft_id, $user_id );
            }
        }
    }

    # Fetch current doctext from database to return as source of truth
    my $current_doctext = $DB->{dbh}->selectrow_array(
        'SELECT doctext FROM document WHERE document_id = ?',
        {}, $draft_id
    );

    return [
        $self->HTTP_OK,
        {
            success  => 1,
            updated  => $updated,
            draft_id => $draft_id,
            doctext  => $current_doctext
        }
    ];
}

# DELETE /api/drafts/:id - Delete a draft (author only)
sub delete_draft {
    my ( $self, $REQUEST, $id ) = @_;

    my $user = $REQUEST->user;
    my $APP  = $self->APP;
    my $DB   = $self->DB;

    # Must be logged in
    if ( $user->is_guest ) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Must be logged in to delete drafts'
            }
        ];
    }

    # Get the draft
    my $draft = $DB->getNodeById($id);
    unless ($draft) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Draft not found'
            }
        ];
    }

    # Verify it's a draft type
    unless ( $draft->{type}{title} eq 'draft' ) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Node is not a draft'
            }
        ];
    }

    # Only the author can delete their own drafts (or admins/gods)
    my $is_author = $draft->{author_user} == $user->node_id;
    my $is_admin  = $APP->isAdmin( $user->NODEDATA );

    unless ( $is_author || $is_admin ) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'You can only delete your own drafts'
            }
        ];
    }

    # Delete associated autosave entries
    my $dbh = $DB->{dbh};
    $dbh->do( 'DELETE FROM autosave WHERE node_id = ?', {}, $id );

    # Delete associated nodenotes
    $dbh->do( 'DELETE FROM nodenote WHERE nodenote_nodeid = ?', {}, $id );

    # Delete links to/from this draft
    $dbh->do( 'DELETE FROM links WHERE from_node = ? OR to_node = ?', {}, $id, $id );

    # Delete the draft node itself
    # Pass -1 as user (superuser) since we already verified permissions above
    my $success = $DB->nukeNode($draft, -1);

    if ($success) {
        return [
            $self->HTTP_OK,
            {
                success => 1,
                message => 'Draft deleted successfully'
            }
        ];
    }
    else {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Failed to delete draft'
            }
        ];
    }
}

sub _notify_review {
    my ( $self, $draft_id, $author_id ) = @_;

    # Add a nodenote that author requested review
    my $note_sql = q|
        INSERT INTO nodenote (nodenote_nodeid, noter_user, notetext, timestamp)
        VALUES (?, 0, 'author requested review', NOW())
    |;
    $self->DB->{dbh}->do( $note_sql, {}, $draft_id );

    return;
}

sub _prune_version_history {
    my ( $self, $user_id, $node_id, $max ) = @_;

    $max //= 20;
    my $dbh = $self->DB->{dbh};

    # Find IDs to keep (the N most recent)
    my $keep_sql = q|
        SELECT autosave_id
        FROM autosave
        WHERE author_user = ? AND node_id = ?
        ORDER BY createtime DESC
        LIMIT ?
    |;

    my $keep_ids =
      $dbh->selectcol_arrayref( $keep_sql, {}, $user_id, $node_id, $max );

    if ( $keep_ids && @$keep_ids ) {
        my $placeholders = join( ',', ('?') x scalar(@$keep_ids) );
        my $delete_sql   = qq|
            DELETE FROM autosave
            WHERE author_user = ? AND node_id = ? AND autosave_id NOT IN ($placeholders)
        |;
        $dbh->do( $delete_sql, {}, $user_id, $node_id, @$keep_ids );
    }

    return;
}

# Get available publication statuses for UI
sub get_statuses {
    my ( $self, $REQUEST ) = @_;

    my $DB = $self->DB;

    # Get statuses that users can set (not nuked/removed which are editor-only)
    my @user_statuses = qw(private shared findable review);

    my @statuses;
    for my $status_name (@user_statuses) {
        my $status = $DB->getNode( $status_name, 'publication_status' );
        if ($status) {
            push @statuses,
              {
                id          => $status->{node_id},
                name        => $status->{title},
                description => $self->_status_description( $status->{title} )
              };
        }
    }

    return [
        $self->HTTP_OK,
        {
            success  => 1,
            statuses => \@statuses
        }
    ];
}

sub _status_description {
    my ( $self, $status ) = @_;

    my %descriptions = (
        'private'  => 'Only you can see this draft',
        'shared'   => 'Visible to users you specify as collaborators',
        'findable' => 'Visible to all logged-in users',
        'review'   => 'Submit for editor review before publishing'
    );

    return $descriptions{$status} || '';
}

=head2 POST /api/drafts/:id/parent

Set or change the parent e2node for a draft. If the e2node doesn't exist,
it will be created automatically.

Request body:
{
  "e2node_title": "Name of the e2node"
}

or:
{
  "e2node_id": 12345
}

Returns the e2node information on success.

=cut

sub set_parent_e2node {
    my ( $self, $REQUEST, $draft_id ) = @_;

    $draft_id = int( $draft_id || 0 );
    return [ $self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_id' } ]
      unless $draft_id > 0;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [ $self->HTTP_BAD_REQUEST,
        { success => 0, error => 'invalid_json' } ]
      unless $json_ok && $data;

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;
    my $APP     = $self->APP;

    # Get the draft
    my $draft = $DB->getNodeById($draft_id);
    return [ $self->HTTP_NOT_FOUND, { success => 0, error => 'not_found' } ]
      unless $draft && $draft->{type}{title} eq 'draft';

    # Check ownership
    unless ( $draft->{author_user} == $user_id ) {
        return [
            $self->HTTP_FORBIDDEN,
            { success => 0, error => 'permission_denied' }
        ];
    }

    my $e2node;
    my $e2node_created = 0;

    # Get or create e2node by ID or title
    if ( my $e2node_id = int( $data->{e2node_id} || 0 ) ) {
        # Lookup by ID
        $e2node = $DB->getNodeById($e2node_id);
        unless ( $e2node && $e2node->{type}{title} eq 'e2node' ) {
            return [
                $self->HTTP_BAD_REQUEST,
                {
                    success => 0,
                    error   => 'invalid_e2node',
                    message => 'E2node with that ID not found'
                }
            ];
        }
    }
    elsif ( my $e2node_title = $data->{e2node_title} ) {
        # Clean the title
        $e2node_title = $APP->cleanNodeName($e2node_title);
        unless ($e2node_title) {
            return [
                $self->HTTP_BAD_REQUEST,
                {
                    success => 0,
                    error   => 'invalid_title',
                    message => 'E2node title is invalid'
                }
            ];
        }

        # Try to find existing e2node
        $e2node = $DB->getNode( $e2node_title, 'e2node' );

        # Create if it doesn't exist
        unless ($e2node) {
            my $e2node_type = $DB->getType('e2node');
            my $e2node_id = $DB->insertNode( $e2node_title, $e2node_type,
                $REQUEST->user->NODEDATA );

            unless ($e2node_id) {
                return [
                    $self->HTTP_INTERNAL_SERVER_ERROR,
                    {
                        success => 0,
                        error   => 'create_failed',
                        message => 'Failed to create e2node'
                    }
                ];
            }

            $e2node         = $DB->getNodeById($e2node_id);
            $e2node_created = 1;
        }
    }
    else {
        return [
            $self->HTTP_BAD_REQUEST,
            {
                success => 0,
                error   => 'missing_e2node',
                message => 'Either e2node_id or e2node_title is required'
            }
        ];
    }

    # Note: The draft table doesn't have a parent_e2node column.
    # The frontend stores the intended parent and passes it during publish.

    # Clear cache
    $DB->getCache->removeNode($draft);

    return [
        $self->HTTP_OK,
        {
            success => 1,
            e2node  => {
                node_id => $e2node->{node_id},
                title   => $e2node->{title},
                created => $e2node_created ? JSON::true : JSON::false
            },
            message => $e2node_created
            ? "Created new e2node '$e2node->{title}'"
            : "Set parent e2node to '$e2node->{title}'"
        }
    ];
}

sub publish_draft {
    my ( $self, $REQUEST, $draft_id ) = @_;

    $draft_id = int( $draft_id || 0 );
    return [ $self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_id' } ]
      unless $draft_id > 0;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [ $self->HTTP_BAD_REQUEST,
        { success => 0, error => 'invalid_json' } ]
      unless $json_ok && $data;

    my $user_id = $REQUEST->user->node_id;
    my $DB      = $self->DB;
    my $APP     = $self->APP;

    # Get the draft
    my $draft = $DB->getNodeById($draft_id);
    return [ $self->HTTP_NOT_FOUND, { success => 0, error => 'not_found' } ]
      unless $draft && $draft->{type}{title} eq 'draft';

    # Check ownership
    unless ( $draft->{author_user} == $user_id ) {
        return [
            $self->HTTP_FORBIDDEN,
            { success => 0, error => 'permission_denied' }
        ];
    }

    # Get required data from request
    my $parent_e2node_id = int( $data->{parent_e2node}      || 0 );
    my $writeuptype_id   = int( $data->{wrtype_writeuptype} || 0 );

    # Validate parent e2node
    unless ( $parent_e2node_id > 0 ) {
        return [
            $self->HTTP_BAD_REQUEST,
            {
                success => 0,
                error   => 'missing_parent',
                message => 'parent_e2node is required'
            }
        ];
    }

    my $e2node = $DB->getNodeById($parent_e2node_id);
    unless ( $e2node && $e2node->{type}{title} eq 'e2node' ) {
        return [
            $self->HTTP_BAD_REQUEST,
            {
                success => 0,
                error   => 'invalid_parent',
                message => 'Invalid e2node ID'
            }
        ];
    }

    # Check if e2node is locked (soft lock prevents new writeups)
    my $node_lock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$parent_e2node_id");
    if ($node_lock) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'node_locked',
                message => 'This node is locked and cannot accept new writeups'
            }
        ];
    }

    # Validate writeup type
    unless ( $writeuptype_id > 0 ) {
        return [
            $self->HTTP_BAD_REQUEST,
            {
                success => 0,
                error   => 'missing_writeuptype',
                message => 'wrtype_writeuptype is required'
            }
        ];
    }

    my $writeuptype = $DB->getNodeById($writeuptype_id);
    unless ( $writeuptype && $writeuptype->{type}{title} eq 'writeuptype' ) {
        return [
            $self->HTTP_BAD_REQUEST,
            {
                success => 0,
                error   => 'invalid_writeuptype',
                message => 'Invalid writeuptype ID'
            }
        ];
    }

    # Get writeup nodetype
    my $writeup_type = $DB->getType('writeup');
    unless ($writeup_type) {
        return [
            $self->HTTP_INTERNAL_SERVER_ERROR,
            {
                success => 0,
                error   => 'config_error',
                message => 'writeup nodetype not found'
            }
        ];
    }

# CRITICAL: Start transaction and acquire lock on e2node to prevent race conditions
# Using SELECT ... FOR UPDATE to lock the e2node row
    my $dbh = $DB->{dbh};

    # Save original AutoCommit state to restore after transaction
    my $orig_autocommit = $dbh->{AutoCommit};

    # Start transaction (if not already in one)
    if ($orig_autocommit) {
        $dbh->{AutoCommit} = 0;
    }

    # Acquire lock on e2node row
    my $lock_result = eval {
        $dbh->do( "SELECT node_id FROM node WHERE node_id = ? FOR UPDATE",
            {}, $e2node->{node_id} );
    };

    unless ($lock_result) {

        # Rollback on lock failure and restore AutoCommit
        my $rollback_ok = eval { $dbh->rollback(); 1 };
        $APP->devLog("Rollback result: " . ($rollback_ok ? "ok" : "failed")) unless $rollback_ok;
        $dbh->{AutoCommit} = $orig_autocommit if $orig_autocommit;
        $APP->devLog("Lock acquisition failed for e2node $parent_e2node_id: $@") if $@;
        return [
            $self->HTTP_CONFLICT,
            {
                success => 0,
                error   => 'node_locked',
                message =>
                  'E2node is locked by another operation. Please try again.'
            }
        ];
    }

    # Convert draft to writeup - update node type and title
    # Writeup title format: "e2node title (writeuptype)"
    my $writeup_title = $e2node->{title} . ' (' . $writeuptype->{title} . ')';
    my $update_result = $DB->sqlUpdate(
        'node',
        {
            type_nodetype => $writeup_type->{node_id},
            title         => $writeup_title
        },
        "node_id=$draft_id"
    );

    # Insert into writeup table
    # Note: Use '-' prefix for column name to pass literal SQL (like NOW())
    my $feedback_policy_id = int( $data->{feedback_policy_id} || 0 );
    my $notnew             = $data->{notnew} ? 1 : 0;

    # Build insert hash - use -publishtime for literal SQL
    my $writeup_data = {
        writeup_id         => $draft_id,
        parent_e2node      => $parent_e2node_id,
        wrtype_writeuptype => $writeuptype_id,
        notnew             => $notnew,
        cooled             => 0, # Not cooled yet
        feedback_policy_id => $feedback_policy_id
    };

    # Handle publishtime - either user-provided string or NOW()
    if ($data->{publishtime}) {
        $writeup_data->{publishtime} = $data->{publishtime};
    } else {
        $writeup_data->{'-publishtime'} = 'NOW()';
    }

    $DB->sqlInsert('writeup', $writeup_data);

    # Update draft table entry - writeups extend drafts so they need the row
    # Set publication_status to 0 (published/public state) and clear collaborators
    $DB->sqlUpdate( 'draft', {
        publication_status => 0,
        collaborators => ''
    }, "draft_id=$draft_id" );

    # Add to e2node's nodegroup
    # nodegroup_id = the e2node (parent), node_id = the writeup (member)
    # Get max rank to add at end
    my ($max_rank) = $DB->sqlSelect( 'MAX(nodegroup_rank)', 'nodegroup',
        "nodegroup_id=$parent_e2node_id" );
    my $new_rank = defined($max_rank) ? $max_rank + 1 : 0;

    $DB->sqlInsert(
        'nodegroup',
        {
            nodegroup_id   => $parent_e2node_id,
            node_id        => $draft_id,
            nodegroup_rank => $new_rank,
            orderby        => $new_rank
        }
    );

    # Add to newwriteup table for tracking
    $DB->sqlInsert(
        'newwriteup',
        {
            node_id => $draft_id,
            notnew  => $notnew
        }
    );

    # Add to publish table for tracking publication
    $DB->sqlInsert(
        'publish',
        {
            publish_id => $draft_id,
            publisher  => $user_id
        }
    );

    # Update cache - increment version and remove from cache
    # The node is now in the wrong type cache (was draft, now writeup)
    $DB->getCache->incrementGlobalVersion($draft);
    $DB->getCache->removeNode($draft);

    # Commit transaction (releases lock) and restore AutoCommit
    eval {
        $dbh->commit();
        $dbh->{AutoCommit} = $orig_autocommit if $orig_autocommit;
    } or do {
        my $commit_error = $@ || 'Unknown commit error';
        $APP->devLog("Commit failed during publish_draft: $commit_error");
        # Even if commit fails, try to restore AutoCommit
        my $restore_ok = eval { $dbh->{AutoCommit} = $orig_autocommit if $orig_autocommit; 1 };
        # Ignore restore errors - we've already logged the commit failure
    };

    # Update newwriteups cache
    $APP->updateNewWriteups();

    # Add nodenote
    eval {
        $APP->addNodeNote( $draft,
            "Published from draft by [$REQUEST->user->{title}\[user]]",
            $REQUEST->user );
        1;
    } or do {
        # Log but don't fail the request if nodenote fails
        $APP->devLog("Failed to add nodenote for published draft $draft_id: $@");
    };

    return [
        $self->HTTP_OK,
        {
            success    => 1,
            writeup_id => $draft_id,
            e2node_id  => $parent_e2node_id,
            message    => 'Draft published successfully'
        }
    ];
}

sub render_preview {
    my ( $self, $REQUEST ) = @_;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [ $self->HTTP_BAD_REQUEST,
        { success => 0, error => 'invalid_json' } ]
      unless $json_ok && $data;

    my $html = $data->{html} // '';

    # Use E2's parseLinks to convert [link] syntax to actual links
    my $APP      = $self->APP;
    my $rendered = $APP->parseLinks($html);

    return [
        $self->HTTP_OK,
        {
            success => 1,
            html    => $rendered
        }
    ];
}

around [ 'list_or_create', 'get_or_update', 'search_drafts', 'set_parent_e2node',
    'publish_draft', 'render_preview' ] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;

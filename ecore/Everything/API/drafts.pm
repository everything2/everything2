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

=cut

sub routes {
    return {
        '/'        => 'list_or_create',
        '/:id'     => 'get_or_update',
        '/preview' => 'render_preview'
    };
}

sub list_or_create {
    my ($self, $REQUEST) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'get') {
        return $self->list_drafts($REQUEST);
    } elsif ($method eq 'post') {
        return $self->create_draft($REQUEST);
    }

    return [$self->HTTP_METHOD_NOT_ALLOWED, {
        success => 0,
        error => 'method_not_allowed'
    }];
}

sub get_or_update {
    my ($self, $REQUEST, $id) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'get') {
        return $self->get_draft($REQUEST, $id);
    } elsif ($method eq 'put' || $method eq 'post') {
        return $self->update_draft($REQUEST, $id);
    }

    return [$self->HTTP_METHOD_NOT_ALLOWED, {
        success => 0,
        error => 'method_not_allowed'
    }];
}

sub list_drafts {
    my ($self, $REQUEST) = @_;

    my $user_id = $REQUEST->user->node_id;
    my $DB = $self->DB;

    # Get pagination parameters from query string
    my $limit = int($REQUEST->param('limit') || 20);
    my $offset = int($REQUEST->param('offset') || 0);

    # Sanity checks
    $limit = 20 if $limit < 1 || $limit > 100;
    $offset = 0 if $offset < 0;

    my $draft_type = $DB->getType('draft');
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

    my $rows = $DB->{dbh}->selectall_arrayref($sql, { Slice => {} },
        $user_id, $draft_type_id, $limit, $offset);

    # Transform rows to match expected format (status instead of status_title)
    my @drafts = map {
        {
            node_id => $_->{node_id},
            title => $_->{title},
            createtime => $_->{createtime},
            status => $_->{status_title} || 'unknown',
            doctext => $_->{doctext} || ''
        }
    } @$rows;

    # Get total count for pagination metadata
    my $total = $DB->{dbh}->selectrow_array(
        'SELECT COUNT(*) FROM node WHERE author_user = ? AND type_nodetype = ?',
        {}, $user_id, $draft_type_id
    );

    return [$self->HTTP_OK, {
        success => 1,
        drafts => \@drafts,
        pagination => {
            limit => $limit,
            offset => $offset,
            total => $total || 0,
            has_more => ($offset + $limit) < ($total || 0)
        }
    }];
}

sub get_draft {
    my ($self, $REQUEST, $draft_id) = @_;

    $draft_id = int($draft_id || 0);
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_id' }]
        unless $draft_id > 0;

    my $user_id = $REQUEST->user->node_id;
    my $DB = $self->DB;

    my $draft = $DB->getNodeById($draft_id);
    return [$self->HTTP_NOT_FOUND, { success => 0, error => 'not_found' }]
        unless $draft;

    # Check ownership
    unless ($draft->{author_user} == $user_id || $self->APP->isEditor($REQUEST->user->NODEDATA)) {
        return [$self->HTTP_FORBIDDEN, { success => 0, error => 'permission_denied' }];
    }

    # Get document text
    my $doctext = $DB->{dbh}->selectrow_array(
        'SELECT doctext FROM document WHERE document_id = ?',
        {}, $draft_id
    ) || '';

    # Get publication status title
    my $status_title = $DB->{dbh}->selectrow_array(
        'SELECT title FROM node WHERE node_id = (SELECT publication_status FROM draft WHERE draft_id = ?)',
        {}, $draft_id
    ) || 'unknown';

    return [$self->HTTP_OK, {
        success => 1,
        draft => {
            node_id => $draft->{node_id},
            title => $draft->{title},
            doctext => $doctext,
            status => $status_title,
            createtime => $draft->{createtime}
        }
    }];
}

sub create_draft {
    my ($self, $REQUEST) = @_;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_json' }]
        unless $json_ok && $data;

    my $title = $data->{title} || 'Untitled Draft';
    my $doctext = $data->{doctext} // '';

    my $user_id = $REQUEST->user->node_id;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Clean the title
    $title = $APP->cleanNodeName($title) || 'untitled draft';

    # Get draft type and default status
    my $draft_type = $DB->getType('draft');
    my $private_status = $DB->getNode('private', 'publication_status');

    # Check for duplicate titles
    my $base_title = $title;
    my $count = 1;
    while ($DB->{dbh}->selectrow_array(
        'SELECT node_id FROM node WHERE title = ? AND type_nodetype = ? AND author_user = ?',
        {}, $title, $draft_type->{node_id}, $user_id
    )) {
        $title = "$base_title ($count)";
        $count++;
    }

    # Create the draft node
    # insertNode signature: ($title, $TYPE, $USER, $NODEDATA, $skip_maintenance)
    # NODEDATA is passed to updateNode after creation, so we can set doctext and publication_status there
    my $nodedata = {
        doctext => $doctext,
        publication_status => $private_status->{node_id}
    };

    my $draft_id = $DB->insertNode($title, $draft_type, $REQUEST->user->NODEDATA, $nodedata);
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { success => 0, error => 'insert_failed' }]
        unless $draft_id;

    return [$self->HTTP_OK, {
        success => 1,
        draft => {
            node_id => $draft_id,
            title => $title,
            status => 'private'
        }
    }];
}

sub update_draft {
    my ($self, $REQUEST, $draft_id) = @_;

    $draft_id = int($draft_id || 0);
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_id' }]
        unless $draft_id > 0;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_json' }]
        unless $json_ok && $data;

    my $user_id = $REQUEST->user->node_id;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get the draft
    my $draft = $DB->getNodeById($draft_id);
    return [$self->HTTP_NOT_FOUND, { success => 0, error => 'not_found' }]
        unless $draft && $draft->{type}{title} eq 'draft';

    # Check ownership
    unless ($draft->{author_user} == $user_id) {
        return [$self->HTTP_FORBIDDEN, { success => 0, error => 'permission_denied' }];
    }

    my $updated = {};

    # Update doctext if provided
    if (exists $data->{doctext}) {
        # Stash current content to version history before overwriting
        my $current_doctext = $DB->{dbh}->selectrow_array(
            'SELECT doctext FROM document WHERE document_id = ?',
            {}, $draft_id
        );

        # Only stash if there's existing content and it's different
        if (defined $current_doctext && $current_doctext ne $data->{doctext}) {
            $DB->{dbh}->do(
                'INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type) VALUES (?, ?, ?, NOW(), ?)',
                {}, $user_id, $draft_id, $current_doctext, 'manual'
            );

            # Prune old versions - keep last 20
            $self->_prune_version_history($user_id, $draft_id);
        }

        # Update the main document
        $DB->{dbh}->do(
            'UPDATE document SET doctext = ? WHERE document_id = ?',
            {}, $data->{doctext}, $draft_id
        );
        $updated->{doctext} = 1;
    }

    # Update title if provided
    if (exists $data->{title} && $data->{title} ne $draft->{title}) {
        my $new_title = $APP->cleanNodeName($data->{title}) || 'untitled draft';

        # Check for duplicates
        my $base_title = $new_title;
        my $count = 1;
        while ($DB->{dbh}->selectrow_array(
            'SELECT node_id FROM node WHERE title = ? AND type_nodetype = ? AND author_user = ? AND node_id != ?',
            {}, $new_title, $draft->{type_nodetype}, $user_id, $draft_id
        )) {
            $new_title = "$base_title ($count)";
            $count++;
        }

        $DB->{dbh}->do(
            'UPDATE node SET title = ? WHERE node_id = ?',
            {}, $new_title, $draft_id
        );
        $updated->{title} = $new_title;
    }

    # Update publication status if provided
    if (exists $data->{status}) {
        my $status_node = $DB->getNode($data->{status}, 'publication_status');
        if ($status_node) {
            my $old_status = $DB->{dbh}->selectrow_array(
                'SELECT publication_status FROM draft WHERE draft_id = ?',
                {}, $draft_id
            );

            $DB->{dbh}->do(
                'UPDATE draft SET publication_status = ? WHERE draft_id = ?',
                {}, $status_node->{node_id}, $draft_id
            );
            $updated->{status} = $data->{status};

            # If changing to review, notify editors
            if ($data->{status} eq 'review' && $old_status != $status_node->{node_id}) {
                $self->_notify_review($draft_id, $user_id);
            }
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        updated => $updated,
        draft_id => $draft_id
    }];
}

sub _notify_review {
    my ($self, $draft_id, $author_id) = @_;

    # Add a nodenote that author requested review
    my $note_sql = q|
        INSERT INTO nodenote (nodenote_nodeid, noter_user, notetext, timestamp)
        VALUES (?, 0, 'author requested review', NOW())
    |;
    $self->DB->{dbh}->do($note_sql, {}, $draft_id);

    return;
}

sub _prune_version_history {
    my ($self, $user_id, $node_id, $max) = @_;

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

# Get available publication statuses for UI
sub get_statuses {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    # Get statuses that users can set (not nuked/removed which are editor-only)
    my @user_statuses = qw(private shared findable review);

    my @statuses;
    for my $status_name (@user_statuses) {
        my $status = $DB->getNode($status_name, 'publication_status');
        if ($status) {
            push @statuses, {
                id => $status->{node_id},
                name => $status->{title},
                description => $self->_status_description($status->{title})
            };
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        statuses => \@statuses
    }];
}

sub _status_description {
    my ($self, $status) = @_;

    my %descriptions = (
        'private' => 'Only you can see this draft',
        'shared' => 'Visible to users you specify as collaborators',
        'findable' => 'Visible to all logged-in users',
        'review' => 'Submit for editor review before publishing'
    );

    return $descriptions{$status} || '';
}

sub render_preview {
    my ($self, $REQUEST) = @_;

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'invalid_json' }]
        unless $json_ok && $data;

    my $html = $data->{html} // '';

    # Use E2's parseLinks to convert [link] syntax to actual links
    my $APP = $self->APP;
    my $rendered = $APP->parseLinks($html);

    return [$self->HTTP_OK, {
        success => 1,
        html => $rendered
    }];
}

around ['list_or_create', 'get_or_update', 'render_preview'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;

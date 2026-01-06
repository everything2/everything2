package Everything::API::weblog;

use Moose;
use namespace::autoclean;
use JSON;
extends 'Everything::API';

=head1 NAME

Everything::API::weblog - Weblog entry management API

=head1 DESCRIPTION

Handles weblog entry operations (list, remove entries from weblogs).
Used by News for Noders and usergroup weblogs.

=head1 ENDPOINTS

=head2 GET /api/weblog/:weblog_id

List weblog entries with pagination.

Query parameters:
  - limit: Number of entries to return (default 5, max 20)
  - offset: Number of entries to skip (default 0)

=head2 DELETE /api/weblog/:weblog_id/:to_node

Remove an entry from a weblog (soft delete by setting removedby_user).

=cut

sub routes {
    return {
        '/available' => 'get_available_groups',
        '/:id' => 'handle_weblog(:id)',
        '/:id/:to_node' => 'handle_entry(:id, :to_node)',
    };
}

=head2 GET /api/weblog/available

Returns list of usergroups the current user can post to.

=cut

sub get_available_groups {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    if ($user->is_guest) {
        return [$self->HTTP_OK, {
            success => 1,
            groups => []
        }];
    }

    my $VARS = $user->VARS;
    my @groups;

    # Get user's can_weblog list
    my $can_weblog = $VARS->{can_weblog} || '';
    my @weblog_ids = split(',', $can_weblog);

    # If can_weblog is empty, get all usergroups the user is a member of
    unless (@weblog_ids && $weblog_ids[0]) {
        my $csr = $DB->sqlSelectMany(
            'DISTINCT nodegroup_id',
            'nodegroup',
            'node_id=' . $user->node_id
        );
        while (my $row = $csr->fetchrow_hashref()) {
            push @weblog_ids, $row->{nodegroup_id};
        }
    }

    # Get webloggables setting for ify display names
    my $webloggables_node = $DB->getNode('webloggables', 'setting');
    my $webloggables = $webloggables_node ? $APP->getVars($webloggables_node) : {};

    # Build available groups list
    foreach my $gid (@weblog_ids) {
        next unless $gid;
        my $group = $DB->getNodeById($gid, 'light');
        next unless $group && $group->{type}{title} eq 'usergroup';

        my $ify_display = $webloggables->{$gid};

        push @groups, {
            node_id => int($group->{node_id}),
            title => $group->{title},
            ($ify_display ? (ify_display => $ify_display) : ())
        };
    }

    return [$self->HTTP_OK, {
        success => 1,
        groups => \@groups
    }];
}

sub handle_weblog {
    my ($self, $REQUEST, $weblog_id) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'get') {
        return $self->list_entries($REQUEST, $weblog_id);
    } elsif ($method eq 'post') {
        return $self->add_entry($REQUEST, $weblog_id);
    }

    return [$self->HTTP_OK, {
        success => 0,
        error => 'Method not allowed'
    }];
}

sub add_entry {
    my ($self, $REQUEST, $weblog_id) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Check if user is logged in
    if ($user->is_guest) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Must be logged in'
        }];
    }

    # Validate weblog_id
    $weblog_id = int($weblog_id || 0);
    unless ($weblog_id) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid weblog_id'
        }];
    }

    # Get the usergroup node
    my $usergroup = $DB->getNodeById($weblog_id);
    unless ($usergroup) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Usergroup not found'
        }];
    }

    # Verify it's a usergroup
    unless ($usergroup->{type}{title} eq 'usergroup') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Target is not a usergroup'
        }];
    }

    # Get target node to link
    my $data = $REQUEST->JSON_POSTDATA;
    my $to_node = int($data->{to_node} || 0);

    unless ($to_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Missing to_node parameter'
        }];
    }

    # Get the target node
    my $target = $DB->getNodeById($to_node);
    unless ($target) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Target node not found'
        }];
    }

    # Target must be a document type (has doctext)
    unless ($target->{type}{sqltablelist} && $target->{type}{sqltablelist} =~ /document/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Target must be a document type'
        }];
    }

    # Can't link a usergroup to itself
    if ($target->{type}{title} eq 'usergroup') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Cannot link usergroups to weblogs'
        }];
    }

    # Check permissions: user must be approved for this usergroup
    # isApproved returns true if: user is god, user is the node, or user is in the group
    my $is_approved = Everything::isApproved($user->NODEDATA, $usergroup);

    unless ($is_approved) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'You do not have permission to post to this usergroup'
        }];
    }

    # Check if entry already exists
    my $exists = $DB->sqlSelect(
        'weblog_id',
        'weblog',
        "weblog_id=$weblog_id AND to_node=$to_node"
    );

    if ($exists) {
        # Re-activate if it was removed, update the linker
        $DB->sqlUpdate('weblog', {
            removedby_user => 0,
            linkedby_user => $user->node_id
        }, "weblog_id=$weblog_id AND to_node=$to_node");
    } else {
        # Create new entry
        $DB->sqlInsert('weblog', {
            weblog_id => $weblog_id,
            to_node => $to_node,
            linkedby_user => $user->node_id,
            -linkedtime => 'NOW()'
        });
    }

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Entry added to weblog',
        weblog_id => $weblog_id,
        to_node => $to_node
    }];
}

sub list_entries {
    my ($self, $REQUEST, $weblog_id) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Validate weblog_id
    $weblog_id = int($weblog_id || 0);
    unless ($weblog_id) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid weblog_id'
        }];
    }

    # Get pagination parameters
    my $limit = int($query->param('limit') || 5);
    my $offset = int($query->param('offset') || 0);

    # Enforce limits
    $limit = 20 if $limit > 20;
    $limit = 1 if $limit < 1;
    $offset = 0 if $offset < 0;

    # Get the weblog node to check it exists
    my $weblog_node = $DB->getNodeById($weblog_id);
    unless ($weblog_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Weblog not found'
        }];
    }

    # Query weblog entries
    my $sql = "SELECT to_node, linkedby_user, linkedtime
               FROM weblog
               WHERE weblog_id = ?
                 AND removedby_user = 0
               ORDER BY linkedtime DESC
               LIMIT ? OFFSET ?";

    my $sth = $DB->getDatabaseHandle()->prepare($sql);
    $sth->execute($weblog_id, $limit, $offset);

    my @entries;
    while (my $row = $sth->fetchrow_hashref()) {
        my $linked_node = $DB->getNodeById($row->{to_node});

        # Skip if node doesn't exist or is a draft (unpublished)
        next unless $linked_node;
        next if $linked_node->{type}{title} eq 'draft';

        my $linker = $DB->getNodeById($row->{linkedby_user});
        my $author = $linked_node->{author_user}
            ? $DB->getNodeById($linked_node->{author_user})
            : undef;

        push @entries, {
            to_node => int($row->{to_node}),
            title => $linked_node->{title},
            type => $linked_node->{type}{title},
            doctext => $linked_node->{doctext} || '',
            linkedtime => $row->{linkedtime},
            linkedby => $linker ? {
                node_id => int($linker->{node_id}),
                title => $linker->{title}
            } : undef,
            author => $author ? {
                node_id => int($author->{node_id}),
                title => $author->{title}
            } : undef,
            author_user => $linked_node->{author_user} ? int($linked_node->{author_user}) : undef
        };
    }

    # Check if there are more entries
    my $check_more = $DB->sqlSelect(
        'to_node',
        'weblog',
        "weblog_id = $weblog_id AND removedby_user = 0",
        "LIMIT 1 OFFSET " . ($offset + $limit)
    );

    # Determine removal permissions
    my $can_remove = 0;
    unless ($user->is_guest) {
        $can_remove = 1 if $APP->isAdmin($user->NODEDATA);

        # Check if user is the usergroup owner (if this is a usergroup weblog)
        if (!$can_remove && $weblog_node->{type}{title} eq 'usergroup') {
            my $owner_id = $APP->getParameter($weblog_id, 'usergroup_owner');
            $can_remove = 1 if $owner_id && $user->node_id == $owner_id;
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        entries => \@entries,
        has_more => $check_more ? 1 : 0,
        offset => $offset,
        limit => $limit,
        can_remove => $can_remove
    }];
}

sub handle_entry {
    my ($self, $REQUEST, $weblog_id, $to_node) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'delete') {
        return $self->remove_entry($REQUEST, $weblog_id, $to_node);
    }

    return [$self->HTTP_OK, {
        success => 0,
        error => 'Method not allowed'
    }];
}

sub remove_entry {
    my ($self, $REQUEST, $weblog_id, $to_node) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Validate IDs
    $weblog_id = int($weblog_id || 0);
    $to_node = int($to_node || 0);

    unless ($weblog_id && $to_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid weblog_id or to_node'
        }];
    }

    # Check if user is logged in
    if ($user->is_guest) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Must be logged in'
        }];
    }

    # Get the weblog node to check ownership
    my $weblog_node = $DB->getNodeById($weblog_id);
    unless ($weblog_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Weblog not found'
        }];
    }

    # Check permissions: admin, usergroup owner, or original linker
    my $is_admin = $APP->isAdmin($user->NODEDATA);
    my $is_owner = 0;

    # Check if user is the usergroup owner (if this is a usergroup weblog)
    if ($weblog_node->{type}{title} eq 'usergroup') {
        my $owner_id = $APP->getParameter($weblog_id, 'usergroup_owner');
        $is_owner = 1 if $owner_id && $user->node_id == $owner_id;
    }

    # Check if user originally linked this entry
    my $is_linker = $DB->sqlSelect(
        'linkedby_user',
        'weblog',
        "weblog_id=" . $DB->quote($weblog_id) .
        " AND to_node=" . $DB->quote($to_node) .
        " AND linkedby_user=" . $DB->quote($user->node_id) .
        " AND removedby_user=0"
    );

    unless ($is_admin || $is_owner || $is_linker) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Permission denied'
        }];
    }

    # Check that the entry exists and isn't already removed
    my $entry_exists = $DB->sqlSelect(
        'to_node',
        'weblog',
        "weblog_id=" . $DB->quote($weblog_id) .
        " AND to_node=" . $DB->quote($to_node) .
        " AND removedby_user=0"
    );

    unless ($entry_exists) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Entry not found or already removed'
        }];
    }

    # Perform the soft delete
    my $sth = $DB->getDatabaseHandle()->prepare(
        'UPDATE weblog SET removedby_user=? WHERE weblog_id=? AND to_node=?'
    );
    $sth->execute($user->node_id, $weblog_id, $to_node);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Entry removed'
    }];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::API>

=cut

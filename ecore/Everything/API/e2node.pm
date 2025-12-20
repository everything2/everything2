package Everything::API::e2node;

use Moose;
extends 'Everything::API';

# API endpoints for e2node management operations
# These operations are restricted to editors only

sub routes {
    return {
        ":id/firmlink"           => "create_firmlink(:id)",
        ":id/firmlink/:target"   => "remove_firmlink(:id,:target)",
        ":id/repair"             => "repair_node(:id)",
        ":id/orderlock"          => "toggle_orderlock(:id)",
        ":id/title"              => "change_title(:id)",
        ":id/lock"               => "node_lock(:id)",
        ":id/reorder"            => "reorder_writeups(:id)",
        ":id/softlinks"          => "manage_softlinks(:id)",
    };
}

#############################################################################
# POST /api/e2node/:id/firmlink
# Create a firmlink from this node to another node
#############################################################################

sub create_firmlink {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Get request data
    my $data         = $REQUEST->JSON_POSTDATA;
    my $to_node_name = $data->{to_node}   || '';
    my $note_text    = $data->{note_text} || '';

    unless ($to_node_name) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'Target node name required' }
        ];
    }

    # Find target node (try multiple types)
    my $target_node;
    foreach my $type (qw/superdoc document superdocnolinks e2node user/) {
        $target_node = $self->DB->getNode( $to_node_name, $type );
        last if $target_node;
    }

    unless ($target_node) {
        return [ $self->HTTP_OK,
            { success => 0, error => "Target node '$to_node_name' not found" }
        ];
    }

    # Can't firmlink to self
    if ( $target_node->{node_id} == $e2node_id ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'Cannot firmlink a node to itself' }
        ];
    }

    # Get firmlink linktype
    my $firmlink_type = $self->DB->getNode( 'firmlink', 'linktype' );
    unless ($firmlink_type) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'Firmlink type not found in database' }
        ];
    }

    # Check if firmlink already exists
    my $existing_link = $self->DB->sqlSelectHashref( '*', 'links',
            "from_node=$e2node_id AND to_node="
          . $target_node->{node_id}
          . " AND linktype="
          . $firmlink_type->{node_id} );

    if ($existing_link) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Firmlink already exists to ' . $target_node->{title}
            }
        ];
    }

    # Create firmlink
    $self->DB->sqlInsert(
        'links',
        {
            linktype  => $firmlink_type->{node_id},
            to_node   => $target_node->{node_id},
            from_node => $e2node_id
        }
    );

    # Create firmlink note if provided
    if ($note_text) {
        $self->DB->sqlInsert(
            'firmlink_note',
            {
                to_node            => $target_node->{node_id},
                from_node          => $e2node_id,
                firmlink_note_text => $note_text
            }
        );
    }

    # Get updated firmlinks list to return to client
    my $firmlinks = $self->_get_firmlinks($e2node_id);

    return [
        $self->HTTP_OK,
        {
            success   => 1,
            message   => 'Firmlink created to ' . $target_node->{title},
            firmlinks => $firmlinks,
            target    => {
                node_id => $target_node->{node_id},
                title   => $target_node->{title}
            }
        }
    ];
}

#############################################################################
# POST /api/e2node/:id/repair
# Repair e2node (fix writeup titles and metadata)
#############################################################################

sub repair_node {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Get request data
    my $data       = $REQUEST->JSON_POSTDATA || {};
    my $no_reorder = $data->{no_reorder}     || 0;

    # Repair the node
    $self->APP->repairE2Node( $e2node->NODEDATA, $no_reorder );

    my $message =
      $no_reorder
      ? 'Node repaired successfully (without reordering)'
      : 'Node repaired and reordered successfully';

    return [
        $self->HTTP_OK,
        {
            success => 1,
            message => $message
        }
    ];
}

#############################################################################
# POST /api/e2node/:id/orderlock
# Toggle writeup order lock on/off
#############################################################################

sub toggle_orderlock {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Get request data
    my $data   = $REQUEST->JSON_POSTDATA || {};
    my $unlock = $data->{unlock}         || 0;

    # Get the node hashref
    my $node_data = $e2node->NODEDATA;

    # Toggle order lock
    if ($unlock) {
        $node_data->{orderlock_user} = 0;
    }
    else {
        $node_data->{orderlock_user} = $user->node_id;
    }

    # Update the node
    $self->DB->updateNode( $node_data, -1 );

    return [
        $self->HTTP_OK,
        {
            success => 1,
            message => $unlock
            ? 'Writeup order unlocked'
            : 'Writeup order locked',
            orderlock_user => $node_data->{orderlock_user}
        }
    ];
}

#############################################################################
# POST /api/e2node/:id/title
# Change e2node title (rename)
#############################################################################

sub change_title {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Get request data
    my $data      = $REQUEST->JSON_POSTDATA;
    my $new_title = $data->{new_title} || '';

    unless ($new_title) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'New title required' } ];
    }

    my $old_title = $e2node->title;

    # Check if title actually changed
    if ( $new_title eq $old_title ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'New title is same as current title' }
        ];
    }

    # Check if target title already exists
    my $existing = $self->DB->getNode( $new_title, 'e2node' );
    if ($existing) {
        return [
            $self->HTTP_OK,
            {
                success      => 0,
                error        => 'An e2node with that title already exists',
                existing_id  => $existing->{node_id},
                existing_url => "/title/" . uri_escape($new_title)
            }
        ];
    }

    # Get node hashref
    my $node_data = $e2node->NODEDATA;

    # Update the title
    $node_data->{title} = $new_title;

    # Update the node
    my $result = $self->DB->updateNode( $node_data, -1 );

    unless ($result) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'Failed to update node title' }
        ];
    }

    # Repair the node to update all contained writeups
    $self->APP->repairE2Node( $node_data, 'no-reorder' );

    return [
        $self->HTTP_OK,
        {
            success   => 1,
            message   => "Title changed from '$old_title' to '$new_title'",
            new_title => $new_title,
            new_url   => "/title/" . uri_escape($new_title)
        }
    ];
}

#############################################################################
# GET /api/e2node/:id/lock
# Get node lock status
#
# POST /api/e2node/:id/lock
# Lock/unlock node to prevent writeup creation
#############################################################################

sub node_lock {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Check if this is a GET request (no POST data) or POST request
    my $data = $REQUEST->JSON_POSTDATA;

    # GET request - return lock status (when no action specified)
    if ( !$data || !$data->{action} ) {
        my $lock = $self->DB->sqlSelectHashref( '*', 'nodelock',
            "nodelock_node=$e2node_id" );

        if ($lock) {
            return [
                $self->HTTP_OK,
                {
                    success => 1,
                    locked  => 1,
                    lock    => {
                        reason  => $lock->{nodelock_reason},
                        user_id => $lock->{nodelock_user}
                    }
                }
            ];
        }
        else {
            return [
                $self->HTTP_OK,
                {
                    success => 1,
                    locked  => 0
                }
            ];
        }
    }

    # POST request - lock or unlock node
    my $action = $data->{action};

    if ( $action eq 'unlock' ) {

        # Delete the lock
        $self->DB->sqlDelete( 'nodelock', "nodelock_node=$e2node_id" );

        return [
            $self->HTTP_OK,
            {
                success => 1,
                message => 'Node unlocked',
                locked  => 0
            }
        ];
    }
    elsif ( $action eq 'lock' ) {
        my $reason = $data->{reason} || '';

        unless ($reason) {
            return [
                $self->HTTP_OK,
                { success => 0, error => 'Lock reason required' }
            ];
        }

        # Check if already locked
        my $existing_lock = $self->DB->sqlSelectHashref( '*', 'nodelock',
            "nodelock_node=$e2node_id" );

        if ($existing_lock) {
            return [
                $self->HTTP_OK,
                { success => 0, error => 'Node is already locked' }
            ];
        }

        # Create the lock
        $self->DB->sqlInsert(
            'nodelock',
            {
                nodelock_reason => $reason,
                nodelock_user   => $user->node_id,
                nodelock_node   => $e2node_id
            }
        );

        return [
            $self->HTTP_OK,
            {
                success => 1,
                message => 'Node locked',
                locked  => 1,
                user_id => $user->node_id
            }
        ];
    }
    else {
        return [ $self->HTTP_OK,
            { success => 0, error => 'Invalid action. Use "lock" or "unlock"' }
        ];
    }
}

#############################################################################
# DELETE /api/e2node/:id/firmlink/:target
# Remove a firmlink from this node to target node
#############################################################################

sub remove_firmlink {
    my ( $self, $REQUEST, $e2node_id, $target_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Validate target node exists
    my $target_node = $self->APP->node_by_id($target_id);
    unless ($target_node) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'Target node not found' } ];
    }

    # Get firmlink linktype
    my $firmlink_type = $self->DB->getNode( 'firmlink', 'linktype' );
    unless ($firmlink_type) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'Firmlink type not found in database' }
        ];
    }

    # Check if firmlink exists
    my $existing_link = $self->DB->sqlSelectHashref( '*', 'links',
            "from_node=$e2node_id AND to_node="
          . $target_id
          . " AND linktype="
          . $firmlink_type->{node_id} );

    unless ($existing_link) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Firmlink does not exist to ' . $target_node->title
            }
        ];
    }

    # Remove the firmlink
    $self->DB->sqlDelete( 'links',
            "from_node=$e2node_id AND to_node="
          . $target_id
          . " AND linktype="
          . $firmlink_type->{node_id} );

    # Remove firmlink note if it exists
    $self->DB->sqlDelete( 'firmlink_note',
        "from_node=$e2node_id AND to_node=" . $target_id );

    # Get updated firmlinks list to return to client
    my $firmlinks = $self->_get_firmlinks($e2node_id);

    return [
        $self->HTTP_OK,
        {
            success   => 1,
            message   => 'Firmlink removed from ' . $target_node->title,
            firmlinks => $firmlinks
        }
    ];
}

#############################################################################
# POST /api/e2node/:id/reorder
# Reorder writeups within an e2node
# Request body: {
#   writeup_ids: [123, 456, 789],  // New order for writeups
#   reset_to_default: false,       // Reset to publishtime order
#   lock_order: true/false         // Set orderlock (optional)
# }
#############################################################################

sub reorder_writeups {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Get request data
    my $data = $REQUEST->JSON_POSTDATA || {};
    my $node_data = $e2node->NODEDATA;
    my $message = '';

    # Handle orderlock if specified
    if ( exists $data->{lock_order} ) {
        if ( $data->{lock_order} ) {
            $node_data->{orderlock_user} = $user->node_id;
            $message = 'Order locked. ';
        }
        else {
            $node_data->{orderlock_user} = 0;
            $message = 'Order unlocked. ';
        }
        $self->DB->updateNode( $node_data, -1 );
    }

    # Handle reset to default (order by publishtime ascending)
    if ( $data->{reset_to_default} ) {
        # Get writeups ordered by publishtime ascending (default order)
        my $cursor = $self->DB->{dbh}->prepare(
            "SELECT ng.node_id, w.publishtime
             FROM nodegroup ng
             JOIN writeup w ON w.writeup_id = ng.node_id
             WHERE ng.nodegroup_id = ?
             ORDER BY w.publishtime ASC"
        );
        $cursor->execute($e2node_id);

        my $orderby = 0;
        while ( my $row = $cursor->fetchrow_hashref ) {
            $self->DB->sqlUpdate(
                'nodegroup',
                { orderby => $orderby },
                "nodegroup_id = $e2node_id AND node_id = " . $row->{node_id}
            );
            $orderby++;
        }
        $cursor->finish;

        return [
            $self->HTTP_OK,
            {
                success        => 1,
                message        => $message . 'Writeup order reset to default (by publish time)',
                orderlock_user => $node_data->{orderlock_user}
            }
        ];
    }

    # Handle manual reorder
    my $writeup_ids = $data->{writeup_ids};

    # If only changing lock_order without reordering, return success
    if ( !$writeup_ids && exists $data->{lock_order} ) {
        return [
            $self->HTTP_OK,
            {
                success        => 1,
                message        => $data->{lock_order} ? 'Order locked' : 'Order unlocked',
                orderlock_user => $node_data->{orderlock_user}
            }
        ];
    }

    unless ( $writeup_ids && ref($writeup_ids) eq 'ARRAY' && @$writeup_ids > 0 ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'writeup_ids array required' }
        ];
    }

    # Validate all writeup IDs belong to this e2node
    my $existing_ids = $self->DB->{dbh}->selectcol_arrayref(
        "SELECT node_id FROM nodegroup WHERE nodegroup_id = ?",
        {}, $e2node_id
    );

    my %existing_set = map { $_ => 1 } @$existing_ids;

    foreach my $wid (@$writeup_ids) {
        unless ( $existing_set{$wid} ) {
            return [
                $self->HTTP_OK,
                { success => 0, error => "Writeup $wid does not belong to this e2node" }
            ];
        }
    }

    # Check that all existing writeups are in the new order
    if ( scalar(@$writeup_ids) != scalar(@$existing_ids) ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'writeup_ids must contain all writeups in the e2node' }
        ];
    }

    # Update orderby values
    my $orderby = 0;
    foreach my $writeup_id (@$writeup_ids) {
        $self->DB->sqlUpdate(
            'nodegroup',
            { orderby => $orderby },
            "nodegroup_id = $e2node_id AND node_id = $writeup_id"
        );
        $orderby++;
    }

    return [
        $self->HTTP_OK,
        {
            success        => 1,
            message        => $message . 'Writeup order updated successfully',
            orderlock_user => $node_data->{orderlock_user}
        }
    ];
}

#############################################################################
# Helper function: Get firmlinks for an e2node
# Returns array of {node_id, title, type} hashrefs
#############################################################################

sub _get_firmlinks {
    my ( $self, $e2node_id ) = @_;

    # Get firmlink linktype
    my $firmlink_type = $self->DB->getNode( 'firmlink', 'linktype' );
    return [] unless $firmlink_type;

    # Get all firmlinks for this e2node with note text
    my $cursor = $self->DB->sqlSelectMany(
        'links.to_node, note.firmlink_note_text',
        'links
        LEFT JOIN firmlink_note AS note
          ON note.from_node = links.from_node
          AND note.to_node = links.to_node',
        "links.from_node=$e2node_id AND links.linktype=" . $firmlink_type->{node_id}
    );

    my @firmlinks;
    while ( my $row = $cursor->fetchrow_hashref ) {
        my $target = $self->APP->node_by_id($row->{to_node});
        if ($target) {
            my $firmlink = {
                node_id => $target->node_id,
                title   => $target->title,
                type    => $target->type->title
            };
            # Include note text if present
            $firmlink->{note_text} = $row->{firmlink_note_text} if $row->{firmlink_note_text};
            push @firmlinks, $firmlink;
        }
    }
    $cursor->finish;

    return \@firmlinks;
}

#############################################################################
# GET /api/e2node/:id/softlinks
# Get all softlinks for an e2node (ordered by hits descending)
#
# POST /api/e2node/:id/softlinks
# Delete selected softlinks from an e2node
# Request body: {
#   delete_ids: [123, 456, 789]  // Array of to_node IDs to delete
# }
#############################################################################

sub manage_softlinks {
    my ( $self, $REQUEST, $e2node_id ) = @_;
    my $user = $REQUEST->user;

    # Check editor permission
    unless ( $user->is_editor ) {
        return [
            $self->HTTP_OK, { success => 0, error => 'Editor access required' }
        ];
    }

    # Validate e2node exists
    my $e2node = $self->APP->node_by_id($e2node_id);
    unless ( $e2node && $e2node->type->title eq 'e2node' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'E2node not found' } ];
    }

    # Check if this is a GET request (no POST data) or POST request
    my $data = $REQUEST->JSON_POSTDATA;

    # GET request - return all softlinks
    if ( !$data || !$data->{delete_ids} ) {
        my $softlinks = $self->_get_softlinks($e2node_id);
        return [
            $self->HTTP_OK,
            {
                success   => 1,
                softlinks => $softlinks
            }
        ];
    }

    # POST request - delete selected softlinks
    my $delete_ids = $data->{delete_ids};

    unless ( ref($delete_ids) eq 'ARRAY' && @$delete_ids > 0 ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'delete_ids array required' }
        ];
    }

    # Softlinks have linktype=0
    my $deleted_count = 0;
    foreach my $to_node_id (@$delete_ids) {
        # Validate it's an integer
        next unless $to_node_id =~ /^\d+$/;

        # Delete the softlink
        my $rows = $self->DB->sqlDelete(
            'links',
            "from_node=$e2node_id AND to_node=$to_node_id AND linktype=0"
        );
        $deleted_count++ if $rows;
    }

    # Get updated softlinks list
    my $softlinks = $self->_get_softlinks($e2node_id);

    return [
        $self->HTTP_OK,
        {
            success       => 1,
            message       => "Deleted $deleted_count softlink(s)",
            deleted_count => $deleted_count,
            softlinks     => $softlinks
        }
    ];
}

#############################################################################
# Helper function: Get softlinks for an e2node
# Returns array of {node_id, title, hits} hashrefs ordered by hits desc
#############################################################################

sub _get_softlinks {
    my ( $self, $e2node_id ) = @_;

    my $cursor = $self->DB->{dbh}->prepare(
        'SELECT node.node_id, node.title, links.hits
         FROM links
         JOIN node ON node.node_id = links.to_node
         WHERE links.from_node = ? AND links.linktype = 0
         ORDER BY links.hits DESC'
    );
    $cursor->execute($e2node_id);

    my @softlinks;
    while ( my $row = $cursor->fetchrow_hashref ) {
        push @softlinks, {
            node_id => int($row->{node_id}),
            title   => $row->{title},
            hits    => int($row->{hits})
        };
    }
    $cursor->finish;

    return \@softlinks;
}

# Helper function for URL escaping
sub uri_escape {
    my ($str) = @_;
    $str =~ s/([^A-Za-z0-9\-._~])/sprintf("%%%02X", ord($1))/eg;
    return $str;
}

__PACKAGE__->meta->make_immutable;
1;

package Everything::API::debatecomments;

use Moose;
extends 'Everything::API';

use Everything qw(getNodeById);

# API for managing debatecomment nodes (usergroup discussions)
# Provides endpoints for creating replies, editing comments, and deleting threads

sub routes {
    return {
        '/action/create' => 'create_debate()',
        '/:id/action/reply' => 'reply(:id)',
        '/:id/action/save' => 'save(:id)',
        '/:id/action/delete' => 'delete_comment(:id)',
    };
}

# Create a new debate (root discussion thread)
sub create_debate {
    my ($self, $REQUEST) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;
    my $DB = $self->DB;

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid request data'}];
    }

    my $title = $data->{title};
    my $doctext = $data->{doctext} // '';
    my $restricted_id = int($data->{restricted} || 0);
    my $announce = $data->{announce} ? 1 : 0;

    unless ($title && length($title) > 0) {
        return [$self->HTTP_OK, {success => 0, error => 'Title is required'}];
    }

    unless ($restricted_id) {
        return [$self->HTTP_OK, {success => 0, error => 'Usergroup is required'}];
    }

    # Verify the usergroup exists and user is a member
    my $usergroup = $DB->getNodeById($restricted_id);
    unless ($usergroup && $usergroup->{type}{title} eq 'usergroup') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid usergroup'}];
    }

    # Check if user is a member of the usergroup (or admin)
    unless ($user->is_admin || $self->APP->inUsergroup($user->NODEDATA, $usergroup)) {
        return [$self->HTTP_OK, {success => 0, error => 'You must be a member of this usergroup'}];
    }

    # Get debate nodetype
    my $type = $DB->getType('debate');
    unless ($type) {
        return [$self->HTTP_OK, {success => 0, error => 'Could not find debate nodetype'}];
    }

    # Create the debate node
    # The debate_create maintenance will set root_debatecomment to self
    my $nodedata = {
        doctext => $doctext,
        parent_debatecomment => 0,
        root_debatecomment => 0,  # Will be set by maintenance
        restricted => $restricted_id,
    };

    my $new_id = $DB->insertNode($title, $type, $user->NODEDATA, $nodedata);

    unless ($new_id) {
        return [$self->HTTP_OK, {success => 0, error => 'Failed to create discussion'}];
    }

    # If announce requested, send message to usergroup
    if ($announce) {
        my $notify_ug_id = $restricted_id;
        # Notify e2gods instead of gods
        $notify_ug_id = 829913 if $notify_ug_id == 114;

        my $virgil = $DB->getNode('Virgil', 'user');
        if ($virgil) {
            $self->APP->sendPrivateMessage({
                author_id => $virgil->{node_id},
                recipient_id => $notify_ug_id,
                message => "Make it known, [" . $user->title . "] just started a new discussion: [" . $usergroup->{title} . ": " . $title . "]."
            });
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        node_id => int($new_id),
        message => 'Discussion created'
    }];
}

# Check if user can access the debatecomment based on root's restricted field
sub _check_access {
    my ($self, $user, $node) = @_;

    # Admins always have access
    return 1 if $user->is_admin;

    # Get root debatecomment to check restriction
    my $root_id = $node->NODEDATA->{root_debatecomment} || $node->node_id;
    my $root = $self->APP->node_by_id($root_id);
    return 0 unless $root;

    # Get the restricted usergroup (default to CE for legacy nodes)
    my $restricted_id = $root->NODEDATA->{restricted} || 923653;

    # Handle legacy magic numbers
    if ($restricted_id == 0) {
        $restricted_id = 923653;  # Content Editors
    } elsif ($restricted_id == 1) {
        $restricted_id = 114;     # gods
    }

    my $group = $self->DB->getNodeById($restricted_id);
    return 0 unless $group;

    return $self->APP->inUsergroup($user->NODEDATA, $group);
}

# Create a reply to a debatecomment
sub reply {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;
    my $DB = $self->DB;

    # Get the parent node
    my $parent = $self->APP->node_by_id($id);

    # Allow replying to both debatecomment and debate nodes (debate extends debatecomment)
    my $parent_type = $parent ? $parent->type->title : '';
    unless ($parent && ($parent_type eq 'debatecomment' || $parent_type eq 'debate')) {
        return [$self->HTTP_OK, {success => 0, error => 'Parent comment not found'}];
    }

    # Check access
    unless ($self->_check_access($user, $parent)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid request data'}];
    }

    my $title = $data->{title};
    my $doctext = $data->{doctext} // '';

    unless ($title && length($title) > 0) {
        return [$self->HTTP_OK, {success => 0, error => 'Title is required'}];
    }

    # Get root and restricted info from parent
    my $root_id = $parent->NODEDATA->{root_debatecomment} || $parent->node_id;
    my $restricted_id = $parent->NODEDATA->{restricted} || 923653;

    # Handle legacy magic numbers
    if ($restricted_id == 0) {
        $restricted_id = 923653;
    } elsif ($restricted_id == 1) {
        $restricted_id = 114;
    }

    # Get debatecomment nodetype
    my $type = $DB->getType('debatecomment');
    unless ($type) {
        return [$self->HTTP_OK, {success => 0, error => 'Could not find debatecomment nodetype'}];
    }

    # insertNode signature: ($title, $TYPE, $USER, $NODEDATA, $skip_maintenance)
    # Set debatecomment-specific fields in NODEDATA
    my $nodedata = {
        doctext => $doctext,
        parent_debatecomment => int($parent->node_id),
        root_debatecomment => int($root_id),
        restricted => int($restricted_id),
    };

    my $new_id = $DB->insertNode($title, $type, $user->NODEDATA, $nodedata);

    unless ($new_id) {
        return [$self->HTTP_OK, {success => 0, error => 'Failed to create reply'}];
    }

    # Get the created node for nodegroup insertion
    my $created = $DB->getNodeById($new_id);

    # Insert into parent's nodegroup
    $DB->insertIntoNodegroup($parent->NODEDATA, $user->node_id, $created);

    # Send notification to parent author (unless replying to self)
    my $parent_author_id = $parent->NODEDATA->{author_user};
    if ($parent_author_id && $parent_author_id != $user->node_id) {
        my $parent_author = $DB->getNodeById($parent_author_id);
        if ($parent_author) {
            my $parent_vars = $self->APP->getVars($parent_author);
            unless ($parent_vars && $parent_vars->{no_discussionreplynotify}) {
                my $replyer = $user->title;
                my $msg = "Attention, <a href=\"/user/$replyer\">$replyer</a> just replied to ";
                $msg .= "<a href=\"/?node_id=$root_id#debatecomment_$new_id\">" . $parent->title . "</a>.";

                my $virgil = $DB->getNode('Virgil', 'user');
                if ($virgil) {
                    $self->APP->sendPrivateMessage({
                        author_id => $virgil->{node_id},
                        recipient_id => $parent_author_id,
                        message => $msg
                    });
                }
            }
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        node_id => int($new_id),
        message => 'Reply created'
    }];
}

# Save/edit an existing debatecomment
sub save {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;
    my $DB = $self->DB;

    # Get the node
    my $node = $self->APP->node_by_id($id);

    # Allow editing both debatecomment and debate nodes (debate extends debatecomment)
    my $node_type = $node ? $node->type->title : '';
    unless ($node && ($node_type eq 'debatecomment' || $node_type eq 'debate')) {
        return [$self->HTTP_OK, {success => 0, error => 'Comment not found'}];
    }

    # Check access
    unless ($self->_check_access($user, $node)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}];
    }

    # Check if user can edit (author or admin)
    my $can_edit = $user->is_admin ||
        ($node->NODEDATA->{author_user} == $user->node_id);

    unless ($can_edit) {
        return [$self->HTTP_OK, {success => 0, error => 'Only the author or admins can edit this comment'}];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid request data'}];
    }

    # Update title if provided
    if (exists $data->{title} && length($data->{title}) > 0) {
        $node->NODEDATA->{title} = $data->{title};
    }

    # Update doctext if provided
    if (exists $data->{doctext}) {
        $node->NODEDATA->{doctext} = $data->{doctext} // '';
    }

    # Update the node
    $DB->updateNode($node->NODEDATA, $user->node_id);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Comment saved'
    }];
}

# Delete a debatecomment (admin only)
sub delete_comment {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;

    # Only admins can delete
    unless ($user->is_admin) {
        return [$self->HTTP_OK, {success => 0, error => 'Only administrators can delete comments'}];
    }

    my $DB = $self->DB;

    # Get the node
    my $node = $self->APP->node_by_id($id);

    # Allow deleting both debatecomment and debate nodes (debate extends debatecomment)
    my $node_type = $node ? $node->type->title : '';
    unless ($node && ($node_type eq 'debatecomment' || $node_type eq 'debate')) {
        return [$self->HTTP_OK, {success => 0, error => 'Comment not found'}];
    }

    # Delete the node and all children recursively
    my $deleted_count = $self->_delete_recursive($node->NODEDATA);

    return [$self->HTTP_OK, {
        success => 1,
        deleted_count => $deleted_count,
        message => "Deleted $deleted_count comment(s)"
    }];
}

# Recursively delete a comment and all its children
sub _delete_recursive {
    my ($self, $node) = @_;

    my $DB = $self->DB;
    my $count = 0;

    # Get children from nodegroup
    my $group = $node->{group} || [];

    # Delete children first
    foreach my $child_id (@$group) {
        my $child = $DB->getNodeById($child_id);
        next unless $child;
        $count += $self->_delete_recursive($child);
    }

    # Delete this node
    $DB->nukeNode($node, -1);
    $count++;

    return $count;
}

around ['create_debate', 'reply', 'save', 'delete_comment'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

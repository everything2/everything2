package Everything::Controller::usergroup;

use Moose;
extends 'Everything::Controller';

# Controller for usergroup nodes
# Migrated from Everything::Delegation::htmlpage::usergroup_display_page

# Fetch weblog entries for a usergroup
# Returns array of entry data with linked node info
sub _fetch_weblog_entries {
    my ($self, $weblog_id, $user, $limit, $offset) = @_;

    $limit  ||= 3;
    $offset ||= 0;

    my $DB  = $self->DB;
    my $APP = $self->APP;

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
            # Include author_user for comparison
            author_user => $linked_node->{author_user} ? int($linked_node->{author_user}) : undef
        };
    }

    return \@entries;
}

# Check if there are more weblog entries beyond the current page
sub _has_more_weblog_entries {
    my ($self, $weblog_id, $offset, $count_fetched) = @_;

    # If we fetched fewer than requested, there are no more
    return 0 if $count_fetched < 3;

    # Check if there's at least one more entry
    my $next_count = $self->DB->sqlSelect(
        'COUNT(*)',
        'weblog',
        "weblog_id = ? AND removedby_user = 0",
        "LIMIT 1 OFFSET ?",
        [$weblog_id, $offset + $count_fetched]
    );

    return $next_count ? 1 : 0;
}

sub display {
    my ( $self, $REQUEST, $node ) = @_;

    my $user = $REQUEST->user;
    my $user_id = $user->node_id;

    # Get usergroup data
    my $usergroup_data = $node->json_display($user);

    # Get usergroup owner
    my $owner_id = $self->APP->getParameter( $node->NODEDATA, 'usergroup_owner' ) || 0;
    my $owner_data;
    if ($owner_id) {
        my $owner = $self->APP->node_by_id($owner_id);
        $owner_data = $owner ? $owner->json_reference : undef;
    }

    # Check if current user is in the group
    my $is_in_group = $self->APP->inUsergroup( $user_id, $node->NODEDATA );

    # Get usergroup discussions link node ID (hardcoded in delegation)
    my $discussions_node_id = 1977025;

    # Check if user can view weblog (ify) settings
    my $weblog_setting;
    if ( $user->is_admin ) {
        my $weblog_node = $self->DB->getNode( 'webloggables', 'setting' );
        if ($weblog_node) {
            my $vars = $self->APP->getVars($weblog_node);
            $weblog_setting = $vars->{ $node->node_id } if $vars;
        }
    }

    # Check if admin can bulk-add users (not allowed for gods/e2gods groups)
    my $can_bulk_edit = 0;
    my $simple_editor_id;
    if ( $user->is_admin ) {
        my %no_bulk_edit = map { $_ => 1 } qw(gods e2gods);
        unless ( $no_bulk_edit{ $node->title } ) {
            $can_bulk_edit = 1;
            my $editor_node = $self->DB->getNode( 'simple usergroup editor', 'superdoc' );
            $simple_editor_id = $editor_node->{node_id} if $editor_node;
        }
    }

    # Get message count for this usergroup
    my $message_count = 0;
    unless ( $user->VARS->{hidemsgyou} ) {
        $message_count = $self->DB->sqlSelect(
            'count(*)', 'message',
            "for_user=$user_id and for_usergroup=" . $node->node_id
        );
    }

    # Build enhanced group member data with flags and formatting
    my @enhanced_members;
    my $owner_index;
    my $member_index = 0;

    # Flags to show based on usergroup context
    my $show_admin_flag = ( $node->title ne 'gods' );
    my $show_ce_flag    = ( $node->title ne 'Content Editors' );

    if ( $usergroup_data->{group} ) {
        foreach my $member_ref ( @{ $usergroup_data->{group} } ) {
            my $member_id = $member_ref->{node_id};
            my $member    = $self->APP->node_by_id($member_id);
            next unless $member;

            # Build flags string
            my $flags = '';
            if ($show_admin_flag) {
                if (   $self->APP->isAdmin($member_id)
                    && !$self->APP->getParameter( $member_id, "hide_chatterbox_staff_symbol" ) )
                {
                    $flags .= '@';
                }
            }

            if ($show_ce_flag) {
                if (   $self->APP->isEditor( $member_id, "nogods" )
                    && !$self->APP->isAdmin($member_id)
                    && !$self->APP->getParameter( $member_id, "hide_chatterbox_staff_symbol" ) )
                {
                    $flags .= '$';
                }
            }

            if ( $show_admin_flag && $self->APP->isChanop( $member_id, "nogods" ) ) {
                $flags .= '+';
            }

            # Mark owner and current user
            my $is_owner      = ( $member_id == $owner_id );
            my $is_current    = ( $member_id == $user_id );

            $owner_index = $member_index if $is_owner;

            push @enhanced_members,
              {
                %$member_ref,
                flags      => $flags,
                is_owner   => $is_owner ? 1 : 0,
                is_current => $is_current ? 1 : 0
              };

            $member_index++;
        }
    }

    # Build user data
    my $user_data = {
        node_id   => $user_id,
        title     => $user->title,
        is_guest  => $user->is_guest ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin ? 1 : 0
    };

    # Fetch initial weblog entries (first 3 for page load)
    my $weblog_entries = $self->_fetch_weblog_entries($node->node_id, $user, 3, 0);
    my $has_more_weblog = scalar(@$weblog_entries) >= 3 ? 1 : 0;

    # If we got exactly 3, check if there are actually more
    if ($has_more_weblog) {
        my $check_more = $self->DB->sqlSelect(
            'to_node',
            'weblog',
            "weblog_id = " . $node->node_id . " AND removedby_user = 0",
            "LIMIT 1 OFFSET 3"
        );
        $has_more_weblog = $check_more ? 1 : 0;
    }

    # Determine weblog removal permissions
    # Admins and usergroup owners can remove entries
    my $can_remove_weblog = $user->is_admin ? 1 : 0;
    if (!$can_remove_weblog && $owner_id && $user_id == $owner_id) {
        $can_remove_weblog = 1;
    }

    # Determine weblog posting permissions
    # User can post if they're approved (admin, or member of the group)
    my $can_post_weblog = 0;
    unless ($user->is_guest) {
        $can_post_weblog = Everything::isApproved($user->NODEDATA, $node->NODEDATA) ? 1 : 0;
    }

    # Determine if user can edit group members (admin or owner)
    my $can_edit_members = 0;
    if ($user->is_admin) {
        $can_edit_members = 1;
    } elsif ($owner_id && $user_id == $owner_id) {
        $can_edit_members = 1;
    }

    # Build contentData for React
    my $content_data = {
        type      => 'usergroup',
        usergroup => {
            %$usergroup_data,
            group => \@enhanced_members,    # Replace with enhanced member data
            owner => $owner_data
        },
        user                => $user_data,
        is_in_group         => $is_in_group ? 1 : 0,
        discussions_node_id => $discussions_node_id,
        weblog_setting      => $weblog_setting,
        message_count       => $message_count || 0,
        owner_index         => $owner_index,
        can_bulk_edit       => $can_bulk_edit ? 1 : 0,
        can_edit_members    => $can_edit_members,
        simple_editor_id    => $simple_editor_id,
        weblog => {
            entries         => $weblog_entries,
            has_more        => $has_more_weblog,
            can_remove      => $can_remove_weblog,
            can_post        => $can_post_weblog,
            weblog_id       => int($node->node_id)
        }
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html =
      $self->layout( '/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node );
    return [ $self->HTTP_OK, $html ];
}

sub edit {
    my ($self, $REQUEST, $node) = @_;

    # Usergroup edit uses the standard basicedit form (gods-only)
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable();
1;

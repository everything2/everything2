package Everything::Controller::user;

use Moose;
extends 'Everything::Controller';

## no critic (ProhibitConstantPragma)
use constant SECONDS_PER_YEAR => 365 * 24 * 60 * 60;
use constant CACHE_DURATION   => 3600;    # 1 hour
## use critic

# Controller for user nodes (homenode display and edit)
# Migrated from Everything::Delegation::htmlpage::user_display_page
# and Everything::Delegation::htmlpage::classic_user_edit_page

sub display {
    my ( $self, $REQUEST, $node ) = @_;

    my $user      = $REQUEST->user;
    my $user_id   = $user->node_id;
    my $is_guest  = $user->is_guest;
    my $is_own    = !$is_guest && ( $user_id == $node->node_id );
    my $is_editor = $user->is_editor;
    my $is_admin  = $user->is_admin;

    # Run setupuservars logic (cached numwriteups update, weblog permissions)
    $self->_setup_user_vars( $node, $user, $is_own ) unless $is_guest;

    # Build user profile data using Node methods
    my $profile = $node->json_display($user);

    # Add user image URL if exists
    if ( $node->NODEDATA->{imgsrc} ) {
        $profile->{imgsrc} = $node->NODEDATA->{imgsrc};
    }

    # Add realname and email (only visible to self or admin)
    if ( $is_own || $is_admin ) {
        $profile->{realname} = $node->NODEDATA->{realname} || '';
        $profile->{email}    = $node->NODEDATA->{email} || '';
    }

    # Add doctext (bio) - always included for display
    $profile->{doctext} = $node->NODEDATA->{doctext} || '';

    # Add last seen visibility flag
    my $node_settings = $node->VARS || {};
    $profile->{hidelastseen} = $node_settings->{hidelastseen} ? 1 : 0;

    # Check if viewing user is ignoring this user's messages
    my $is_ignored = 0;
    unless ($is_guest) {
        $is_ignored = $self->DB->sqlSelect(
            'ignore_node', 'messageignore',
            'messageignore_id=' . $node->node_id . " and ignore_node=$user_id"
        ) ? 1 : 0;
    }

    # Get usergroup memberships
    my @groups;
    foreach my $group ( @{ $node->usergroup_memberships || [] } ) {
        push @groups, $group->json_reference;
    }
    $profile->{groups} = \@groups;

    # Get categories maintained by this user (excludes public/guest_user categories)
    my @categories;
    foreach my $cat ( @{ $node->maintained_categories || [] } ) {
        push @categories, $cat->json_reference;
    }
    $profile->{categories} = \@categories;

    # Get registration entries (profile data like location, etc.)
    # Only shown to logged-in users who are not ignoring
    my @registrations;
    if ( !$is_guest && !$is_ignored ) {
        my $csr = $self->DB->sqlSelectMany(
            '*', 'registration',
            'from_user=' . $node->NODEDATA->{user_id} . ' && in_user_profile=1'
        );
        if ($csr) {
            while ( my $ref = $csr->fetchrow_hashref() ) {
                my $registry_node = $self->APP->node_by_id( $ref->{for_registry} );
                next unless $registry_node;
                push @registrations, {
                    registry => $registry_node->json_reference,
                    data     => $ref->{data} || '',
                    comments => $ref->{comments} || ''
                };
            }
        }
    }
    $profile->{registrations} = \@registrations;

    # Get message count from this user (for "msgs from me" link)
    my $message_count = 0;
    unless ( $is_guest || $REQUEST->user->VARS->{hidemsgyou} ) {
        $message_count = $self->DB->sqlSelect(
            'count(*)', 'message',
            "for_user=$user_id and author_user=" . $node->node_id
        ) || 0;
    }

    # Get last noded writeup via direct database query (not cached VARS)
    # This ensures we always show the actual most recent writeup
    my $lastnoded;
    unless ( $node_settings->{hidelastnoded} ) {
        # Build exclusion clause for maintenance nodes
        my $maint_nodes = $self->APP->getMaintenanceNodesForUser( $node->NODEDATA );
        my $maint_str   = '';
        if ( $maint_nodes && @$maint_nodes ) {
            $maint_str = ' AND node_id NOT IN (' . join( ', ', @$maint_nodes ) . ')';
        }

        # Query for most recent published writeup
        my $lastnoded_id = $self->DB->sqlSelect(
            'node_id',
            'node JOIN writeup ON node_id=writeup_id',
            'author_user=' . $node->node_id . $maint_str,
            'ORDER BY publishtime DESC LIMIT 1'
        );

        if ($lastnoded_id) {
            my $lastnoded_node = $self->APP->node_by_id($lastnoded_id);
            if ($lastnoded_node) {
                my $parent = $self->APP->node_by_id( $lastnoded_node->NODEDATA->{parent_e2node} );
                $lastnoded = {
                    writeup => $lastnoded_node->json_reference,
                    e2node  => $parent ? $parent->json_reference : undef
                };
            }
        }
    }

    # Get recent writeup count (if enabled)
    my $recent_writeup_count;
    if ( $node_settings->{showrecentwucount} ) {
        $recent_writeup_count = $self->_get_writeups_since_last_year( $node->node_id );
    }

    # Get C!s spent count
    my $cools_spent = $self->DB->sqlSelect(
        'count(*)', 'coolwriteups',
        'cooledby_user=' . $node->node_id
    ) || 0;

    # Build viewing user data
    my $viewer_data = {
        node_id   => $user_id,
        title     => $user->title,
        is_guest  => $is_guest ? 1 : 0,
        is_editor => $is_editor ? 1 : 0,
        is_admin  => $is_admin ? 1 : 0,
        is_chanop => $user->is_chanop ? 1 : 0
    };

    # Check if user is "infected" (primitive bot detection flag)
    # Only visible to editors
    my $is_infected = 0;
    if ($is_editor) {
        my $patient_vars = $node->VARS || {};
        $is_infected = ( $patient_vars->{infected} && $patient_vars->{infected} == 1 ) ? 1 : 0;
    }

    # Add admin-only user info (IP, browser) for editors/chanops
    if ( $is_editor || $user->is_chanop ) {
        my $target_vars = $node->VARS || {};
        $profile->{lastip}  = $target_vars->{ipaddy} if $target_vars->{ipaddy};
        $profile->{browser} = $target_vars->{browser} if $target_vars->{browser};
        $profile->{infected} = $is_infected if $is_infected;

        # Check if user's IP is blacklisted
        if ($target_vars->{ipaddy}) {
            $profile->{ip_blacklisted} = $self->APP->is_ip_blacklisted($target_vars->{ipaddy}) ? 1 : 0;
        }
    }

    # Build contentData for React
    my $content_data = {
        type          => 'user',
        user          => $profile,
        viewer        => $viewer_data,
        is_own        => $is_own ? 1 : 0,
        is_ignored    => $is_ignored,
        message_count => $message_count,
        lastnoded     => $lastnoded,
        cools_spent   => $cools_spent,
        is_infected   => $is_infected
    };

    $content_data->{recent_writeup_count} = $recent_writeup_count
        if defined $recent_writeup_count;

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
    my $html = $self->layout( '/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node );
    return [ $self->HTTP_OK, $html ];
}

sub edit {
    my ( $self, $REQUEST, $node ) = @_;

    my $user    = $REQUEST->user;
    my $user_id = $user->node_id;

    # Only allow editing own profile (or admin)
    unless ( $user_id == $node->node_id || $user->is_admin ) {
        return $self->display( $REQUEST, $node );
    }

    # Get profile data for editing
    my $profile = $node->json_display($user);

    # Add editable fields
    $profile->{imgsrc}   = $node->NODEDATA->{imgsrc} || '';
    $profile->{realname} = $node->NODEDATA->{realname} || '';
    $profile->{email}    = $node->NODEDATA->{email} || '';
    $profile->{doctext}  = $node->NODEDATA->{doctext} || '';

    # Check if user can have an image
    # Admins can upload for any user, so always allow for admins
    my $can_have_image = 0;
    if ( $user->is_admin ) {
        $can_have_image = 1;
    }
    else {
        my $users_with_image = $self->DB->getNode( 'users with image', 'nodegroup' );
        if ( $users_with_image && Everything::isApproved( $node->NODEDATA, $users_with_image ) ) {
            $can_have_image = 1;
        }
        elsif ( $self->APP->getLevel( $node->NODEDATA ) >= 1 ) {
            $can_have_image = 1;
        }
    }

    # Build viewer data
    my $viewer_data = {
        node_id   => $user_id,
        title     => $user->title,
        is_guest  => $user->is_guest ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin ? 1 : 0
    };

    # Build contentData for React
    my $content_data = {
        type           => 'user_edit',
        user           => $profile,
        viewer         => $viewer_data,
        can_have_image => $can_have_image ? 1 : 0
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

    # Use react_page layout
    my $html = $self->layout( '/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node );
    return [ $self->HTTP_OK, $html ];
}

sub _get_writeups_since_last_year {
    my ( $self, $user_id ) = @_;

    my $one_year_ago = time() - SECONDS_PER_YEAR;
    my $formatted    = $self->APP->convertEpochToDate($one_year_ago);

    my $count = $self->DB->sqlSelect(
        'count(*)', 'node n, writeup w',
        "n.node_id = w.writeup_id AND n.author_user = $user_id AND n.createtime > '$formatted'"
    );

    return $count || 0;
}

# Migrated from htmlcode::setupuservars
# Updates cached numwriteups count (hourly) and weblog permissions
sub _setup_user_vars {
    my ( $self, $node, $user, $is_own ) = @_;

    my $settings = $node->VARS || {};
    my $now      = time();

    # Update numwriteups if cache is stale
    unless ( $settings->{nwriteupsupdate} && $now - $settings->{nwriteupsupdate} < CACHE_DURATION ) {
        $settings->{nwriteupsupdate} = $now;

        my $writeup_type = $self->DB->getType('writeup');
        my $node_id      = $node->node_id;

        my $wherestr = 'type_nodetype=' . $writeup_type->{node_id} . " AND author_user=$node_id";

        # Exclude maintenance nodes
        my $maint_nodes = $self->APP->getMaintenanceNodesForUser($node_id) || [];
        if ( @$maint_nodes ) {
            $wherestr .= ' AND node_id NOT IN (' . join( ', ', @$maint_nodes ) . ')';
        }

        my $writeups = $self->DB->sqlSelect( 'count(*)', 'node', $wherestr );
        $settings->{numwriteups} = int( $writeups || 0 );

        # Persist updated settings
        $node->set_vars($settings);
    }

    # Update can_weblog permissions if viewing own profile
    if ($is_own) {
        my $user_data = $user->NODEDATA;
        $user_data->{numwriteups} = $settings->{numwriteups} || 0;
        $self->DB->updateNode( $user_data, $user_data );

        # Update weblog permissions
        delete $user->VARS->{can_weblog};
        my $webloggables = $self->DB->getNode( 'webloggables', 'setting' );
        if ($webloggables) {
            my $wls    = $self->APP->getVars($webloggables);
            my @canwl  = ();
            foreach my $wl_id ( keys %{ $wls || {} } ) {
                my $wl_node = $self->APP->node_by_id($wl_id);
                next unless $wl_node;
                if ( $user->is_admin || $self->DB->isApproved( $user->NODEDATA, $wl_node->NODEDATA ) ) {
                    push @canwl, $wl_id;
                }
            }
            $user->VARS->{can_weblog} = join ',', sort { $a <=> $b } @canwl;
        }
    }

    return;
}

__PACKAGE__->meta->make_immutable();
1;

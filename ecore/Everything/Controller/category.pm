package Everything::Controller::category;

use Moose;
extends 'Everything::Controller';

# Controller for category nodes
# Handles display and edit modes for categories

sub display {
    my ( $self, $REQUEST, $node ) = @_;

    my $user = $REQUEST->user;
    my $DB   = $self->DB;
    my $APP  = $self->APP;

    # Get category metadata
    my $author      = $APP->node_by_id( $node->NODEDATA->{author_user} );
    my $author_name = $author ? $author->title : 'Unknown';
    my $author_type = $author ? ($author->NODEDATA->{type}{title} || '') : '';
    my $guest_user_id = $self->CONF->guest_user;
    my $is_public   = $node->NODEDATA->{author_user} == $guest_user_id ? 1 : 0;

    # Check if user can edit this category
    my $can_edit = 0;
    unless ( $user->is_guest ) {
        if ( $user->is_admin ) {
            $can_edit = 1;
        }
        elsif ( $node->NODEDATA->{author_user} == $user->node_id ) {
            # User owns this category
            $can_edit = 1;
        }
        elsif ($is_public) {
            # Public category - any logged-in user can edit
            $can_edit = 1;
        }
        else {
            # Check if user is in the usergroup that maintains this category
            foreach my $ug ( @{ $user->usergroup_memberships || [] } ) {
                if ( $ug->node_id == $node->NODEDATA->{author_user} ) {
                    $can_edit = 1;
                    last;
                }
            }
        }
    }

    # Get category members (nodes linked to this category)
    my $category_linktype = $DB->getNode( 'category', 'linktype' );
    my $linktype_id = $category_linktype->{node_id};

    my @members;
    my $csr = $DB->sqlSelectMany(
        'to_node, food',
        'links',
        "from_node = " . $node->node_id . " AND linktype = $linktype_id",
        'ORDER BY food, to_node'
    );

    if ($csr) {
        while ( my $row = $csr->fetchrow_hashref ) {
            my $member_node = $APP->node_by_id( $row->{to_node} );
            next unless $member_node;

            # Get author info for the member
            my $member_author = $APP->node_by_id( $member_node->NODEDATA->{author_user} );

            push @members, {
                node_id     => $member_node->node_id,
                title       => $member_node->title,
                type        => $member_node->NODEDATA->{type}{title} || $member_node->type_title,
                author      => $member_author ? $member_author->title : 'Unknown',
                author_id   => $member_node->NODEDATA->{author_user},
                food        => $row->{food} || 0
            };
        }
    }

    # Parse the description text through the link parser
    my $doctext = $node->NODEDATA->{doctext} || '';
    my $parsed_description = $APP->parseLinks( $doctext, $user->NODEDATA, $node->NODEDATA );

    # Build viewer data
    my $viewer_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin ? 1 : 0
    };

    # Convert createtime to Unix timestamp for React TimeDistance component
    my $createtime_epoch = $APP->convertDateToEpoch($node->NODEDATA->{createtime});

    # Build contentData for React
    my $content_data = {
        type        => 'category',
        category    => {
            node_id     => $node->node_id,
            title       => $node->title,
            description => $parsed_description,
            raw_description => $doctext,
            author      => $author_name,
            author_id   => $node->NODEDATA->{author_user},
            author_type => $author_type,
            is_public   => $is_public,
            createtime  => $createtime_epoch,
            member_count => scalar(@members)
        },
        members     => \@members,
        can_edit    => $can_edit ? 1 : 0,
        viewer      => $viewer_data
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
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

sub edit {
    my ( $self, $REQUEST, $node ) = @_;

    my $user = $REQUEST->user;
    my $DB   = $self->DB;
    my $APP  = $self->APP;

    # Check permissions
    my $guest_user_id = $self->CONF->guest_user;
    my $is_public = $node->NODEDATA->{author_user} == $guest_user_id ? 1 : 0;

    my $can_edit = 0;
    my $is_owner = 0;
    unless ( $user->is_guest ) {
        if ( $user->is_admin ) {
            $can_edit = 1;
        }
        elsif ( $node->NODEDATA->{author_user} == $user->node_id ) {
            $can_edit = 1;
            $is_owner = 1;
        }
        elsif ($is_public) {
            $can_edit = 1;
        }
        else {
            foreach my $ug ( @{ $user->usergroup_memberships || [] } ) {
                if ( $ug->node_id == $node->NODEDATA->{author_user} ) {
                    $can_edit = 1;
                    $is_owner = 1;  # Usergroup member counts as owner
                    last;
                }
            }
        }
    }

    # If user can't edit, redirect to display
    unless ($can_edit) {
        return $self->display( $REQUEST, $node );
    }

    # Get author info
    my $author      = $APP->node_by_id( $node->NODEDATA->{author_user} );
    my $author_name = $author ? $author->title : 'Unknown';
    my $author_type = $author ? ($author->NODEDATA->{type}{title} || '') : '';

    # Determine permissions for meta editing and member management
    # Editors can edit meta (title/owner) on any category
    my $can_edit_meta = $user->is_editor ? 1 : 0;

    # Editors can manage members on any category
    # Owners can manage members on non-public categories
    my $can_manage_members = 0;
    if ($user->is_editor) {
        $can_manage_members = 1;
    }
    elsif (!$is_public && $is_owner) {
        $can_manage_members = 1;
    }

    # Get category members for management UI
    my @members;
    my $category_linktype = $DB->getNode( 'category', 'linktype' );
    my $linktype_id = $category_linktype->{node_id};

    my $csr = $DB->sqlSelectMany(
        'to_node, food',
        'links',
        "from_node = " . $node->node_id . " AND linktype = $linktype_id",
        'ORDER BY food, to_node'
    );

    if ($csr) {
        while ( my $row = $csr->fetchrow_hashref ) {
            my $member_node = $APP->node_by_id( $row->{to_node} );
            next unless $member_node;

            my $member_author = $APP->node_by_id( $member_node->NODEDATA->{author_user} );

            push @members, {
                node_id     => $member_node->node_id,
                title       => $member_node->title,
                type        => $member_node->NODEDATA->{type}{title} || $member_node->type_title,
                author      => $member_author ? $member_author->title : 'Unknown',
                author_id   => $member_node->NODEDATA->{author_user},
                food        => $row->{food} || 0
            };
        }
    }

    # Build viewer data
    my $viewer_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin ? 1 : 0
    };

    # Convert createtime to Unix timestamp for React TimeDistance component
    my $createtime_epoch = $APP->convertDateToEpoch($node->NODEDATA->{createtime});

    # Build contentData for React edit mode
    my $content_data = {
        type        => 'category_edit',
        category    => {
            node_id     => $node->node_id,
            title       => $node->title,
            description => $node->NODEDATA->{doctext} || '',
            author      => $author_name,
            author_id   => $node->NODEDATA->{author_user},
            author_type => $author_type,
            is_public   => $is_public,
            createtime  => $createtime_epoch
        },
        members          => \@members,
        can_edit_meta    => $can_edit_meta,
        can_manage_members => $can_manage_members,
        guest_user_id    => $guest_user_id,
        viewer           => $viewer_data
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
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

__PACKAGE__->meta->make_immutable;
1;

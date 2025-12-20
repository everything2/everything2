package Everything::Controller::usergroup;

use Moose;
extends 'Everything::Controller';

# Controller for usergroup nodes
# Migrated from Everything::Delegation::htmlpage::usergroup_display_page

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
    if ( $user->is_god ) {
        my $weblog_node = $self->DB->getNode( 'webloggables', 'setting' );
        if ($weblog_node) {
            my $vars = $self->APP->getVars($weblog_node);
            $weblog_setting = $vars->{ $node->node_id } if $vars;
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
        is_god    => $user->is_god ? 1 : 0,
        is_admin  => $user->is_admin ? 1 : 0
    };

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
        owner_index         => $owner_index
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

__PACKAGE__->meta->make_immutable();
1;

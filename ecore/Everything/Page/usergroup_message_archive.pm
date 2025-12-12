package Everything::Page::usergroup_message_archive;

use Moose;
extends 'Everything::Page';

use Everything qw(getId getNode getNodeById getVars setVars);
use Everything::HTML qw(encodeHTML parseLinks);

=head1 Everything::Page::usergroup_message_archive

React page for Usergroup Message Archive - view archived messages sent to usergroups.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $NODE  = $REQUEST->node;
    my $VARS  = $APP->getVars( $USER->NODEDATA );

    my $userid = getId( $USER->NODEDATA );
    my $is_admin = $APP->isAdmin( $USER->NODEDATA );

    # Guest check
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type     => 'usergroup_message_archive',
            is_guest => 1,
            message  => 'You must login to use this feature.'
        };
    }

    # Get groups that allow message archiving
    my $ks = $APP->getNodesWithParameter('allow_message_archive');
    my @archive_groups = ();
    foreach my $ug_id ( @$ks ) {
        my $ug = getNodeById( $ug_id );
        next unless $ug;
        push @archive_groups, {
            node_id => $ug->{node_id},
            title   => $ug->{title}
        };
    }

    # Check if viewing a specific group
    my $viewgroup = $query->param('viewgroup');
    unless ( $viewgroup ) {
        return {
            type           => 'usergroup_message_archive',
            is_guest       => 0,
            is_admin       => $is_admin,
            archive_groups => \@archive_groups,
            node_id        => $NODE->NODEDATA->{node_id}
        };
    }

    my $UG = getNode( $viewgroup, 'usergroup' );
    unless ( $UG ) {
        return {
            type           => 'usergroup_message_archive',
            is_guest       => 0,
            is_admin       => $is_admin,
            archive_groups => \@archive_groups,
            node_id        => $NODE->NODEDATA->{node_id},
            error          => 'There is no such usergroup.'
        };
    }

    # Check membership
    unless ( Everything::isApproved( $USER->NODEDATA, $UG ) ) {
        return {
            type           => 'usergroup_message_archive',
            is_guest       => 0,
            is_admin       => $is_admin,
            archive_groups => \@archive_groups,
            node_id        => $NODE->NODEDATA->{node_id},
            selected_group => {
                node_id => $UG->{node_id},
                title   => $UG->{title}
            },
            error          => "You aren't a member of this group, so you can't view the group's messages."
        };
    }

    # Check if archiving is allowed
    unless ( $APP->getParameter( $UG, "allow_message_archive" ) ) {
        return {
            type           => 'usergroup_message_archive',
            is_guest       => 0,
            is_admin       => $is_admin,
            archive_groups => \@archive_groups,
            node_id        => $NODE->NODEDATA->{node_id},
            selected_group => {
                node_id => $UG->{node_id},
                title   => $UG->{title}
            },
            error          => "This group doesn't archive messages."
        };
    }

    my $ugID = getId( $UG );

    # Handle message copy to self
    my $copied_count = 0;
    my $reset_time = $VARS->{ugma_resettime} ? 1 : 0;

    foreach my $param ( $query->param ) {
        if ( $param =~ /^cpgroupmsg_(\d+)$/ ) {
            my $msg_id = $1;
            my $MSG = $DB->sqlSelectHashref( '*', 'message', "message_id=$msg_id" );
            next unless $MSG;

            # Verify message belongs to this group archive
            next unless ( $MSG->{for_user} == $ugID ) && ( $MSG->{for_usergroup} == $ugID );

            $copied_count++;
            delete $MSG->{message_id};
            delete $MSG->{tstamp} if $reset_time;
            $MSG->{for_user} = $userid;
            $DB->sqlInsert( 'message', $MSG );
        }
    }

    # Handle reset time preference toggle
    if ( defined $query->param('ugma_resettime') ) {
        $VARS->{ugma_resettime} = $query->param('ugma_resettime') ? 1 : 0;
        setVars( $USER->NODEDATA, $VARS );
        $reset_time = $VARS->{ugma_resettime};
    }

    # Get message count and pagination
    my $LIMITS = "for_user=$ugID AND for_usergroup=$ugID";
    my ($numMsg) = $DB->sqlSelect( 'COUNT(*)', 'message', $LIMITS );

    my $max_show = int( $query->param('max_show') || 25 );
    my $start_default = $numMsg - $max_show;
    $start_default = 0 if $start_default < 0;

    my $show_start = defined $query->param('startnum')
        ? int( $query->param('startnum') || 0 )
        : $start_default;

    $show_start = $start_default if $show_start > $start_default;
    $show_start = 0 if $show_start < 0;

    # Get messages
    my $csr = $DB->sqlSelectMany(
        '*',
        'message',
        $LIMITS,
        "ORDER BY tstamp,message_id LIMIT $show_start,$max_show"
    );

    my @messages = ();
    my $msg_count = $show_start;

    while ( my $msg_row = $csr->fetchrow_hashref ) {
        $msg_count++;

        my $author_node = $msg_row->{author_user} ? getNodeById( $msg_row->{author_user} ) : undef;
        my $author_name = $author_node ? $author_node->{title} : '';
        $author_name =~ tr/ /_/;

        # Process message text
        my $text = $msg_row->{msgtext} || '';
        $text =~ s/</&lt;/g;
        $text =~ s/>/&gt;/g;
        $text =~ s/\s+\\n\s+/<br \/>/g;
        $text = parseLinks( $text );
        $text =~ s/\[/&#91;/g;

        push @messages, {
            message_id   => $msg_row->{message_id},
            number       => $msg_count,
            author_id    => $author_node ? $author_node->{node_id} : 0,
            author_title => encodeHTML( $author_name ),
            timestamp    => $msg_row->{tstamp},
            text         => $text
        };
    }
    $csr->finish;

    my $num_show = scalar( @messages );

    return {
        type           => 'usergroup_message_archive',
        is_guest       => 0,
        is_admin       => $is_admin,
        archive_groups => \@archive_groups,
        node_id        => $NODE->NODEDATA->{node_id},
        selected_group => {
            node_id => $UG->{node_id},
            title   => $UG->{title}
        },
        messages       => \@messages,
        total_messages => $numMsg,
        show_start     => $show_start,
        max_show       => $max_show,
        num_show       => $num_show,
        copied_count   => $copied_count,
        reset_time     => $reset_time
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

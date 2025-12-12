package Everything::Page::usergroup_discussions;

use Moose;
extends 'Everything::Page';

use Everything qw(getId getNodeById getType);

=head1 Everything::Page::usergroup_discussions

React page for Usergroup Discussions - view and create discussions for usergroups.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $NODE  = $REQUEST->node;

    my $uid = getId( $USER->NODEDATA );

    # Guest check
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type     => 'usergroup_discussions',
            is_guest => 1,
            message  => "If you logged in, you would be able to strike up long-winded conversations with your buddies"
        };
    }

    # Get all usergroups
    my $csr = $DB->sqlSelectMany( "node_id", "node", "type_nodetype=16 ORDER BY node_id" );
    my @ug_ids = ();
    while ( my $row = $csr->fetchrow_hashref ) {
        push @ug_ids, $row->{node_id};
    }
    $csr->finish;

    # Excluded usergroups (e2gods, %%)
    my %exclude_ug_ids = ( 829913 => 1, 1175790 => 1 );

    # Find user's usergroups
    my @thisnoder_ug_ids = ();
    foreach my $ug_id ( @ug_ids ) {
        my $ug = getNodeById( $ug_id );
        next unless $ug && $ug->{group};
        my $ids = $ug->{group};

        my $is_member = 0;
        foreach my $member_id ( @$ids ) {
            if ( $member_id == $uid ) {
                $is_member = 1;
                last;
            }
        }

        if ( $is_member ) {
            push @thisnoder_ug_ids, $ug_id unless $exclude_ug_ids{$ug_id};

            # If admin (gods=114), also add Content Editors (923653)
            if ( $ug_id == 114 ) {
                push @thisnoder_ug_ids, 923653;
            }
        }
    }

    # No usergroups
    unless ( @thisnoder_ug_ids ) {
        return {
            type          => 'usergroup_discussions',
            is_guest      => 0,
            no_usergroups => 1,
            message       => "You have no usergroups! Find some friends first, and then start a discussion with them."
        };
    }

    # Build usergroup list for display
    my @usergroups = ();
    foreach my $ug_id ( @thisnoder_ug_ids ) {
        my $ug = getNodeById( $ug_id );
        next unless $ug;
        push @usergroups, {
            node_id => $ug_id,
            title   => $ug->{title}
        };
    }

    my $show_ug = int( $query->param('show_ug') || 0 );

    # Check for unauthorized usergroup access
    if ( $show_ug ) {
        my $is_valid = 0;
        foreach my $ug_id ( @thisnoder_ug_ids ) {
            if ( $ug_id == $show_ug ) {
                $is_valid = 1;
                last;
            }
        }
        unless ( $is_valid ) {
            return {
                type               => 'usergroup_discussions',
                is_guest           => 0,
                usergroups         => \@usergroups,
                selected_usergroup => $show_ug,
                access_denied      => 1,
                message            => "You are not a member of the selected usergroup."
            };
        }
    }

    # Build where clause for discussions
    my $wherestr = '';
    if ( $show_ug ) {
        $wherestr = "restricted=$show_ug";
    } else {
        my $id_list = join( ', ', @thisnoder_ug_ids );
        $wherestr = "restricted in ($id_list)";
    }

    # Get discussions
    $csr = $DB->sqlSelectMany(
        "root_debatecomment",
        "debatecomment",
        $wherestr,
        "GROUP BY root_debatecomment"
    );

    my @nodes = ();
    while ( my $temprow = $csr->fetchrow_hashref ) {
        my $N = getNodeById( $temprow->{root_debatecomment} );
        next unless $N;

        my $latest_id = $DB->sqlSelect(
            "MAX(debatecomment_id)",
            "debatecomment",
            "root_debatecomment=$N->{node_id}"
        );
        my $latest = getNodeById( $latest_id );
        next unless $latest;

        my $latesttime = $latest->{createtime};
        my $latesttime_e = $APP->convertDateToEpoch( $latesttime );

        push @nodes, {
            node       => $N,
            latest     => $latest,
            latesttime => $latesttime_e
        };
    }
    $csr->finish;

    # Sort by latest time descending
    @nodes = sort { $b->{latesttime} <=> $a->{latesttime} } @nodes;

    # Pagination
    my $offset     = int( $query->param("offset") || 0 );
    my $limit      = 50;
    my $totalnodes = scalar( @nodes );
    my $nodesleft  = $totalnodes - $offset;
    my $thispage   = ( $limit < $nodesleft ? $limit : $nodesleft );

    $thispage = 0 if $thispage < 0;

    my @page_nodes = ();
    if ( $thispage > 0 ) {
        @page_nodes = @nodes[ $offset .. $offset + $thispage - 1 ];
    }

    # Build discussions data
    my @discussions = ();
    foreach my $nodestuff ( @page_nodes ) {
        my $n = $nodestuff->{node};
        my $latest = $nodestuff->{latest};

        my $user = getNodeById( $n->{author_user} );
        my $ug = getNodeById( $n->{restricted} );

        my $latestreadtime = $DB->sqlSelect(
            "dateread",
            "lastreaddebate",
            "user_id=$uid and debateroot_id=$n->{node_id}"
        );

        my $latesttime_e = $nodestuff->{latesttime};
        my $latestreadtime_e = 0;
        if ( $latestreadtime ) {
            $latestreadtime_e = $APP->convertDateToEpoch( $latestreadtime );
        }

        my $unread = ( $latestreadtime_e < $latesttime_e ) ? 1 : 0;

        my $replycount = $DB->sqlSelect(
            "COUNT(*)",
            "debatecomment",
            "root_debatecomment=$n->{node_id}"
        );
        $replycount-- if $replycount > 0;  # Don't count root

        push @discussions, {
            node_id      => $n->{node_id},
            title        => $n->{title},
            author_id    => $user ? $user->{node_id} : 0,
            author_title => $user ? $user->{title} : 'unknown',
            usergroup_id    => $ug ? $ug->{node_id} : 0,
            usergroup_title => $ug ? $ug->{title} : 'unknown',
            reply_count  => $replycount,
            unread       => $unread,
            last_updated => $latest->{createtime} || ''
        };
    }

    return {
        type               => 'usergroup_discussions',
        is_guest           => 0,
        usergroups         => \@usergroups,
        selected_usergroup => $show_ug,
        discussions        => \@discussions,
        total_discussions  => $totalnodes,
        offset             => $offset,
        limit              => $limit,
        node_id            => $NODE->NODEDATA->{node_id}
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

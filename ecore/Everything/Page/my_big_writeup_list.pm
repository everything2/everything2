package Everything::Page::my_big_writeup_list;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::my_big_writeup_list

React page for My Big Writeup List - displays comprehensive list of user's writeups.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Guest check
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type  => 'my_big_writeup_list',
            guest => 1
        };
    }

    my $is_admin = $APP->isAdmin( $USER->NODEDATA );
    my $is_editor = $APP->isEditor( $USER->NODEDATA );

    # Get target user (admins can search for other users)
    my $username = $query->param('usersearch') || $USER->title;
    my $target_user = $DB->getNode( $username, 'user' );

    # Invalid user
    unless ($target_user) {
        return {
            type     => 'my_big_writeup_list',
            error    => "User '$username' doesn't exist. Did you type their name correctly?",
            username => $username,
            is_admin => $is_admin ? 1 : 0
        };
    }

    # Special cases - bots that shouldn't be queried
    if ( $target_user->{title} eq 'EDB' ) {
        return {
            type     => 'my_big_writeup_list',
            error    => 'G r o w l !',
            username => $username,
            is_admin => $is_admin ? 1 : 0
        };
    }

    if ( $target_user->{title} eq 'Webster 1913' ) {
        return {
            type     => 'my_big_writeup_list',
            error    => 'Are you really looking for almost all the words in the English language?',
            username => $username,
            is_admin => $is_admin ? 1 : 0
        };
    }

    my $target_user_id = $target_user->{node_id};
    my $is_me          = ( $target_user_id == $USER->node_id );
    my $show_rep       = $is_me || $is_admin || $is_editor;

    # Get total writeup count
    my $writeup_type_id = $DB->getType('writeup')->{node_id};
    my $total_count     = $DB->sqlSelect(
        'COUNT(*)',
        'node',
        "author_user=$target_user_id AND type_nodetype=$writeup_type_id"
    );

    # No writeups
    unless ($total_count) {
        return {
            type         => 'my_big_writeup_list',
            username     => $target_user->{title},
            is_admin     => $is_admin ? 1 : 0,
            is_me        => $is_me ? 1 : 0,
            show_rep     => $show_rep ? 1 : 0,
            total_count  => 0,
            writeups     => [],
            order_by     => 'title ASC',
            raw_mode     => 0,
            delimiter    => '_'
        };
    }

    # Get sorting and formatting preferences
    my $order_by  = $query->param('orderby') || 'title ASC';
    my $raw_mode  = $query->param('raw') ? 1 : 0;
    my $delimiter = $query->param('delimiter') || '_';

    # Validate order_by to prevent SQL injection
    my %valid_orderings = (
        'title ASC'                                  => 1,
        'wrtype_writeuptype ASC,title ASC'           => 1,
        'cooled DESC,title ASC'                      => 1,
        'cooled DESC,node.reputation DESC,title ASC' => 1,
        'node.reputation DESC,title ASC'             => 1,
        'writeup.publishtime DESC'                   => 1,
        'writeup.publishtime ASC'                    => 1
    );

    $order_by = 'title ASC' unless exists $valid_orderings{$order_by};

    # Validate delimiter for raw mode
    if ( $raw_mode && length($delimiter) != 1 ) {
        return {
            type         => 'my_big_writeup_list',
            error        => "Delimiter must be exactly one character.",
            username     => $target_user->{title},
            is_admin     => $is_admin ? 1 : 0,
            is_me        => $is_me ? 1 : 0,
            show_rep     => $show_rep ? 1 : 0,
            total_count  => $total_count,
            writeups     => [],
            order_by     => $order_by,
            raw_mode     => $raw_mode,
            delimiter    => $delimiter
        };
    }

    # Fetch writeup data
    my $cursor = $DB->sqlSelectMany(
        'node.node_id, parent_e2node, title, cooled, reputation, publishtime, totalvotes',
        'node, writeup',
        "node.author_user=$target_user_id AND node.type_nodetype=$writeup_type_id AND writeup.writeup_id=node.node_id",
        "ORDER BY $order_by"
    );

    # Build list of writeup node_ids and collect writeup data
    my @writeup_node_ids;
    my @raw_writeups;
    while ( my $row = $cursor->fetchrow_hashref ) {
        push @writeup_node_ids, $row->{node_id};
        push @raw_writeups, $row;
    }

    # Get the set of writeups the current user has voted on (if not viewing own or not editor/admin)
    my %user_voted;
    if ( !$is_me && !$is_admin && !$is_editor && @writeup_node_ids ) {
        my $user_id = $USER->node_id;
        my $id_list = join( ',', @writeup_node_ids );
        my $voted_cursor = $DB->{dbh}->selectcol_arrayref(
            "SELECT vote_id FROM vote WHERE voter_user = $user_id AND vote_id IN ($id_list)"
        );
        %user_voted = map { $_ => 1 } @{$voted_cursor || []};
    }

    my @writeups;
    for my $row (@raw_writeups) {
        my $writeup_node_id = $row->{node_id};
        my $voted = $user_voted{$writeup_node_id} ? 1 : 0;

        # Reputation visible if: own writeups, editor/admin, OR user voted on this writeup
        my $can_see_rep = $show_rep || $voted;

        my $writeup_data = {
            parent_e2node => $row->{parent_e2node},
            title         => $row->{title},
            cooled        => $row->{cooled} || 0,
            publishtime   => $row->{publishtime},
            voted         => $voted
        };

        # Add reputation data for authorized viewers
        if ($can_see_rep) {
            my $total_votes = $row->{totalvotes} || 0;
            my $reputation = $row->{reputation} || 0;
            my $upvotes = int( ( $total_votes + $reputation ) / 2 );
            my $downvotes = int( ( $total_votes - $reputation ) / 2 );

            $writeup_data->{reputation}  = $reputation;
            $writeup_data->{total_votes} = $total_votes;
            $writeup_data->{upvotes}     = $upvotes;
            $writeup_data->{downvotes}   = $downvotes;
        }

        push @writeups, $writeup_data;
    }

    return {
        type         => 'my_big_writeup_list',
        username     => $target_user->{title},
        user_id      => $target_user_id,
        is_admin     => $is_admin ? 1 : 0,
        is_editor    => $is_editor ? 1 : 0,
        is_me        => $is_me ? 1 : 0,
        show_rep     => $show_rep ? 1 : 0,
        total_count  => $total_count,
        writeups     => \@writeups,
        order_by     => $order_by,
        raw_mode     => $raw_mode,
        delimiter    => $delimiter
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

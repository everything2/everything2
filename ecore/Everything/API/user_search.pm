package Everything::API::user_search;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes {
    return {
        '/' => 'search'
    };
}

sub search {
    my ( $self, $REQUEST ) = @_;

    my $query = $REQUEST->cgi;
    my $USER  = $REQUEST->user->NODEDATA;
    my $VARS  = $REQUEST->VARS;

    # Get parameters
    my $username = $query->param('username');
    unless ($username) {
        return [ $self->HTTP_BAD_REQUEST, { error => 'username parameter is required' } ];
    }

    # Clean up username
    $username = $self->APP->htmlScreen($username);

    # Look up the user
    my $search_user = $self->DB->getNode( $username, 'user' );
    unless ($search_user) {
        return [ $self->HTTP_OK, {
            error => 'User not found',
            username => $username,
            writeups => [],
            total => 0
        } ];
    }

    # Pagination
    my $page     = int( $query->param('page') || 1 );
    my $per_page = int( $query->param('per_page') || 50 );
    $per_page = 50 if $per_page > 100 || $per_page < 1;
    $page = 1 if $page < 1;
    my $offset = ( $page - 1 ) * $per_page;

    # Sort order - validate against allowed values
    my $orderby = $query->param('orderby') || 'publishtime_desc';
    my %allowed_orders = (
        'publishtime_desc' => 'writeup.publishtime DESC',
        'publishtime_asc'  => 'writeup.publishtime ASC',
        'title_asc'        => 'node.title ASC',
        'title_desc'       => 'node.title DESC',
        'reputation_desc'  => 'node.reputation DESC',
        'reputation_asc'   => 'node.reputation ASC',
        'type_asc'         => 'writeup.wrtype_writeuptype ASC',
        'type_desc'        => 'writeup.wrtype_writeuptype DESC',
        'hits_desc'        => 'node.hits DESC',
        'hits_asc'         => 'node.hits ASC',
        'cools_desc'       => 'writeup.cooled DESC',
        'cools_asc'        => 'writeup.cooled ASC',
        'random'           => 'RAND()'
    );

    my $sql_order = $allowed_orders{$orderby} || 'writeup.publishtime DESC';

    # Filter hidden writeups
    my $filter_hidden = int( $query->param('filter_hidden') || 0 );

    # Determine what the viewing user can see
    my $search_user_id  = $search_user->{node_id};
    my $viewing_user_id = $USER->{node_id};
    my $is_self         = ( $search_user_id == $viewing_user_id ) && ( $viewing_user_id != 0 );
    my $is_editor       = $self->APP->isEditor($USER);
    my $is_guest        = $self->APP->isGuest($USER);
    my $can_see_rep     = $is_self || $is_editor;
    my $can_see_hidden  = $can_see_rep;

    # Build writeup type ID
    my $writeup_type_id = $self->DB->getId( $self->DB->getType('writeup') );

    # Build filter clause
    my $filter_clause = '';

    # Only show published writeups (publishtime != 0) unless viewing own writeups
    # Users can see their own drafts, but not others' drafts
    unless ($is_self) {
        $filter_clause = "AND writeup.publishtime != '0000-00-00 00:00:00'";
    }

    if ( $can_see_hidden && $filter_hidden ) {
        if ( $filter_hidden == 1 ) {
            $filter_clause .= ' AND writeup.notnew = 0';    # Only unhidden
        }
        elsif ( $filter_hidden == 2 ) {
            $filter_clause .= ' AND writeup.notnew != 0';    # Only hidden
        }
    }

    # Get total count
    my $count_sql = qq|
        SELECT COUNT(*) AS total
        FROM node
        JOIN writeup ON writeup.writeup_id = node.node_id
        WHERE node.author_user = ?
        AND node.type_nodetype = ?
        $filter_clause
    |;

    my $count_result = $self->DB->{dbh}->selectrow_hashref( $count_sql, {}, $search_user_id, $writeup_type_id );
    my $total = $count_result->{total} || 0;

    # Get writeups
    my $vote_select = '';
    my $vote_join   = '';
    unless ($is_guest) {
        $vote_select = ', vote.weight AS user_vote';
        $vote_join   = "LEFT OUTER JOIN vote ON vote.voter_user = $viewing_user_id AND vote.vote_id = node.node_id";
    }

    my $note_select = '';
    if ($is_editor) {
        $note_select = ", (SELECT 1 FROM nodenote
            WHERE nodenote.noter_user != 0
            AND (nodenote.nodenote_nodeid = node.node_id
            OR nodenote.nodenote_nodeid = writeup.parent_e2node)
            LIMIT 1) AS has_note";
    }

    # Vote spread (upvotes/downvotes) - only for viewing your own writeups
    my $vote_spread_select = '';
    if ($is_self) {
        $vote_spread_select = qq{,
            (SELECT COUNT(*) FROM vote WHERE vote.vote_id = node.node_id AND vote.weight > 0) AS upvotes,
            (SELECT COUNT(*) FROM vote WHERE vote.vote_id = node.node_id AND vote.weight < 0) AS downvotes
        };
    }

    my $writeups_sql = qq|
        SELECT
            node.node_id,
            node.title,
            node.reputation,
            node.hits,
            writeup.parent_e2node,
            parent.title AS parent_title,
            writeup.cooled,
            writeup.notnew AS hidden,
            writeup.publishtime,
            type.title AS writeup_type
            $vote_select
            $note_select
            $vote_spread_select
        FROM node
        JOIN writeup ON writeup.writeup_id = node.node_id
        JOIN node AS type ON type.node_id = writeup.wrtype_writeuptype
        LEFT JOIN node AS parent ON parent.node_id = writeup.parent_e2node
        $vote_join
        WHERE node.author_user = ?
        AND node.type_nodetype = ?
        $filter_clause
        ORDER BY $sql_order, node.node_id ASC
        LIMIT ? OFFSET ?
    |;

    my $sth = $self->DB->{dbh}->prepare($writeups_sql);
    $sth->execute( $search_user_id, $writeup_type_id, $per_page, $offset );

    my @writeups;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $writeup = {
            node_id      => $row->{node_id},
            title        => $row->{title},
            parent_id    => $row->{parent_e2node},
            parent_title => $row->{parent_title} || '',
            writeup_type => $row->{writeup_type},
            cools        => $row->{cooled} || 0,
            publishtime  => $row->{publishtime},
            hits         => $row->{hits} || 0
        };

        # Only include hidden status for self/editors
        if ($can_see_rep) {
            $writeup->{hidden} = $row->{hidden} ? 1 : 0;
        }

        # Reputation visibility:
        # - Self/editors always see reputation
        # - Other users only see reputation if they've voted on the writeup
        if ($can_see_rep) {
            $writeup->{reputation} = $row->{reputation} || 0;
        } elsif ( !$is_guest && defined( $row->{user_vote} ) ) {
            # User has voted on this writeup, so they can see its reputation
            $writeup->{reputation} = $row->{reputation} || 0;
        }

        # Include vote for logged-in users viewing others' writeups
        if ( !$is_guest && !$is_self ) {
            $writeup->{user_vote} = defined( $row->{user_vote} ) ? int( $row->{user_vote} ) : undef;
        }

        # Include note indicator for editors
        if ($is_editor) {
            $writeup->{has_note} = $row->{has_note} ? 1 : 0;
        }

        # Include vote spread for self
        if ($is_self) {
            $writeup->{upvotes} = $row->{upvotes} || 0;
            $writeup->{downvotes} = $row->{downvotes} || 0;
        }

        push @writeups, $writeup;
    }

    # Calculate pagination info
    my $total_pages = int( ( $total + $per_page - 1 ) / $per_page );

    return [
        $self->HTTP_OK,
        {
            username    => $search_user->{title},
            user_id     => $search_user_id,
            writeups    => \@writeups,
            total       => $total,
            page        => $page,
            per_page    => $per_page,
            total_pages => $total_pages,
            orderby     => $orderby,
            can_see_rep => $can_see_rep ? 1 : 0,
            is_self     => $is_self ? 1 : 0,
            is_editor   => $is_editor ? 1 : 0
        }
    ];
}

__PACKAGE__->meta->make_immutable;

1;

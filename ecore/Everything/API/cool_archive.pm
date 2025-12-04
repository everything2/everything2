package Everything::API::cool_archive;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

=head1 NAME

Everything::API::cool_archive - Cool Archive browsing API

=head1 DESCRIPTION

Provides paginated access to the cool archive with filtering and sorting options.

=head1 ENDPOINTS

=head2 GET /api/cool_archive

Get paginated list of cooled writeups with filtering.

Query parameters:
- orderby: Sort order (default: 'tstamp DESC')
- useraction: 'cooled' or 'written' (default: 'cooled')
- cooluser: Username to filter by
- limit: Results per page (default: 50, max: 100)
- offset: Starting offset (default: 0)

=cut

sub routes {
    return {
        '/' => 'list_writeups'
    };
}

sub list_writeups {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get parameters
    my $orderby = $REQUEST->param('orderby') || 'tstamp DESC';
    my $useraction = $REQUEST->param('useraction') || 'cooled';
    my $cooluser = $REQUEST->param('cooluser') || '';
    my $limit = int($REQUEST->param('limit') || 50);
    my $offset = int($REQUEST->param('offset') || 0);

    # Sanity checks
    $limit = 50 if $limit < 1 || $limit > 100;
    $offset = 0 if $offset < 0;

    # Validate orderby
    my %valid_orders = (
        'tstamp DESC'                => 1,
        'tstamp ASC'                 => 1,
        'title ASC'                  => 1,
        'title DESC'                 => 1,
        'reputation DESC, title ASC' => 1,
        'reputation ASC, title ASC'  => 1,
        'cooled DESC, title ASC'     => 1,
    );
    $orderby = 'tstamp DESC' unless exists $valid_orders{$orderby};

    # Check if order requires user
    my $order_needs_user = ($orderby =~ /^(title|reputation|cooled)/);

    # If order needs user but none provided, return error
    if ($order_needs_user && !$cooluser) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'This sort option requires a username',
            writeups => [],
            has_more => 0
        }];
    }

    my ($sql, @bind_params);

    # Fetch one extra row to determine if there are more results
    my $fetch_limit = $limit + 1;

    if ($cooluser) {
        # User-specific query
        my $U = $DB->getNode($cooluser, 'user');
        unless ($U) {
            return [$self->HTTP_OK, {
                success => 0,
                error => "User '$cooluser' not found",
                writeups => [],
                has_more => 0
            }];
        }

        my $user_id = $U->{node_id};

        if ($useraction eq 'cooled') {
            # Writeups cooled by this user
            $sql = qq|
                SELECT
                    node.node_id, node.title, node.author_user, node.reputation,
                    writeup.writeup_id, writeup.parent_e2node, writeup.cooled,
                    cw.tstamp, cw.cooledby_user,
                    parent.title AS parent_title,
                    author.title AS author_name,
                    cooler.title AS cooled_by_name,
                    wutype.title AS writeup_type
                FROM
                    (SELECT * FROM coolwriteups WHERE cooledby_user = ?) cw
                INNER JOIN node
                    ON node.node_id = cw.coolwriteups_id
                INNER JOIN writeup
                    ON writeup.writeup_id = node.node_id
                LEFT JOIN node AS parent
                    ON parent.node_id = writeup.parent_e2node
                LEFT JOIN node AS author
                    ON author.node_id = node.author_user
                LEFT JOIN node AS cooler
                    ON cooler.node_id = cw.cooledby_user
                LEFT JOIN node AS wutype
                    ON wutype.node_id = writeup.wrtype_writeuptype
                ORDER BY $orderby
                LIMIT ? OFFSET ?
            |;
            @bind_params = ($user_id, $fetch_limit, $offset);

        } else {
            # Writeups written by this user that were cooled
            $sql = qq|
                SELECT
                    nd.node_id, nd.title, nd.author_user, nd.reputation,
                    writeup.writeup_id, writeup.parent_e2node, writeup.cooled,
                    coolwriteups.tstamp, coolwriteups.cooledby_user,
                    parent.title AS parent_title,
                    author.title AS author_name,
                    cooler.title AS cooled_by_name,
                    wutype.title AS writeup_type
                FROM
                    (SELECT * FROM node WHERE author_user = ?) nd
                INNER JOIN coolwriteups
                    ON coolwriteups.coolwriteups_id = nd.node_id
                INNER JOIN writeup
                    ON writeup.writeup_id = nd.node_id
                LEFT JOIN node AS parent
                    ON parent.node_id = writeup.parent_e2node
                LEFT JOIN node AS author
                    ON author.node_id = nd.author_user
                LEFT JOIN node AS cooler
                    ON cooler.node_id = coolwriteups.cooledby_user
                LEFT JOIN node AS wutype
                    ON wutype.node_id = writeup.wrtype_writeuptype
                WHERE writeup.cooled != 0
                ORDER BY $orderby
                LIMIT ? OFFSET ?
            |;
            @bind_params = ($user_id, $fetch_limit, $offset);
        }

    } else {
        # General query (sorted by tstamp only)
        # Use bigLimit for subquery to handle deleted writeups
        my $bigLimit = 10 * $fetch_limit;

        $sql = qq|
            SELECT
                node.node_id, node.title, node.author_user, node.reputation,
                writeup.writeup_id, writeup.parent_e2node, writeup.cooled,
                cw.tstamp, cw.cooledby_user,
                parent.title AS parent_title,
                author.title AS author_name,
                cooler.title AS cooled_by_name,
                wutype.title AS writeup_type
            FROM
                (SELECT * FROM coolwriteups ORDER BY $orderby LIMIT ? OFFSET ?) cw
            INNER JOIN writeup
                ON writeup.writeup_id = cw.coolwriteups_id
            INNER JOIN node
                ON node.node_id = cw.coolwriteups_id
            LEFT JOIN node AS parent
                ON parent.node_id = writeup.parent_e2node
            LEFT JOIN node AS author
                ON author.node_id = node.author_user
            LEFT JOIN node AS cooler
                ON cooler.node_id = cw.cooledby_user
            LEFT JOIN node AS wutype
                ON wutype.node_id = writeup.wrtype_writeuptype
        |;
        @bind_params = ($bigLimit, $offset);
    }

    my $rows = $DB->{dbh}->selectall_arrayref($sql, { Slice => {} }, @bind_params);

    # Check if we have more results
    my $has_more = 0;
    if (@$rows > $limit) {
        $has_more = 1;
        pop @$rows;  # Remove the extra row
    }

    # Transform to clean JSON structure
    my @writeups = map {
        {
            writeup_id => $_->{writeup_id},
            parent_node_id => $_->{parent_e2node},
            parent_title => $_->{parent_title} || 'Unknown',
            author_name => $_->{author_name} || 'Unknown',
            cooled_by_name => $_->{cooled_by_name} || 'Unknown',
            writeup_type => $_->{writeup_type},
            reputation => $_->{reputation} || 0,
            cooled_count => $_->{cooled} || 0,
            tstamp => $_->{tstamp}
        }
    } @$rows;

    return [$self->HTTP_OK, {
        success => 1,
        writeups => \@writeups,
        has_more => $has_more,
        offset => $offset,
        limit => $limit
    }];
}

__PACKAGE__->meta->make_immutable;

1;

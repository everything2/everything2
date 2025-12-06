package Everything::API::list_nodes;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::list_nodes - API for listing nodes by type

=head1 DESCRIPTION

Provides API endpoint for the List Nodes of Type tool.

=head1 METHODS

=head2 routes

Define API routes.

=cut

sub routes {
    return {
        "list" => "list"
    };
}

=head2 list($REQUEST)

Returns list of nodes for the specified node type with filtering and sorting.

GET /api/list_nodes/list?type_id=14&sort1=nameA&offset=0

=cut

sub list {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Security check - editors (includes admins) or developers
    unless ($USER->is_editor || $USER->is_developer) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Access denied'
        }];
    }

    my $is_admin = $USER->is_admin;
    my $is_editor = $USER->is_editor;

    # Get parameters
    my $type_id = $REQUEST->param('type_id');
    my $sort1 = $REQUEST->param('sort1') || '0';
    my $sort2 = $REQUEST->param('sort2') || '0';
    my $filter_user = $REQUEST->param('filter_user');
    my $filter_user_not = $REQUEST->param('filter_user_not') ? 1 : 0;
    my $offset = $REQUEST->param('offset') || 0;

    # Validate type_id
    unless ($type_id && $type_id =~ /^[1-9]\d*$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid type ID'
        }];
    }

    # Determine page size based on role
    my $page_size = $is_admin ? 100 : ($is_editor ? 75 : 60);

    # Build sort clause
    my %sort_map = (
        '0'       => '',
        'idA'     => 'node_id ASC',
        'idD'     => 'node_id DESC',
        'nameA'   => 'title ASC',
        'nameD'   => 'title DESC',
        'authorA' => 'author_user ASC',
        'authorD' => 'author_user DESC',
        'createA' => 'createtime ASC',
        'createD' => 'createtime DESC'
    );

    my @sort_parts;
    for my $sort_key ($sort1, $sort2) {
        next unless exists $sort_map{$sort_key};
        my $sort_sql = $sort_map{$sort_key};
        next unless $sort_sql;
        push @sort_parts, $sort_sql;
    }
    my $sort_clause = @sort_parts ? ' ORDER BY ' . join(', ', @sort_parts) : '';

    # Build filter clause
    my $filter_clause = '';
    my $filter_user_node;
    if ($filter_user) {
        $filter_user_node = $DB->getNode($filter_user, 'user')
                         || $DB->getNode($filter_user, 'usergroup');
        if ($filter_user_node) {
            my $op = $filter_user_not ? '!=' : '=';
            $filter_clause = " AND author_user $op " . $filter_user_node->{node_id};
        }
    }

    # Get total count
    my $count_sql = "SELECT COUNT(*) FROM node WHERE type_nodetype = ? $filter_clause";
    my $sth = $DB->{dbh}->prepare($count_sql);
    $sth->execute($type_id);
    my ($total) = $sth->fetchrow;

    # Get nodes
    my $query_sql = "SELECT node_id, title, author_user, createtime FROM node WHERE type_nodetype = ? $filter_clause $sort_clause LIMIT ?, ?";
    $sth = $DB->{dbh}->prepare($query_sql);
    $sth->execute($type_id, $offset, $page_size);

    my @nodes;
    while (my $row = $sth->fetchrow_hashref) {
        my $author = $DB->getNodeById($row->{author_user});

        push @nodes, {
            node_id => $row->{node_id},
            title => $row->{title},
            author_user => $row->{author_user},
            author_name => $author ? $author->{title} : 'unknown',
            createtime => $row->{createtime},
            can_edit => ($is_admin || ($row->{author_user} == $USER->{node_id})) ? 1 : 0
        };
    }

    # Get type info
    my $type_node = $DB->getNodeById($type_id);

    return [$self->HTTP_OK, {
        success => 1,
        nodes => \@nodes,
        total => $total,
        offset => $offset,
        page_size => $page_size,
        type_name => $type_node ? $type_node->{title} : 'unknown',
        type_id => $type_id,
        filter_user_name => $filter_user_node ? $filter_user_node->{title} : undef,
        filter_user_not => $filter_user_not ? 1 : 0
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>

=cut

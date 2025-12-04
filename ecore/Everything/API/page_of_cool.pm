package Everything::API::page_of_cool;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

=head1 NAME

Everything::API::page_of_cool - Page of Cool API

=head1 DESCRIPTION

Provides access to recently cooled nodes and editor endorsements.

=head1 ENDPOINTS

=head2 GET /api/page_of_cool/coolnodes

Get paginated list of recently cooled nodes.

Query parameters:
- offset: Starting offset (default: 0)
- limit: Results per page (default: 50, max: 100)

=head2 GET /api/page_of_cool/endorsements/:editor_id

Get list of nodes endorsed (C!'ed) by a specific editor.

=cut

sub routes {
    return {
        '/coolnodes' => 'list_coolnodes',
        '/endorsements/:editor_id' => 'get_endorsements'
    };
}

sub list_coolnodes {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $limit = int($REQUEST->param('limit') || 50);
    my $offset = int($REQUEST->param('offset') || 0);

    # Sanity checks
    $limit = 50 if $limit < 1 || $limit > 100;
    $offset = 0 if $offset < 0;

    # Get the coolnodes nodegroup
    my $coolnodes_group = $DB->getNode('coolnodes', 'nodegroup');
    return [$self->HTTP_OK, {
        success => 0,
        error => 'coolnodes nodegroup not found',
        coolnodes => [],
        pagination => { offset => 0, limit => $limit, total => 0 }
    }] unless $coolnodes_group;

    my $node_ids = $coolnodes_group->{group} || [];
    my $total = scalar(@$node_ids);

    # Reverse array (most recent first) and slice for pagination
    my @reversed = reverse @$node_ids;
    my @page_ids = splice(@reversed, $offset, $limit);

    # Get the coollink linktype to find who cooled each node
    my $coollink = $DB->getNode('coollink', 'linktype');
    my $coollink_id = $coollink ? $coollink->{node_id} : 0;

    # Fetch node details and who cooled them
    my @coolnodes;
    for my $node_id (@page_ids) {
        my $node = $DB->getNodeById($node_id);
        next unless $node;

        # Find who cooled this node
        my $cooled_by_name = undef;
        if ($coollink_id) {
            my $link_row = $DB->{dbh}->selectrow_hashref(
                'SELECT to_node FROM links WHERE from_node = ? AND linktype = ?',
                {}, $node_id, $coollink_id
            );
            if ($link_row && $link_row->{to_node}) {
                my $cooler = $DB->getNodeById($link_row->{to_node});
                $cooled_by_name = $cooler->{title} if $cooler;
            }
        }

        push @coolnodes, {
            node_id => $node->{node_id},
            title => $node->{title},
            cooled_by_name => $cooled_by_name
        };
    }

    return [$self->HTTP_OK, {
        success => 1,
        coolnodes => \@coolnodes,
        pagination => {
            offset => $offset,
            limit => $limit,
            total => $total
        }
    }];
}

sub get_endorsements {
    my ($self, $REQUEST, $editor_id) = @_;

    $editor_id = int($editor_id || 0);
    return [$self->HTTP_OK, {
        success => 0,
        error => 'invalid_editor_id'
    }] unless $editor_id > 0;

    my $DB = $self->DB;

    # Verify editor exists and is a user
    my $editor = $DB->getNodeById($editor_id);
    return [$self->HTTP_OK, {
        success => 0,
        error => 'editor_not_found'
    }] unless $editor && $editor->{type}{title} eq 'user';

    # Get the coollink linktype
    my $coollink = $DB->getNode('coollink', 'linktype');
    return [$self->HTTP_OK, {
        success => 0,
        error => 'coollink_not_found'
    }] unless $coollink;

    my $coollink_id = $coollink->{node_id};

    # Find all nodes this editor has cooled
    # The link goes FROM the node TO the editor
    my $sql = q|
        SELECT links.from_node AS node_id, node.title, node.type_nodetype
        FROM links
        INNER JOIN node ON node.node_id = links.from_node
        WHERE links.linktype = ?
        AND links.to_node = ?
        ORDER BY node.title
    |;

    my $rows = $DB->{dbh}->selectall_arrayref($sql, { Slice => {} },
        $coollink_id, $editor_id);

    my @nodes;
    for my $row (@$rows) {
        my $node = $DB->getNodeById($row->{node_id});
        next unless $node;

        my $node_data = {
            node_id => $node->{node_id},
            title => $node->{title},
            type => $node->{type}{title}
        };

        # If it's an e2node, count writeups
        if ($node->{type}{title} eq 'e2node') {
            my $group = $node->{group} || [];
            $node_data->{writeup_count} = scalar(@$group);
        }

        push @nodes, $node_data;
    }

    return [$self->HTTP_OK, {
        success => 1,
        editor_id => $editor_id,
        editor_name => $editor->{title},
        count => scalar(@nodes),
        nodes => \@nodes
    }];
}

__PACKAGE__->meta->make_immutable;

1;

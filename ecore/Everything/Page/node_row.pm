package Everything::Page::node_row;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::node_row - Node Row editorial tool (deprecated)

=head1 DESCRIPTION

Editorial tool for viewing and managing items on Node Row.
Shows writeups that have been removed from nodes and placed in the editorial queue.

NOTE: This tool is deprecated and scheduled for removal. It is part of the legacy
editorial workflow. Modern editorial processes should use alternative tools.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns Node Row data including counts and weblog entries.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $NODE  = $REQUEST->node;

    # Only editors can access
    unless ( $APP->isEditor( $USER->NODEDATA ) ) {
        return {
            type  => 'node_row',
            error => 'Access denied. This tool is restricted to editors and administrators.'
        };
    }

    # Get Node Row node
    my $node_row_node = $DB->getNode( 'Node Row', 'oppressor_superdoc' );
    return {
        type  => 'node_row',
        error => 'Node Row document not found'
    } unless $node_row_node;

    my $node_row_id = $node_row_node->{node_id};

    # Get counts
    my $total_count = $DB->sqlSelect( 'COUNT(*)', 'weblog',
        "weblog_id=$node_row_id AND removedby_user=0" ) || 0;

    my $removed_by_user = $DB->sqlSelect(
        'COUNT(*)',
        'weblog',
        "weblog_id=$node_row_id AND linkedby_user=" . $USER->node_id . " AND removedby_user=0"
    ) || 0;

    # Get weblog entries with pagination
    my $interval = 10;
    my $offset   = int( $query->param('offset') ) || 0;

    my $csr = $DB->sqlSelectMany(
        'weblog_id, to_node, linkedby_user, linkedtime, removedby_user',
        'weblog',
        "weblog_id=$node_row_id AND removedby_user=0",
        "ORDER BY linkedtime DESC LIMIT $interval OFFSET $offset"
    );

    my @entries = ();
    while ( my $row = $csr->fetchrow_hashref ) {
        my $node = $DB->getNodeById( $row->{to_node} );

        # Skip if node doesn't exist or is a draft
        next unless $node;
        next if $node->{type}{title} eq 'draft';

        my $linkedby_user = $DB->getNodeById( $row->{linkedby_user}, 'light' );

        push @entries,
          {
            weblog_id      => $row->{weblog_id},
            to_node        => $row->{to_node},
            node_title     => $node->{title},
            node_type      => $node->{type}{title},
            linkedby_user  => $row->{linkedby_user},
            linkedby_title => $linkedby_user ? $linkedby_user->{title} : 'Unknown',
            linkedtime     => $row->{linkedtime},
            content        => $self->getNodeContent($node),
            parent_node    => $self->getParentNode($node)
          };
    }

    # Check if there are more entries
    my $has_more = ( $total_count > $offset + $interval ) ? 1 : 0;

    return {
        type            => 'node_row',
        total_count     => $total_count,
        removed_by_user => $removed_by_user,
        entries         => \@entries,
        offset          => $offset,
        interval        => $interval,
        has_more        => $has_more,
        node_row_id     => $node_row_id
    };
}

=head2 getNodeContent($node)

Returns formatted content for a node (truncated if too long).

=cut

sub getNodeContent {
    my ( $self, $node ) = @_;

    my $content = $node->{doctext} || '';

    # Truncate if too long (first 500 characters)
    if ( length($content) > 500 ) {
        $content = substr( $content, 0, 500 ) . '...';
    }

    return $content;
}

=head2 getParentNode($node)

Returns the parent node information for a writeup.

=cut

sub getParentNode {
    my ( $self, $node ) = @_;

    return unless $node->{type}{title} eq 'writeup';

    my $parent_id = $node->{parent_e2node};
    return unless $parent_id;

    my $parent = $self->DB->getNodeById( $parent_id, 'light' );
    return unless $parent;

    return {
        node_id => $parent->{node_id},
        title   => $parent->{title}
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=head1 DEPRECATION NOTICE

This tool is part of the legacy editorial workflow and is scheduled for removal.
Modern editorial processes should use alternative tools.

=cut

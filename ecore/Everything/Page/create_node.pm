package Everything::Page::create_node;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::create_node

React page for Create Node - allows users to create new nodes.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $query = $REQUEST->cgi;

    # Get all nodetypes for the dropdown
    my $nodetype_type = $DB->getType('nodetype');
    my $nodetype_id   = $nodetype_type->{node_id};

    my $csr = $DB->sqlSelectMany(
        'node_id, title',
        'node',
        "type_nodetype=$nodetype_id",
        'ORDER BY title ASC'
    );

    my @nodetypes;
    while ( my $row = $csr->fetchrow_hashref ) {
        push @nodetypes, {
            node_id => $row->{node_id},
            title   => $row->{title}
        };
    }

    # Get the default nodetype (e2node)
    my $e2node_type    = $DB->getType('e2node');
    my $default_type   = $e2node_type ? $e2node_type->{node_id} : undef;
    my $newtitle       = $query->param('newtitle') || '';

    return {
        type           => 'create_node',
        nodetypes      => \@nodetypes,
        default_type   => $default_type,
        newtitle       => $newtitle
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

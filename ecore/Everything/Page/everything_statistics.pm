package Everything::Page::everything_statistics;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::everything_statistics

React page for Everything Statistics - displays site-wide statistics.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB = $self->DB;

    # Total Number of Nodes
    my $total_nodes = $DB->sqlSelect('count(*)', 'node');

    # Total Number of Writeups
    my $writeup_type_id = $DB->getType('writeup')->{node_id};
    my $total_writeups = $DB->sqlSelect('count(*)', 'node', "type_nodetype=$writeup_type_id");

    # Total Number of Users
    my $total_users = $DB->sqlSelect('count(*)', 'user');

    # Total Number of Links
    my $total_links = $DB->sqlSelect('count(*)', 'links');

    # Get node IDs for the footer links
    my $finger_node = $DB->getNode('Everything Finger', 'superdoc');
    my $news_node = $DB->getNode('news for noders.  stuff that matters.', 'document');

    return {
        type           => 'everything_statistics',
        total_nodes    => $total_nodes,
        total_writeups => $total_writeups,
        total_users    => $total_users,
        total_links    => $total_links,
        finger_node_id => $finger_node ? $finger_node->{node_id} : undef,
        news_node_id   => $news_node ? $news_node->{node_id} : undef
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

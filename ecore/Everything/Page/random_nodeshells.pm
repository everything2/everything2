package Everything::Page::random_nodeshells;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::random_nodeshells - Random Nodeshells page

=head1 DESCRIPTION

Generates a random list of nodeshells by picking random node IDs and filtering for
e2nodes with no writeups and no firmlinks.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data with a list of random nodeshells.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;

    # Guest users can't access this
    if ($APP->isGuest($USER)) {
        return {
            type => 'random_nodeshells',
            is_guest => 1,
            message => 'If you logged in, you could see random nodeshells.'
        };
    }

    my $max_id = $DB->sqlSelect('max(node_id)', 'node');
    my $num_nodes = 1200;
    my @rand = ();

    # Generate random node IDs
    for (my $x = 1; $x <= $num_nodes; $x++) {
        push @rand, int(rand($max_id));
    }

    my $rand_str = join(', ', @rand);

    # Query for e2nodes with no writeups and no firmlinks
    # Type 116 is e2node, linktype 1150375 is firmlink
    my $csr = $DB->sqlSelectMany('node_id',
        'node',
        'type_nodetype=116 and ' .
        '(select count(*) from nodegroup where nodegroup_id=node.node_id) = 0 and ' .
        '(select count(*) from links where linktype=1150375 and from_node=node.node_id limit 1) = 0 and ' .
        'node_id in (' . $rand_str . ')'
    );

    my @nodeshells = ();
    while (my $row = $csr->fetchrow_hashref) {
        my $node = $DB->getNodeById($row->{node_id});
        push @nodeshells, {
            node_id => $node->{node_id},
            title => $node->{title}
        };
    }

    return {
        type => 'random_nodeshells',
        is_guest => 0,
        num_searched => $num_nodes,
        num_found => scalar(@nodeshells),
        nodeshells => \@nodeshells
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

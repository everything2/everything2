package Everything::Page::random_nodes_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::random_nodes_xml_ticker - Random Nodes XML Ticker

=head1 DESCRIPTION

Returns XML listing random nodes from the system's randomnodes stash,
prefixed with a randomly selected witty phrase.

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing random nodes with a random witty phrase.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $XG = $self->xml_generator;

    my @phrase = (
        'Nodes your grandma would have liked:',
        'After stirring Everything, these nodes rose to the top:',
        'Look at this mess the Death Borg made!',
        'Just another sprinking of indeterminacy',
        'The best nodes of all time:'
    );

    my $wit = $XG->wit($phrase[rand(int(@phrase))]);

    my $randomnodes = $self->DB->stashData("randomnodes");

    my $links = '';
    foreach my $N (@$randomnodes) {
        $links .= "\n  " . $XG->e2link({node_id => $$N{node_id}}, $$N{title});
    }

    return qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n} .
           $XG->randomnodes("\n" . $wit . $links . "\n");
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

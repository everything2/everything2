package Everything::Page::xml_interfaces_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::xml_interfaces_ticker - XML Interfaces Ticker Page

=head1 DESCRIPTION

Returns a list of all available XML export interfaces on the system.
This ticker provides metadata about other XML tickers available.

=head1 METHODS

=head2 generate_xml($REQUEST)

Generates XML listing all available XML export interfaces.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $XG = $self->xml_generator;

    # Current node (this ticker)
    my $this = $XG->this(
        {node_id => $node->node_id},
        $node->title
    );

    # Get all XML export interfaces from settings
    my $xml_exports = $self->DB->getNode("XML exports", "setting");
    my $ifaces = $self->APP->getVars($xml_exports);

    my $exports = '';
    foreach my $iface_key (keys %$ifaces)
    {
        my $iface_node = $self->DB->getNodeById($ifaces->{$iface_key});
        next unless $iface_node;

        $exports .= $XG->xmlexport(
            {iface => $iface_key, node_id => $iface_node->{node_id}},
            $iface_node->{title}
        );
    }

    return $self->xml_header() . $XG->xmlcaps($this . $exports);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

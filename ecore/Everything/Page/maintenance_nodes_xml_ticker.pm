package Everything::Page::maintenance_nodes_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::maintenance_nodes_xml_ticker - Maintenance Nodes XML Ticker

=head1 DESCRIPTION

Returns XML listing maintenance nodes configured in the system.
These are important system/admin nodes from $Everything::CONF->maintenance_nodes.

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing maintenance nodes.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $XG = $self->xml_generator;

    my $links = '';
    foreach my $n (@{$Everything::CONF->maintenance_nodes})
    {
        my $maint_node = $self->DB->getNodeById($n);
        $links .= $XG->e2link({node_id => $$maint_node{node_id}}, $$maint_node{title}) . "\n";
    }

    return $self->xml_header() . $XG->maintenance("\n" . $links);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

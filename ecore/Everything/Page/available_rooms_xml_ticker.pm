package Everything::Page::available_rooms_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::available_rooms_xml_ticker - Available Rooms XML Ticker

=head1 DESCRIPTION

Returns XML listing all available chat rooms on the system, including
the "go outside" link and all room nodes.

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing all available rooms.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $XG = $self->xml_generator;

    # Outside section
    my $go = $self->DB->getNode("go outside", "superdocnolinks");
    my $outside = $XG->outside(
        $XG->e2link({node_id => $go->{node_id}}, $go->{title})
    );

    # Roomlist section
    my $room_type = $self->DB->getType("room");
    my $csr = $self->DB->sqlSelectMany("node_id, title", "node",
        "type_nodetype=" . $self->DB->getId($room_type));

    my $rooms = {};
    while(my $ROW = $csr->fetchrow_hashref())
    {
        $rooms->{lc($ROW->{title})} = $ROW->{node_id};
    }

    my $roomlinks = '';
    foreach my $key (sort(keys %$rooms))
    {
        my $n = $self->DB->getNodeById($rooms->{$key});
        $roomlinks .= $XG->e2link({node_id => $n->{node_id}}, $n->{title});
    }

    my $roomlist = $XG->roomlist($roomlinks);

    return $self->xml_header() . $XG->e2rooms($outside . $roomlist);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

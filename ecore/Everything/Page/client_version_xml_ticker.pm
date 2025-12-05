package Everything::Page::client_version_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::client_version_xml_ticker - Client Version XML Ticker

=head1 DESCRIPTION

Returns XML listing all registered E2 client applications, including
version information, homepage, download URL, and maintainer details.

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing all E2 clients.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $XG = $self->xml_generator;

    my $client_type = $self->DB->getType('e2client');
    my $csr = $self->DB->sqlSelectMany("node_id", "node",
        "type_nodetype=" . $self->DB->getId($client_type));

    my $clients = '';

    while(my $r = $csr->fetchrow_hashref())
    {
        my $cl = $self->DB->getNodeById($r);
        my $u = $self->DB->getNodeById($cl->{author_user});

        $clients .= $XG->client(
            {client_id => $cl->{node_id}, client_class => $cl->{clientstr}},
            $XG->version($cl->{version}) .
            $XG->homepage($cl->{homeurl}) .
            $XG->download($cl->{dlurl}) .
            $XG->maintainer({node_id => $u->{node_id}}, $u->{title})
        );
    }

    return $self->xml_header() . $XG->clientregistry($clients);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

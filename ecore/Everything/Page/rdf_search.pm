package Everything::Page::rdf_search;

use Moose;
extends 'Everything::Page';

use XML::Generator;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::rdf_search - RDF Search Interface

=head1 DESCRIPTION

Returns search results in RDF (Resource Description Framework) XML format.
Searches for e2nodes matching the keywords parameter.

Query parameters:
- keywords: Search terms (use + delimited words)

=head1 METHODS

=head2 display($REQUEST, $node)

Returns RDF XML feed of search results.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;

    my $keywords = $self->APP->cleanNodeName(scalar $query->param('keywords'));
    my $e2ntype = Everything::getId(Everything::getNode("e2node", "nodetype"));

    return [$self->HTTP_OK, "no keywords supplied", {type => 'text/plain'}] unless $keywords;

    my $nodes = $self->APP->searchNodeName($keywords, [$e2ntype], 0, 1);

    my $XG = XML::Generator->new();

    my $xml = '';

    $xml .= "\n\t" . $XG->channel("\n\t\t"
        . $XG->title("RDF Search") . "\n\t\t"
        . $XG->link("http://everything2.com/?node_id=" . Everything::getId($node->NODEDATA)) . "\n\t\t"
        . $XG->description("RDF interface to E2 Search.  \"keywords\" parameter should use + delimited words.") . "\n\t");

    foreach (@$nodes) {
        $xml .= "\n\t" . $XG->item("\n\t\t"
            . $XG->title($self->APP->xml_escape($_->{title})) . "\n\t\t"
            . $XG->link("http://everything2.com/?node_id=" . Everything::getId($_)) . "\n\t"
        ) unless $_->{type_nodetype} != $e2ntype;
    }

    $xml = $XG->RDF($xml . "\n");

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $xml, {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::Page::e2_xml_search_interface;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::e2_xml_search_interface - XML search interface for E2

=head1 DESCRIPTION

Returns XML search results for nodes matching the given keywords.

Supports query parameters:
- keywords: Search terms
- typerestrict: Restrict search to a specific nodetype (default: e2node)

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML with search info and matching results.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $XG = $self->xml_generator;
    my $APP = $self->APP;
    my $DB = $self->DB;

    my $keywords = $APP->cleanNodeName($query->param('keywords') // '');
    my $tr = $query->param('typerestrict');

    my $typerestrict;
    $typerestrict = $DB->getNode($tr, 'nodetype') if $tr;

    my $e2ntype = $typerestrict || $DB->getNode('e2node', 'nodetype');

    # Build search info section
    my $search_info = $XG->searchinfo(
        $XG->keywords($keywords // '') .
        $XG->search_nodetype({node_id => $e2ntype->{node_id}}, $e2ntype->{title})
    );

    # Build search results
    my $results = '';
    if ($keywords) {
        my $nodes = $APP->searchNodeName($keywords, [$e2ntype->{node_id}], 0, 1);

        foreach my $n (@$nodes) {
            next unless $n->{type_nodetype} == $e2ntype->{node_id};
            $results .= $XG->e2link({node_id => $n->{node_id}}, $n->{title}) . "\n";
        }
    }

    my $search_results = $XG->searchresults("\n" . $results);

    return $self->xml_header() . $XG->searchinterface("\n" . $search_info . "\n" . $search_results . "\n");
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

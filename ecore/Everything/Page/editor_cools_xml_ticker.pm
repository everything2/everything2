package Everything::Page::editor_cools_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::editor_cools_xml_ticker - Editor Cools XML Ticker

=head1 DESCRIPTION

Returns XML listing editor-selected cool nodes from the 'coolnodes' nodegroup.
These are special cools endorsed by editors with 'coollink' links.

Supports query parameters:
- count: Number of results (default 10, max 50)

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing editor-selected cool nodes.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $XG = $self->xml_generator;

    my $poclink = $self->DB->getId($self->DB->getNode('coollink', 'linktype'));
    my $pocgrp = $self->DB->getNode('coolnodes', 'nodegroup');
    my $count = 0;
    my $countmax = $query->param('count');
    $countmax ||= 10;
    $countmax = 50 if $countmax > 50;

    $pocgrp = $$pocgrp{group};

    my $selections = '';
    foreach(reverse @$pocgrp)
    {
        last if($count >= $countmax);
        $count++;

        next unless($_);

        my $csr = $self->DB->{dbh}->prepare('SELECT * FROM links WHERE from_node=\''.$self->DB->getId($_).'\' and linktype=\''.$poclink.'\'');

        $csr->execute;

        my $coolref = $csr->fetchrow_hashref;

        next unless($coolref);
        my $cooler = $self->DB->getNodeById($$coolref{to_node});
        $coolref = $self->DB->getNodeById($$coolref{from_node});
        next unless($coolref);

        $selections .= $XG->edselection(
            "\n " .
            $XG->endorsed({node_id => $$cooler{node_id}}, $$cooler{title}) .
            "\n " .
            $XG->e2link({node_id => $$coolref{node_id}}, $$coolref{title}) .
            "\n"
        ) . "\n";
        $csr->finish();
    }

    return qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n} . $XG->editorcools("\n" . $selections);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

package Everything::Page::cool_nodes_xml_ticker;

use Moose;
extends 'Everything::Page';

use XML::Generator;

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::cool_nodes_xml_ticker - Cool Nodes XML Ticker

=head1 DESCRIPTION

Returns the most recently cooled writeups in XML format. Shows up to 15 unique
cooled writeups with node_id, parent e2node, author, and who cooled it.

=head1 METHODS

=head2 display($REQUEST, $node)

Returns XML feed of recently cooled writeups.

=cut

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $cache = $self->DB->stashData("coolnodes");

    my $xml = '';
    my $XG = XML::Generator->new();

    my $count = 15;
    my %used = ();

    foreach my $CW (@$cache) {
        next if exists $used{$$CW{coolwriteups_id}};
        $used{$$CW{coolwriteups_id}} = 1;
        $xml .="\t".$XG->cooled({node_id => $$CW{coolwriteups_id},
            parent_e2node => $$CW{parentNode},
            author_user => $$CW{wu_author},
            cooledby_user => $$CW{cooluser}},
            $$CW{parentTitle})."\n";
        last unless (--$count);
    }

    $xml = $XG->COOLEDNODES(
        $XG->INFO({site => $self->CONF->site_url, sitename => $self->CONF->site_name,  servertime => scalar(localtime(time))}, 'Rendered by the Cool Nodes XML Ticker')
        . "\n".$xml . "\n");

    return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $xml, {type => $self->mimetype}];
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

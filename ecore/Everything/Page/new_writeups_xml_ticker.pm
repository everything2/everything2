package Everything::Page::new_writeups_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::new_writeups_xml_ticker - New Writeups XML Ticker

=head1 DESCRIPTION

Returns XML listing recently published writeups, filtered according to
user preferences (infravision, reputation thresholds, etc.).

Supports query parameters:
- count: Number of results (default 15, max 100)

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing recent writeups with metadata.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;
    my $XG = $self->xml_generator;

    my $limit = $query->param("count");
    $limit ||= "15";
    $limit =~ s/[^\d]//g;
    $limit = 100 if ($limit > 100);

    my $writeupsdata = $self->APP->filtered_newwriteups($USER, $limit);

    my $writeups = '';
    foreach my $wu (@$writeupsdata)
    {
        my $wutype = $wu->{writeuptype} || '';

        my $wu_content = $XG->e2link({node_id => $wu->{node_id}}, $wu->{title});

        my $author_content = '';
        $author_content = $XG->e2link({node_id => $wu->{author}->{node_id}}, $wu->{author}->{title}) if $wu->{author};
        $wu_content .= $XG->author($author_content);

        my $parent_content = '';
        $parent_content = $XG->e2link({node_id => $wu->{parent}->{node_id}}, $wu->{parent}->{title}) if $wu->{parent};
        $wu_content .= $XG->parent($parent_content);

        $writeups .= $XG->wu({wrtype => $wutype}, $wu_content);
    }

    return $self->xml_header() . $XG->newwriteups($writeups);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

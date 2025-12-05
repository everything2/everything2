package Everything::Page::raw_vars_xml_ticker;

use Moose;
extends 'Everything::Page';
with 'Everything::XMLTicker';

has 'mimetype' => (default => 'application/xml', is => 'ro');

=head1 NAME

Everything::Page::raw_vars_xml_ticker - Raw Vars XML Ticker

=head1 DESCRIPTION

Returns XML listing the user's exportable vars (user preferences).
Only available to logged-in users (guests see empty XML).

=head1 METHODS

=head2 generate_xml($REQUEST, $node)

Generates XML listing user's exportable variable settings.

=cut

sub generate_xml {
    my ($self, $REQUEST, $node) = @_;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $self->APP->getVars($USER);
    my $XG = $self->xml_generator;

    my $keys = '';
    unless($self->APP->isGuest($USER)) {
        my $exportable_vars = $self->DB->getNode("exportable vars", "setting");
        my $ev = $self->APP->getVars($exportable_vars);

        foreach(keys %$ev) {
            next unless $$VARS{$_};
            $keys .= $XG->key({name => $_}, $$VARS{$_}) . "\n";
        }
    }

    return $self->xml_header() . $XG->vars($keys);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::XMLTicker>

=cut

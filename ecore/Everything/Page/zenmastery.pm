package Everything::Page::zenmastery;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::zenmastery - CSS demonstration page for staff features

=head1 DESCRIPTION

Pure demonstration page showing staff-only HTML classes and IDs for
styling purposes. All content is static HTML with neutered forms.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns minimal data structure - all content rendered in React.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'zenmastery'
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

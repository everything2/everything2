package Everything::Page::word_messer_upper;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::word_messer_upper - Word shuffler tool

=head1 DESCRIPTION

Pure client-side React component that shuffles words in user-provided text.
No server-side logic needed - all processing happens in the browser.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns minimal React data structure since all logic is client-side.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'word_messer_upper'
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

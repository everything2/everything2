package Everything::Page::e2_word_counter;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::e2_word_counter - Interactive word counting tool

=head1 DESCRIPTION

E2 Word Counter is a client-side utility for counting words in text.
It provides live updates as you type, showing word count, character count,
and other statistics. Useful for writers checking writeup length.

This is a pure client-side tool - no server processing needed.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns minimal data - all counting logic is client-side.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    # Pure client-side tool, no server data needed
    return {};
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::Page::e2_source_code_formatter;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::e2_source_code_formatter - E2 Source Code Formatter

=head1 DESCRIPTION

A client-side tool for formatting source code for E2 writeups by converting
angle brackets, square brackets, and ampersands to HTML entities.

Original version written by wharfinger 11/23/00 - in the public domain.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure (no server-side processing needed).

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'e2_source_code_formatter'
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

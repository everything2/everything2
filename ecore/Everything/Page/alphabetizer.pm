package Everything::Page::alphabetizer;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::alphabetizer - Client-side text alphabetizing utility

=head1 DESCRIPTION

Pure React utility for sorting and formatting lists of text entries.
All processing happens client-side in JavaScript.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns minimal data - user preferences for initial state.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $VARS = $REQUEST->VARS;

    return {
        type => 'alphabetizer',
        separator => $VARS->{alphabetizer_sep} || '0',
        sort_order => $VARS->{alphabetizer_sortorder} ? 1 : 0,
        ignore_case => $VARS->{alphabetizer_case} ? 0 : 1,  # Inverse checkbox
        format_links => $VARS->{alphabetizer_format} ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

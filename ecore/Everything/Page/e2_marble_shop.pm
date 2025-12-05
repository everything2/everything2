package Everything::Page::e2_marble_shop;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::e2_marble_shop - E2 Marble Shop

=head1 DESCRIPTION

A humorous "marble shop" that has no marbles to sell. For when you've lost your marbles.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure (static content).

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'e2_marble_shop'
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

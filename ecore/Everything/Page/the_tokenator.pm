package Everything::Page::the_tokenator;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::the_tokenator

React page for The Tokenator - admin tool to give tokens to users.

Pure-render: the give-tokens WRITE (per user: Cool Man Eddie notification + a `tokens`
var increment) moved to POST /api/the_tokenator/tokenate (Everything::API::the_tokenator,
#4455, Refs #4298), so this page no longer mutates off tokenateUser<N> query params.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Admins only (implied by oppressor_superdoc)
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type          => 'the_tokenator',
            access_denied => 1
        };
    }

    return {
        type => 'the_tokenator'
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

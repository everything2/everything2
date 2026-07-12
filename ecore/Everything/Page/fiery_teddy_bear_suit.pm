package Everything::Page::fiery_teddy_bear_suit;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::fiery_teddy_bear_suit

React page for Fiery Teddy Bear Suit - curses users with -1 GP.

Admin only. Posts a public hug message to the chatterbox from the
Fiery Teddy Bear user, and removes 1 GP from the target user.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text (incl. the
    # acting-user intro), permission tier, and API endpoint, keyed on this type (#4509).
    return { type => 'fiery_teddy_bear_suit' };
}

__PACKAGE__->meta->make_immutable;

1;

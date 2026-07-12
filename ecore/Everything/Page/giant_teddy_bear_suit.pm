package Everything::Page::giant_teddy_bear_suit;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::giant_teddy_bear_suit

React page for Giant Teddy Bear Suit - grants +2 GP to users with public hug.

Admin only. Posts a public hug message to the chatterbox from the
Giant Teddy Bear user, and grants 2 GP to the target user.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text (incl. the
    # acting-user intro), permission tier, and API endpoint, keyed on this type (#4509).
    return { type => 'giant_teddy_bear_suit' };
}

__PACKAGE__->meta->make_immutable;

1;

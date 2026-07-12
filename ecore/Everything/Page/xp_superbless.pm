package Everything::Page::xp_superbless;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::xp_superbless

React page for XP Superbless - grants XP to users.

Admin only. This is an archived version of the old Superbless which used
to give XP instead of GP. All blessings should be given in GP nowadays.
There is no reason why administrators should fiddle with user XP except
for extraordinary circumstances. All usage is logged.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text + the admin
    # permission tier, keyed on this type; the API is the real enforcement boundary (#4509).
    return { type => 'xp_superbless' };
}

__PACKAGE__->meta->make_immutable;

1;

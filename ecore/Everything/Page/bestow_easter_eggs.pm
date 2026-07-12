package Everything::Page::bestow_easter_eggs;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::bestow_easter_eggs

React page for Bestow Easter Eggs - grants easter eggs to users.

Admin only. Allows administrators to give easter eggs to users.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text + permission
    # tier, keyed on this type; the API is the real enforcement boundary (#4509).
    return { type => 'bestow_easter_eggs' };
}

__PACKAGE__->meta->make_immutable;

1;

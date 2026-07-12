package Everything::Page::the_well_of_cool;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::the_well_of_cool

React page for The Well of Cool - self-service cool granting.

Any user can grant themselves cools using this page.
Uses the unified AdminBestowTool React component configured for self-service.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text and self-service
    # behavior (any user; row 0 prefilled with the acting user), keyed on this type (#4509).
    return { type => 'the_well_of_cool' };
}

__PACKAGE__->meta->make_immutable;

1;

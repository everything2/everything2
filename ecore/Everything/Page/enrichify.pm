package Everything::Page::enrichify;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::enrichify

React page for Enrichify - grants GP to users (Admin-only version).

Administrators can use this tool to grant GP to any user.
Uses the unified AdminBestowTool React component.
Similar to Superbless but restricted to Admin level access.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text + permission
    # tier, keyed on this type; the API is the real enforcement boundary (#4509).
    return { type => 'enrichify' };
}

__PACKAGE__->meta->make_immutable;

1;

package Everything::Page::superbless;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::superbless

React page for Superbless - grants GP to users.

Now a restricted_superdoc nodetype (permissions handled at node type level).
Uses the unified AdminBestowTool React component.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Pure gate: ships only its type. React (AdminBestowTool) owns the flavor text + the editor
    # permission tier, keyed on this type. The API (grant_gp, is_editor) is the real enforcement
    # boundary; the React flag only drives display -- the /api/pagestate path bypasses controller
    # gates, so permission is computed client-side from the actual user, never hardcoded (#4509/#4498).
    return { type => 'superbless' };
}

__PACKAGE__->meta->make_immutable;

1;

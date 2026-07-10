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

    # prefill_username is NOT read here -- it's a client concern; AdminBestowTool reads it off
    # window.location. The server neither reads nor ships it (#4500, same as websterbless #4497).
    return {
        type => 'admin_bestow_tool',
        title => 'Superbless',
        description => 'Grant GP to users. Positive values give GP, negative values remove GP. Karma is adjusted accordingly.',
        # Per-user permission flag (editors; admins are editors). Computed here, NOT hardcoded 1:
        # the /api/pagestate client-router path doesn't enforce the node's read perms, so a guest
        # would otherwise be handed has_permission=1 and a usable-looking tool. The API (grant_gp,
        # is_editor) is the real enforcement boundary; this only drives the React display. Full
        # mixin consolidation (both paths) is #4498. Matches xp_superbless's per-user flag.
        has_permission => $REQUEST->user->is_editor ? 1 : 0,
        permission_error => 'This tool is available to editors and administrators.',
        resource_name => 'GP',
        show_amount_input => 1,
        allow_negative => 1,
        default_amount => '',
        row_count => 10,
        api_endpoint => '/api/superbless/grant_gp',
        button_text => 'Superbless',
        button_text_loading => 'Superblessing...',
        note_text => 'All GP grants are logged. Karma is adjusted based on the direction of the grant.',
    };
}

__PACKAGE__->meta->make_immutable;

1;

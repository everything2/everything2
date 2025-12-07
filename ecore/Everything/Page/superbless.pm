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

    # No permission check needed - restricted_superdoc type handles access control
    return {
        type => 'admin_bestow_tool',
        title => 'Superbless',
        description => 'Grant GP to users. Positive values give GP, negative values remove GP. Karma is adjusted accordingly.',
        has_permission => 1,  # Access already verified by superdoc permissions
        resource_name => 'GP',
        show_amount_input => 1,
        allow_negative => 1,
        default_amount => '',
        row_count => 10,
        api_endpoint => '/api/superbless/grant_gp',
        button_text => 'Superbless',
        button_text_loading => 'Superblessing...',
        note_text => 'All GP grants are logged. Karma is adjusted based on the direction of the grant.'
    };
}

__PACKAGE__->meta->make_immutable;

1;

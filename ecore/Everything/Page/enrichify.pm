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

    my $APP = $self->APP;
    my $user = $REQUEST->user;

    return {
        type => 'admin_bestow_tool',
        title => 'Enrichify',
        description => 'Grant GP to users. Positive values give GP, negative values remove GP. Karma is adjusted accordingly.',
        has_permission => $APP->isAdmin($user->NODEDATA) ? 1 : 0,
        permission_error => 'You want to be supercursed? No? Then play elsewhere.',
        resource_name => 'GP',
        show_amount_input => 1,
        allow_negative => 1,
        default_amount => '',
        row_count => 10,
        api_endpoint => '/api/superbless/grant_gp',
        button_text => 'Enrichify',
        button_text_loading => 'Enrichifying...',
        note_text => 'All GP grants are logged. Karma is adjusted based on the direction of the grant.'
    };
}

__PACKAGE__->meta->make_immutable;

1;

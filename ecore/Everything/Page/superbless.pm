package Everything::Page::superbless;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::superbless

React page for Superbless - grants GP to users.

Editors and above can use this tool to grant GP to any user.
Uses the unified AdminBestowTool React component.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $user = $REQUEST->user;

    return {
        type => 'admin_bestow_tool',
        title => 'Superbless',
        description => 'Grant GP to users. Positive values give GP, negative values remove GP. Karma is adjusted accordingly.',
        has_permission => $APP->isEditor($user->NODEDATA) ? 1 : 0,
        permission_error => 'You have not yet learned that spell.',
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

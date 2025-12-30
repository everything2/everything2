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

    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Get prefill_username from URL parameter (for user tools modal integration)
    my $prefill_username = $REQUEST->param('prefill_username') || '';

    return {
        type => 'admin_bestow_tool',
        title => 'XP Superbless (Archived)',
        description => 'WARNING: This is an archived version of the old Superbless which used to give XP instead of GP. All blessings should be given in GP nowadays. There is no reason why administrators should fiddle with user XP except for extraordinary circumstances. All usage of this tool is logged. Please contact Tem42 if a user wants XP reset to zero.',
        has_permission => $APP->isAdmin($user->NODEDATA) ? 1 : 0,
        permission_error => 'Only administrators can grant XP.',
        resource_name => 'XP',
        show_amount_input => 1,
        allow_negative => 1,
        default_amount => '',
        row_count => 5,
        api_endpoint => '/api/superbless/grant_xp',
        button_text => 'Grant XP',
        button_text_loading => 'Granting XP...',
        note_text => 'All XP grants are logged and audited. Use [Superbless] for normal GP blessings.',
        prefill_username => $prefill_username
    };
}

__PACKAGE__->meta->make_immutable;

1;

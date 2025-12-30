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

    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Get prefill_username from URL parameter (for user tools modal integration)
    my $prefill_username = $REQUEST->param('prefill_username') || '';

    return {
        type => 'admin_bestow_tool',
        title => 'Bestow Easter Eggs',
        description => 'Grant easter eggs to users. Each user receives one easter egg per entry.',
        has_permission => $APP->isAdmin($user->NODEDATA) ? 1 : 0,
        permission_error => 'Who do you think you are? The Easter Bunny?',
        resource_name => 'Eggs',
        fixed_amount => 1,
        show_amount_input => 0,
        row_count => 5,
        api_endpoint => '/api/easter_eggs/bestow',
        button_text => 'Bestow Easter Eggs',
        button_text_loading => 'Bestowing...',
        note_text => 'Each user receives one easter egg. Users get a message from Cool Man Eddie.',
        prefill_username => $prefill_username
    };
}

__PACKAGE__->meta->make_immutable;

1;

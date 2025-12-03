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

    my $user = $REQUEST->user;

    return {
        type => 'admin_bestow_tool',
        title => 'The Well of Cool',
        description => 'Drink deeply from the well of cool. Grant yourself cools (C!) to highlight excellent writeups.',
        has_permission => 1,  # All users can use this
        permission_error => '',
        resource_name => 'Cools',
        show_amount_input => 1,
        allow_negative => 0,
        default_amount => '1',
        row_count => 1,  # Only one row needed for self-service
        api_endpoint => '/api/superbless/grant_cools',
        button_text => 'Drink deeply from the well of cool',
        button_text_loading => 'Drinking...',
        note_text => 'Cools allow you to C! writeups you find excellent.',
        prefill_username => $user->title  # Pre-fill with current user's name
    };
}

__PACKAGE__->meta->make_immutable;

1;

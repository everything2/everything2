package Everything::Page::bestow_cools;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::bestow_cools

React page for Bestow Cools - grants cools (chings) to users.

Admin only. Allows administrators to grant additional cools to users.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $user = $REQUEST->user;

    return {
        type => 'admin_bestow_tool',
        title => 'Bestow Cools',
        description => 'Grant cools (C!) to users. Users can use cools to highlight excellent writeups.',
        has_permission => $APP->isAdmin($user->NODEDATA) ? 1 : 0,
        permission_error => 'Only administrators can bestow cools.',
        resource_name => 'Cools',
        show_amount_input => 1,
        allow_negative => 0,
        default_amount => '1',
        row_count => 5,
        api_endpoint => '/api/superbless/grant_cools',
        button_text => 'Bestow Cools',
        button_text_loading => 'Bestowing...',
        note_text => 'Cools allow users to C! writeups they find excellent.'
    };
}

__PACKAGE__->meta->make_immutable;

1;

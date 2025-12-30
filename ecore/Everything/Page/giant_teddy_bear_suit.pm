package Everything::Page::giant_teddy_bear_suit;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::giant_teddy_bear_suit

React page for Giant Teddy Bear Suit - grants +2 GP to users with public hug.

Admin only. Posts a public hug message to the chatterbox from the
Giant Teddy Bear user, and grants 2 GP to the target user.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $user = $REQUEST->user;
    my $is_admin = $APP->isAdmin($user->NODEDATA) ? 1 : 0;

    # Get prefill_username from URL parameter (for user tools modal integration)
    my $prefill_username = $REQUEST->param('prefill_username') || '';

    return {
        type => 'admin_bestow_tool',
        title => 'Giant Teddy Bear Suit',
        description => $is_admin
            ? 'The user(s) are publicly hugged by a Giant Teddy Bear. Users receive +2 GP and +1 karma.'
            : undef,
        intro_text => $user->title . ' has donned the Giant Teddy Bear Suit . . .',
        has_permission => $is_admin,
        permission_error => 'Hands off the bear, bobo.',
        resource_name => 'GP',
        fixed_amount => 2,
        show_amount_input => 0,
        row_count => 5,
        api_endpoint => '/api/teddybear/hug',
        button_text => 'Hug Users',
        button_text_loading => 'Hugging...',
        note_text => 'Giant Teddy Bear hugs grant 2 GP and post a public hug message to the chatterbox.',
        prefill_username => $prefill_username
    };
}

__PACKAGE__->meta->make_immutable;

1;

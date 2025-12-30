package Everything::Page::fiery_teddy_bear_suit;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::fiery_teddy_bear_suit

React page for Fiery Teddy Bear Suit - curses users with -1 GP.

Admin only. Posts a public hug message to the chatterbox from the
Fiery Teddy Bear user, and removes 1 GP from the target user.

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
        title => 'Fiery Teddy Bear Suit',
        description => $is_admin
            ? 'The user(s) are publicly hugged by a Fiery Teddy Bear. Users are cursed with -1 GP and -1 karma.'
            : undef,
        intro_text => $user->title . ' is engulfed in flames . . . OW!',
        has_permission => $is_admin,
        permission_error => 'Hands off the bear, bobo.',
        resource_name => 'GP',
        fixed_amount => -1,
        show_amount_input => 0,
        row_count => 5,
        api_endpoint => '/api/superbless/fiery_hug',
        button_text => 'Hug Users',
        button_text_loading => 'Hugging...',
        note_text => 'Fiery hugs remove 1 GP and post a public hug message to the chatterbox.',
        prefill_username => $prefill_username
    };
}

__PACKAGE__->meta->make_immutable;

1;

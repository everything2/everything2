package Everything::Page::everything_poll_creator;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $user = $REQUEST->user;

    # Check if polls are currently disabled
    my $polls_disabled = 0; # Could be a system setting

    # Check if user can create polls (must be logged in)
    my $can_create = $user && !$user->is_guest ? 1 : 0;

    # Get the current poll god (defaults to 'mauler')
    my $poll_god = 'mauler';

    return {
        type => 'everything_poll_creator',
        polls_disabled => $polls_disabled,
        can_create => $can_create,
        poll_god => $poll_god
    };
}

__PACKAGE__->meta->make_immutable;

1;

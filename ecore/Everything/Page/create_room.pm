package Everything::Page::create_room;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::create_room - Create new chat room page

=head1 DESCRIPTION

Allows users to create new chat rooms. Requires a minimum level
(configurable), admin status, or chanop privileges.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about user's ability to create rooms and any suspension status.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $CONF = $self->CONF;
    my $USER = $REQUEST->user->NODEDATA;

    my $user_level = $APP->getLevel($USER);
    my $required_level = $CONF->create_room_level || 0;
    my $is_admin = $APP->isAdmin($USER) ? 1 : 0;
    my $is_chanop = $APP->isChanop($USER) ? 1 : 0;

    # Check if user can create rooms
    my $can_create = ($user_level >= $required_level || $is_admin || $is_chanop) ? 1 : 0;

    # Check for suspension
    my $is_suspended = $APP->isSuspended($USER, 'room') ? 1 : 0;

    return {
        type => 'create_room',
        can_create => $can_create,
        is_suspended => $is_suspended,
        required_level => int($required_level),
        user_level => int($user_level),
        is_admin => $is_admin,
        is_chanop => $is_chanop
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::chatroom>

=cut

package Everything::Page::e2_bouncer;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::e2_bouncer - Chanop tool for bulk user room management

=head1 DESCRIPTION

E2 Bouncer allows chanops to move multiple users between chat rooms.
Also known as "Nerf Borg" - a softer way to manage user locations
without borging them.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about available rooms and chanop status.
Requires chanop privileges to use.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;

    my $is_chanop = $APP->isChanop($USER) ? 1 : 0;

    # Get all rooms for the dropdown
    my $room_type = $DB->getNode('room', 'nodetype');
    my @rooms = ();

    if ($room_type) {
        my $csr = $DB->sqlSelectMany('node_id, title', 'node',
            'type_nodetype=' . $room_type->{node_id});

        while (my $row = $csr->fetchrow_hashref()) {
            push @rooms, {
                node_id => int($row->{node_id}),
                title => $row->{title}
            };
        }

        # Sort rooms alphabetically (case-insensitive)
        @rooms = sort { lc($a->{title}) cmp lc($b->{title}) } @rooms;
    }

    # Random quips for the room list
    my @quips = (
        'Yeah, yeah, get a room...',
        'I\'ll take door number three...',
        'Hey, that\'s a llama back there!',
        'Three doors, down, on your right, just past Political Asylum',
        'They can\'t ALL be locked!?',
        'Why be so stuffed up in a room? Go outside!'
    );

    return {
        type => 'e2_bouncer',
        is_chanop => $is_chanop,
        rooms => \@rooms,
        quip => $quips[int(rand(@quips))]
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::bouncer>

=cut

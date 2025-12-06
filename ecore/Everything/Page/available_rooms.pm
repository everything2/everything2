package Everything::Page::available_rooms;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::available_rooms - Available Rooms page

=head1 DESCRIPTION

Displays a list of all available chat rooms on Everything2.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about available chat rooms.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $NODE = $REQUEST->node;

    # Get room nodetype
    my $room_type = $DB->getNode('room', 'nodetype');
    return {
        type => 'available_rooms',
        error => 'Room nodetype not found'
    } unless $room_type;

    # Get all room nodes
    my $csr = $DB->sqlSelectMany('node_id, title', 'node',
        'type_nodetype=' . $room_type->{node_id});

    my @rooms = ();
    while (my $row = $csr->fetchrow_hashref()) {
        push @rooms, {
            node_id => $row->{node_id},
            title => $row->{title}
        };
    }

    # Sort rooms alphabetically by title (case-insensitive)
    @rooms = sort { lc($a->{title}) cmp lc($b->{title}) } @rooms;

    # Pick a random quip
    my @quips = (
        'Yeah, yeah, get a room...',
        'I\'ll take door number three...',
        'Hey, that\'s a llama back there!',
        'Three doors, down, on your right, just past [Political Asylum]',
        'They can\'t ALL be locked!?',
        'Why be so stuffed up in a room? [Go outside]!'
    );

    my $quip = $quips[int(rand(@quips))];

    return {
        type => 'available_rooms',
        quip => $quip,
        rooms => \@rooms
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::API::bouncer;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

=head1 NAME

Everything::API::bouncer - API for bulk user room management

=head1 DESCRIPTION

Allows chanops to move multiple users between chat rooms at once.

=head1 ROUTES

=over 4

=item POST /api/bouncer/

Move users to a specified room

=back

=cut

sub routes {
    return {
        '/' => 'move_users',
    }
}

=head2 move_users($REQUEST)

Move multiple users to a specified room.

POST body:
  {
    "usernames": ["user1", "user2", ...],
    "room_title": "Room Name"  (or "outside" for outside)
  }

Returns:
  {
    "success": 1,
    "moved": ["user1", "user2"],
    "not_found": ["baduser"],
    "room_title": "Room Name"
  }

=cut

sub move_users {
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Check chanop permission
    unless ($APP->isChanop($USER)) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Permission denied. Chanop access required.'
        }];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;
    unless ($data) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid JSON body'
        }];
    }

    # Validate usernames
    my $usernames = $data->{usernames};
    unless ($usernames && ref($usernames) eq 'ARRAY' && @$usernames > 0) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'No usernames provided'
        }];
    }

    # Validate room
    my $room_title = $data->{room_title};
    unless (defined $room_title && $room_title =~ /\S/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'No room specified'
        }];
    }

    # Resolve room
    my $room = undef;
    my $room_display = '';

    if (lc($room_title) eq 'outside') {
        $room = 0;  # 0 means outside
        $room_display = 'outside';
    } else {
        $room = $DB->getNode($room_title, 'room');
        unless ($room) {
            return [$self->HTTP_OK, {
                success => 0,
                error => "Room \"$room_title\" does not exist"
            }];
        }
        $room_display = $room->{title};
    }

    # Process each username
    my @moved = ();
    my @not_found = ();

    foreach my $username (@$usernames) {
        # Clean up whitespace
        $username =~ s/^\s+|\s+$//g;
        next unless $username =~ /\S/;

        my $user_node = $DB->getNode($username, 'user');
        if ($user_node) {
            $APP->changeRoom($user_node, $room);
            push @moved, $username;
        } else {
            push @not_found, $username;
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        moved => \@moved,
        not_found => \@not_found,
        room_title => $room_display,
        message => scalar(@moved) . ' user(s) moved to ' . $room_display
    }];
}

around ['move_users'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::Page::e2_bouncer>

=cut

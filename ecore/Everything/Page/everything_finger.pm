package Everything::Page::everything_finger;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_finger - Who's online on Everything2

=head1 DESCRIPTION

Displays list of currently logged-in users with their location and status flags.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with list of online users and their metadata.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;

    # Build WHERE clause based on infravision setting
    my $wherestr = '';
    unless ($USER->infravision) {
        $wherestr = 'visible=0';
    }

    # Get all users in rooms, ordered by experience
    my $csr = $DB->sqlSelectMany('*', 'room', $wherestr, 'order by experience DESC');

    my @users;
    my $is_editor = $APP->isEditor($USER);

    while (my $row = $csr->fetchrow_hashref) {
        my $uid = $row->{member_user};
        my $user_node = $DB->getNodeById($uid);

        next unless $user_node;

        # Build flags
        my @flags;

        # Invisible flag
        push @flags, {type => 'invisible', label => 'invis'} if $row->{visible};

        # Role flags
        push @flags, {type => 'admin', label => '@'} if $APP->isAdmin($uid);
        push @flags, {type => 'editor', label => '$'}
            if $APP->isEditor($uid, "nogods") && !$APP->isAdmin($uid);
        push @flags, {type => 'developer', label => '%'}
            if $APP->isDeveloper($uid, "nogods");

        # Newbie days (only shown to editors)
        if ($is_editor && $row->{unixcreatetime}) {
            my $difftime = time() - $row->{unixcreatetime};
            if ($difftime < 60 * 60 * 24 * 30) {  # Within 30 days
                my $days = int($difftime / (60 * 60 * 24)) + 1;
                push @flags, {
                    type => 'newbie',
                    label => $days,
                    highlight => ($days <= 3)  # Highlight first 3 days
                };
            }
        }

        # Get room info
        my $room = undef;
        if ($row->{room_id}) {
            my $room_node = $DB->getNodeById($row->{room_id});
            $room = {
                node_id => $row->{room_id},
                title => $room_node->{title}
            } if $room_node;
        }

        push @users, {
            user_id => $uid,
            username => $user_node->{title},
            nick => $row->{nick},
            flags => \@flags,
            room => $room,
            experience => $row->{experience}
        };
    }

    $csr->finish;

    return {
        type => 'everything_finger',
        users => \@users,
        total => scalar(@users)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

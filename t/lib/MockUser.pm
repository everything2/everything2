package MockUser;

use strict;
use warnings;
use Everything;  # Get access to $DB global

=head1 NAME

MockUser - Mock user object for API testing

=head1 SYNOPSIS

    use lib "$FindBin::Bin/lib";
    use MockUser;

    my $user = MockUser->new(
        node_id => 123,
        title => 'testuser',
        is_admin_flag => 1,
        nodedata => $user_hashref
    );

    if ($user->is_admin) {
        # Admin operations
    }

=head1 DESCRIPTION

MockUser provides a lightweight mock implementation of the Everything::Node::user
interface for use in API tests. It supports all common user methods without
requiring full database initialization.

=head1 METHODS

=head2 new(%args)

Creates a new MockUser instance.

Arguments:
    node_id         - User's node ID (default: 0)
    title           - User's display name (default: 'Guest User')
    is_guest_flag   - Whether user is guest (default: 1)
    is_admin_flag   - Whether user is admin (default: 0)
    is_editor_flag  - Whether user is editor (default: 0)
    is_developer_flag - Whether user is developer (default: 0)
    nodedata        - User's node data hashref (default: {})
    vars            - User's VARS hashref (default: {})
    coolsleft       - Remaining C!s (default: 10)
    votesleft       - Remaining votes (default: 10)
    ignores         - List of ignored users (default: [])

=cut

sub new {
    my ($class, %args) = @_;

    return bless {
        node_id => $args{node_id} // 0,
        title => $args{title} // 'Guest User',
        is_guest_flag => $args{is_guest_flag} // 1,
        is_admin_flag => $args{is_admin_flag} // 0,
        is_editor_flag => $args{is_editor_flag} // 0,
        is_developer_flag => $args{is_developer_flag} // 0,
        _nodedata => $args{nodedata} // {},
        _vars => $args{vars} // {},
        _coolsleft => $args{coolsleft} // 10,
        _votesleft => $args{votesleft} // 10,
        _ignores => $args{ignores} // [],
    }, $class;
}

=head2 Permission Methods

=head3 is_guest()

Returns true if user is a guest (not logged in).

=head3 is_admin()

Returns true if user has admin privileges.

=head3 is_editor()

Returns true if user has editor privileges.

=head3 is_developer()

Returns true if user has developer privileges.

=cut

sub is_guest { return shift->{is_guest_flag}; }
sub is_admin { return shift->{is_admin_flag}; }
sub is_editor { return shift->{is_editor_flag}; }
sub is_developer { return shift->{is_developer_flag}; }

=head2 Core Accessors

=head3 node_id()

Returns the user's node ID.

=head3 title()

Returns the user's display name.

=head3 NODEDATA()

Returns the underlying node data hashref.

=cut

sub node_id { return shift->{node_id}; }
sub title { return shift->{title}; }
sub NODEDATA { return shift->{_nodedata}; }

=head2 User Settings

=head3 VARS()

Returns the user's VARS (preferences) hashref.

=head3 set_vars($vars)

Updates the user's VARS. In the real implementation this would persist
to the database, but the mock just updates the in-memory copy.

=cut

sub VARS { return shift->{_vars}; }

sub set_vars {
    my ($self, $vars) = @_;
    $self->{_vars} = $vars;
    return 1;
}

=head2 Voting/Cool Methods

=head3 coolsleft()

Returns the number of C!s remaining for this user.

=head3 votesleft()

Returns the number of votes remaining for this user.

=cut

sub coolsleft { return shift->{_coolsleft}; }
sub votesleft { return shift->{_votesleft}; }

=head2 Message Ignore Methods

=head3 message_ignores()

Returns arrayref of ignored users.

=head3 set_message_ignore($ignore_id, $should_ignore)

Adds or removes a user from the ignore list.

Arguments:
    $ignore_id      - Node ID of user to ignore/unignore
    $should_ignore  - 1 to ignore, 0 to unignore

Returns:
    When ignoring: hashref with node_id, title, type
    When unignoring: arrayref with just the node_id

=cut

sub message_ignores {
    my $self = shift;
    return $self->{_ignores};
}

sub set_message_ignore {
    my ($self, $ignore_id, $should_ignore) = @_;

    if ($should_ignore) {
        # Add to ignores if not already there
        my $already_ignored = 0;
        foreach my $ig (@{$self->{_ignores}}) {
            if ($ig->{node_id} == $ignore_id) {
                $already_ignored = 1;
                last;
            }
        }

        unless ($already_ignored) {
            my $ignored_node = $DB->getNodeById($ignore_id);
            push @{$self->{_ignores}}, {
                node_id => $ignored_node->{node_id},
                title => $ignored_node->{title},
                type => $ignored_node->{type}{title}
            };
        }

        # Return the ignored user struct
        my $ignored_node = $DB->getNodeById($ignore_id);
        return {
            node_id => $ignored_node->{node_id},
            title => $ignored_node->{title},
            type => $ignored_node->{type}{title}
        };
    } else {
        # Remove from ignores
        my @new_ignores;
        foreach my $ig (@{$self->{_ignores}}) {
            push @new_ignores, $ig unless $ig->{node_id} == $ignore_id;
        }
        $self->{_ignores} = \@new_ignores;

        # Return the unignored ID
        return [$ignore_id];
    }
}

=head3 is_ignoring_messages($ignore_id)

Checks if user is ignoring messages from another user.

Arguments:
    $ignore_id - Node ID of user to check

Returns:
    Hashref of ignored user if ignoring, 0 otherwise

=cut

sub is_ignoring_messages {
    my ($self, $ignore_id) = @_;

    foreach my $ig (@{$self->{_ignores}}) {
        if ($ig->{node_id} == $ignore_id) {
            return $ig;
        }
    }

    return 0;
}

=head1 USAGE EXAMPLES

=head2 Basic Guest User

    my $guest = MockUser->new();
    # All defaults: guest user with no privileges

=head2 Admin User

    my $admin = MockUser->new(
        node_id => 113,
        title => 'root',
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $root_hashref
    );

=head2 User with Limited Votes

    my $user = MockUser->new(
        node_id => 123,
        title => 'testuser',
        is_guest_flag => 0,
        coolsleft => 0,      # No C!s remaining
        votesleft => 5       # 5 votes remaining
    );

=head2 User with Ignores

    my $user = MockUser->new(
        node_id => 123,
        title => 'testuser',
        is_guest_flag => 0,
        ignores => [
            { node_id => 456, title => 'annoying_user', type => 'user' }
        ]
    );

=head1 SEE ALSO

L<MockRequest>, L<Everything::Node::user>

=head1 AUTHOR

Generated for Everything2 API testing infrastructure

=cut

1;

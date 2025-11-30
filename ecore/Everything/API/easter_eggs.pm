package Everything::API::easter_eggs;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 Everything::API::easter_eggs

API for Bestow Easter Eggs - grants easter eggs to users.

Admin only. Each user receives one easter egg and a message from Cool Man Eddie.

=cut

sub routes
{
    return {
        "bestow" => "bestow"
    };
}

sub bestow
{
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;

    # Admin-only endpoint
    unless ($user->is_admin) {
        return [$self->HTTP_FORBIDDEN, { error => 'Who do you think you are? The Easter Bunny?' }];
    }

    my $data = $REQUEST->JSON_POSTDATA;

    # Accept either 'users' (unified format) or 'usernames' (legacy format)
    my @user_entries;
    if ($data->{users} && ref($data->{users}) eq 'ARRAY') {
        @user_entries = @{$data->{users}};
    } elsif ($data->{usernames} && ref($data->{usernames}) eq 'ARRAY') {
        # Convert legacy format to unified format
        @user_entries = map { { username => $_ } } @{$data->{usernames}};
    }

    unless (@user_entries) {
        return [$self->HTTP_BAD_REQUEST, { error => 'No users provided' }];
    }

    my @results = ();

    foreach my $entry (@user_entries) {
        my $username = ref($entry) eq 'HASH' ? $entry->{username} : $entry;
        next unless $username && $username =~ /\S/;

        my $target_user = $self->APP->node_by_name($username, 'user');
        unless ($target_user) {
            push @results, {
                username => $username,
                success => 0,
                error => "User not found: $username"
            };
            next;
        }

        # Get and update user VARS
        my $target_vars = $target_user->VARS;
        $target_vars->{easter_eggs} = ($target_vars->{easter_eggs} || 0) + 1;
        $target_user->set_vars($target_vars);

        # Send notification via Cool Man Eddie
        $self->APP->sendPrivateMessage(
            $target_user->NODEDATA,
            'Far out! Somebody has given you an [easter egg].',
            'Cool Man Eddie'
        );

        my $target_title = $target_user->title;
        push @results, {
            username => $target_title,
            success => 1,
            amount => 1,
            new_total => $target_vars->{easter_eggs},
            message => "User $target_title was given 1 easter egg (now has $target_vars->{easter_eggs} eggs)"
        };
    }

    return [$self->HTTP_OK, { results => \@results }];
}

__PACKAGE__->meta->make_immutable;

1;

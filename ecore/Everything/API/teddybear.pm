package Everything::API::teddybear;

use Moose;
extends 'Everything::API';

=head1 Everything::API::teddybear

API for Giant Teddy Bear Suit - allows admins to hug users with GP grants.

Migrated from document.pm giant_teddy_bear_suit() delegation function.

=cut

sub routes
{
    return {
        "hug" => "hug"
    };
}

=head2 hug

Grant GP to users via Giant Teddy Bear hug.

POST /api/teddybear/hug

Unified format:
{
  "users": [
    {"username": "user1"},
    {"username": "user2"}
  ]
}

Legacy format (still supported):
{
  "usernames": ["user1", "user2", "user3"]
}

Returns:
{
  "success": true,
  "results": [
    {"username": "user1", "success": true, "amount": 2, "message": "User user1 was given 2 GP"}
  ]
}

=cut

sub hug
{
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Only admins can use the Giant Teddy Bear Suit
    unless ($APP->isAdmin($USER)) {
        return [$self->HTTP_FORBIDDEN, {
            error => 'Hands off the bear, bobo.',
            message => 'Only administrators can use the Giant Teddy Bear Suit'
        }];
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
        return [$self->HTTP_BAD_REQUEST, {
            error => 'No users provided',
            message => 'Please provide an array of users to hug'
        }];
    }

    # Giant Teddy Bear grants fixed 2 GP per hug
    my $gp_amount = 2;

    my @results;

    # Get Giant Teddy Bear user for chatbox messages
    my $teddy_bear_user = $DB->getNode('Giant Teddy Bear', 'user');
    my $teddy_bear_id = $teddy_bear_user ? $teddy_bear_user->{node_id} : undef;

    foreach my $entry (@user_entries) {
        my $username = ref($entry) eq 'HASH' ? $entry->{username} : $entry;
        next unless $username;

        my $target_user = $DB->getNode($username, 'user');

        if (!$target_user) {
            push @results, {
                username => $username,
                success => 0,
                error => "User not found: $username"
            };
            next;
        }

        # Post hug message to public chatter
        if ($teddy_bear_id) {
            $DB->sqlInsert('message', {
                msgtext => '/me hugs ' . $target_user->{title},
                author_user => $teddy_bear_id,
                for_user => 0,  # 0 is public
                room => $USER->{in_room} || 0  # Default to outside
            });
        }

        # Grant GP
        $APP->adjustGP($target_user, $gp_amount);

        # Increase karma
        $target_user->{karma} += 1;
        $DB->updateNode($target_user, -1);

        # Security log
        $APP->securityLog(
            $DB->getNode('Superbless', 'superdoc'),
            $USER,
            "$USER->{title} hugged $target_user->{title} using the [Giant Teddy Bear suit] for $gp_amount GP."
        );

        # Check for karma achievements
        $APP->checkAchievementsByType('karma', $target_user->{user_id});

        push @results, {
            username => $target_user->{title},
            success => 1,
            amount => $gp_amount,
            message => "User $target_user->{title} was given $gp_amount GP"
        };
    }

    return [$self->HTTP_OK, {
        success => 1,
        results => \@results
    }];
}

__PACKAGE__->meta->make_immutable;
1;

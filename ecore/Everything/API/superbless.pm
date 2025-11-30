package Everything::API::superbless;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 Everything::API::superbless

Unified API for admin resource granting functions.

Handles GP, XP, cools, and other admin-only resource grants.

=cut

sub routes
{
    return {
        "grant_gp" => "grant_gp",
        "grant_xp" => "grant_xp",
        "grant_cools" => "grant_cools",
        "fiery_hug" => "fiery_hug"
    };
}

=head2 grant_gp

Grant GP to users (Superbless). Editors and above can use this.

POST /api/superbless/grant_gp
{
  "users": [
    {"username": "user1", "amount": 10},
    {"username": "user2", "amount": 5}
  ]
}

=cut

sub grant_gp
{
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Editors and above can superbless GP
    unless ($APP->isEditor($USER)) {
        return [$self->HTTP_FORBIDDEN, {
            error => 'You have not yet learned that spell.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;
    my $users = $data->{users} || [];

    unless (@$users) {
        return [$self->HTTP_BAD_REQUEST, {
            error => 'No users provided'
        }];
    }

    my @results;

    foreach my $entry (@$users) {
        my $username = $entry->{username};
        my $amount = $entry->{amount};

        next unless $username;

        # Validate amount is a number (positive or negative allowed)
        unless (defined $amount && $amount =~ /^-?\d+$/) {
            push @results, {
                username => $username,
                success => 0,
                error => "Invalid GP value: $amount"
            };
            next;
        }

        my $target_user = $DB->getNode($username, 'user');

        if (!$target_user) {
            push @results, {
                username => $username,
                success => 0,
                error => "User not found: $username"
            };
            next;
        }

        # If superblessing yourself, use current USER to ensure session updates
        if ($target_user->{node_id} == $USER->{node_id}) {
            $target_user = $USER;
        }

        # Grant/remove GP
        $APP->adjustGP($target_user, $amount);

        # Adjust karma based on direction
        my $signum = ($amount > 0) ? 1 : (($amount < 0) ? -1 : 0);
        if ($signum != 0) {
            $target_user->{karma} += $signum;
            $DB->updateNode($target_user, -1);
            $APP->checkAchievementsByType('karma', $target_user->{user_id});
        }

        # Security log
        $APP->securityLog(
            $DB->getNode('Superbless', 'superdoc'),
            $USER,
            "$target_user->{title} was superblessed $amount GP by $USER->{title}"
        );

        my $new_gp = $target_user->{GP} || 0;
        push @results, {
            username => $target_user->{title},
            success => 1,
            amount => $amount,
            new_total => $new_gp,
            message => "User $target_user->{title} was given $amount GP (now has $new_gp GP)"
        };
    }

    return [$self->HTTP_OK, { results => \@results }];
}

=head2 grant_xp

Grant XP to users (XP Superbless). Admin only - archived/emergency use.

POST /api/superbless/grant_xp
{
  "users": [
    {"username": "user1", "amount": 100}
  ]
}

=cut

sub grant_xp
{
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Admin only for XP grants
    unless ($APP->isAdmin($USER)) {
        return [$self->HTTP_FORBIDDEN, {
            error => 'Only administrators can grant XP.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;
    my $users = $data->{users} || [];

    unless (@$users) {
        return [$self->HTTP_BAD_REQUEST, {
            error => 'No users provided'
        }];
    }

    my @results;

    foreach my $entry (@$users) {
        my $username = $entry->{username};
        my $amount = $entry->{amount};

        next unless $username;

        # Validate amount
        unless (defined $amount && $amount =~ /^-?\d+$/) {
            push @results, {
                username => $username,
                success => 0,
                error => "Invalid XP value: $amount"
            };
            next;
        }

        my $target_user = $DB->getNode($username, 'user');

        if (!$target_user) {
            push @results, {
                username => $username,
                success => 0,
                error => "User not found: $username"
            };
            next;
        }

        # Adjust XP
        $APP->adjustExp($target_user, $amount);

        # Adjust karma based on direction
        my $signum = ($amount > 0) ? 1 : (($amount < 0) ? -1 : 0);
        if ($signum != 0) {
            $target_user->{karma} += $signum;
            $DB->updateNode($target_user, -1);
            $APP->checkAchievementsByType('karma', $target_user->{user_id});
        }

        # Security log
        $APP->securityLog(
            $DB->getNode('XP Superbless', 'superdoc'),
            $USER,
            "$target_user->{title} was superblessed $amount XP by $USER->{title}"
        );

        my $new_xp = $target_user->{experience} || 0;
        push @results, {
            username => $target_user->{title},
            success => 1,
            amount => $amount,
            new_total => $new_xp,
            message => "User $target_user->{title} was given $amount XP (now has $new_xp XP)"
        };
    }

    return [$self->HTTP_OK, { results => \@results }];
}

=head2 grant_cools

Grant cools (chings) to users. Admin only.

POST /api/superbless/grant_cools
{
  "users": [
    {"username": "user1", "amount": 5}
  ]
}

=cut

sub grant_cools
{
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->VARS;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Admin only
    unless ($APP->isAdmin($USER)) {
        return [$self->HTTP_FORBIDDEN, {
            error => 'Only administrators can bestow cools.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;
    my $users = $data->{users} || [];

    unless (@$users) {
        return [$self->HTTP_BAD_REQUEST, {
            error => 'No users provided'
        }];
    }

    my @results;

    foreach my $entry (@$users) {
        my $username = $entry->{username};
        my $amount = $entry->{amount};

        next unless $username;

        # Validate amount (positive only for cools)
        unless (defined $amount && $amount =~ /^\d+$/ && $amount > 0) {
            push @results, {
                username => $username,
                success => 0,
                error => "Invalid cools value: $amount (must be positive)"
            };
            next;
        }

        my $target_user = $DB->getNode($username, 'user');

        if (!$target_user) {
            push @results, {
                username => $username,
                success => 0,
                error => "User not found: $username"
            };
            next;
        }

        # Check if bestowing on yourself
        my $is_self = ($target_user->{node_id} == $USER->{node_id});

        if ($is_self) {
            # Modify in-scope VARS for current user
            $VARS->{cools} = ($VARS->{cools} || 0) + $amount;
            $USER->{karma} += 1;

            $APP->securityLog(
                $DB->getNode('Bestow Cools', 'restricted_superdoc'),
                $USER,
                "$USER->{title} bestowed $amount cools to themselves"
            );

            push @results, {
                username => $USER->{title},
                success => 1,
                amount => $amount,
                new_total => $VARS->{cools},
                message => "$amount cools were bestowed to you (now have $VARS->{cools} cools)"
            };
        } else {
            # Get target user's vars and update
            my $target_vars = $DB->getVars($target_user);
            $target_vars->{cools} = ($target_vars->{cools} || 0) + $amount;
            $DB->setVars($target_user, $target_vars);

            $target_user->{karma} += 1;
            $DB->updateNode($target_user, -1);

            $APP->securityLog(
                $DB->getNode('Bestow Cools', 'restricted_superdoc'),
                $USER,
                "$target_user->{title} was given $amount cools by $USER->{title}"
            );

            push @results, {
                username => $target_user->{title},
                success => 1,
                amount => $amount,
                new_total => $target_vars->{cools},
                message => "$amount cools were bestowed to $target_user->{title} (now has $target_vars->{cools} cools)"
            };
        }
    }

    return [$self->HTTP_OK, { results => \@results }];
}

=head2 fiery_hug

Curse users with -1 GP via Fiery Teddy Bear Suit. Admin only.
Posts public hug message to chatterbox from Fiery Teddy Bear.

POST /api/superbless/fiery_hug
{
  "users": [
    {"username": "user1"},
    {"username": "user2"}
  ]
}

=cut

sub fiery_hug
{
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Admin only
    unless ($APP->isAdmin($USER)) {
        return [$self->HTTP_FORBIDDEN, {
            error => 'Hands off the bear, bobo.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;
    my $users = $data->{users} || [];

    unless (@$users) {
        return [$self->HTTP_BAD_REQUEST, {
            error => 'No users provided'
        }];
    }

    # Fiery Teddy Bear always curses with -1 GP
    my $gp_penalty = 1;

    my @results;

    # Get Fiery Teddy Bear user for chatbox messages
    my $fiery_teddy = $DB->getNode('Fiery Teddy Bear', 'user');
    my $fiery_teddy_id = $fiery_teddy ? $fiery_teddy->{node_id} : undef;

    foreach my $entry (@$users) {
        my $username = $entry->{username};

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
        if ($fiery_teddy_id) {
            $DB->sqlInsert('message', {
                msgtext => '/me hugs ' . $target_user->{title},
                author_user => $fiery_teddy_id,
                for_user => 0,  # 0 is public
                room => $USER->{in_room} || 0
            });
        }

        # Remove GP (penalty)
        $APP->adjustGP($target_user, -$gp_penalty);

        # Decrease karma
        $target_user->{karma} -= 1;
        $DB->updateNode($target_user, -1);

        # Security log
        $APP->securityLog(
            $DB->getNode('Superbless', 'superdoc'),
            $USER,
            "$USER->{title} hugged $target_user->{title} using the [Fiery Teddy Bear suit] for negative $gp_penalty GP."
        );

        push @results, {
            username => $target_user->{title},
            success => 1,
            amount => -$gp_penalty,
            message => "User $target_user->{title} lost $gp_penalty GP"
        };
    }

    return [$self->HTTP_OK, { results => \@results }];
}

__PACKAGE__->meta->make_immutable;

1;

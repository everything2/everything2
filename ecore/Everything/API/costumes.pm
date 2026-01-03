package Everything::API::costumes;

use Moose;
extends 'Everything::API';

sub routes {
    return {
        'buy'    => 'buy_costume',
        'remove' => 'remove_costume',
    };
}

sub buy_costume {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $VARS = $user->VARS;
    my $USER_DATA = $user->NODEDATA;

    # Check if Halloween period (uses centralized method from Application.pm)
    my $is_halloween = $APP->inHalloweenPeriod();
    return [$self->HTTP_OK, {success => 0, error => "The shop is closed. Check back on All Hallows' Eve."}]
        unless $is_halloween;

    my $data = $REQUEST->JSON_POSTDATA;
    my $costume = $data->{costume} // '';

    # Clean costume name
    $costume =~ s/[\[\]<>&]//g;
    $costume =~ s/^\s+|\s+$//g;

    return [$self->HTTP_OK, {success => 0, error => 'Please enter a costume name'}]
        unless length($costume) > 0;

    return [$self->HTTP_OK, {success => 0, error => 'Costume name too long (max 40 characters)'}]
        if length($costume) > 40;

    # Check if costume name conflicts with existing user
    my $user_type = $DB->getType('user');
    my $user_check = $DB->getNode($costume, $user_type);

    return [$self->HTTP_OK, {success => 0, error => 'That costume is also a username! Please try another option.'}]
        if $user_check;

    # Calculate cost (free for admins)
    my $costume_cost = $user->is_admin ? 0 : 30;
    my $user_gp = int($USER_DATA->{GP} || 0);

    return [$self->HTTP_OK, {success => 0, error => "Not enough GP. You need $costume_cost GP."}]
        if $user_gp < $costume_cost;

    # Apply costume
    $VARS->{costume} = $costume;
    $VARS->{treats} = 0;  # Reset treats counter

    # Deduct GP
    if ($costume_cost > 0) {
        $APP->adjustGP($USER_DATA, -$costume_cost);
    }

    # Save vars
    $user->set_vars($VARS);

    my $new_gp = int($USER_DATA->{GP} || 0);

    return [$self->HTTP_OK, {
        success => 1,
        message => "You're now dressed as \"$costume\"!",
        newCostume => $costume,
        newGP => $new_gp,
    }];
}

sub remove_costume {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;

    my $APP = $self->APP;
    my $DB = $self->DB;

    # Only editors can remove costumes
    return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}]
        unless $APP->isEditor($user->NODEDATA);

    my $data = $REQUEST->JSON_POSTDATA;
    my $username = $data->{username} // '';

    return [$self->HTTP_OK, {success => 0, error => 'Username is required'}]
        unless length($username) > 0;

    # Find the user
    my $target_user = $DB->getNode($username, 'user');

    return [$self->HTTP_OK, {success => 0, error => "User '$username' not found"}]
        unless $target_user;

    my $target_vars = $APP->getVars($target_user);

    # Check if they have a costume
    return [$self->HTTP_OK, {success => 0, error => "User '$username' is not wearing a costume"}]
        unless defined $target_vars->{costume};

    my $old_costume = $target_vars->{costume};

    # Remove the costume
    delete $target_vars->{costume};
    Everything::setVars($target_user, $target_vars);
    $DB->updateNode($target_user, -1);

    # Send a notification message from Klaproth
    my $klaproth = $DB->getNode('Klaproth', 'user');
    if ($klaproth) {
        $APP->sendPrivateMessage(
            $klaproth,
            { user_id => $target_user->{node_id} },
            'Hey, your costume has been removed because it was deemed abusive. Please choose your costume more carefully next time, or you will lose costume-wearing privileges.'
        );
    }

    return [$self->HTTP_OK, {
        success     => 1,
        message     => "Removed costume \"$old_costume\" from $username",
        username    => $target_user->{title},
        oldCostume  => $old_costume,
    }];
}

__PACKAGE__->meta->make_immutable;

1;

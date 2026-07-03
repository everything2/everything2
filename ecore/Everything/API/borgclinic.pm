package Everything::API::borgclinic;

use Moose;
extends 'Everything::API';

# POST /api/borgclinic/setborg -- admin-only borg-count setter (#4449, Refs #4298).
# Replaces the render-time setVars(numborged) in Everything::Page::the_borg_clinic,
# which wrote a user's vars off query params during buildReactData. A user stays
# borged 4 + 2*numborged minutes; negatives are "borg insurance" (instant unborg).

sub routes {
    return { 'setborg' => 'set_borg_count' };
}

sub set_borg_count {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $data   = $REQUEST->JSON_POSTDATA;
    my $target = $data->{user};
    my $count  = $data->{count};

    return [$self->HTTP_OK, {success => 0, error => 'A user is required'}]
        unless (defined $target && length $target);

    # Integer (negatives allowed for "borg insurance").
    return [$self->HTTP_OK, {success => 0, error => 'Borg count must be an integer'}]
        unless (defined $count && $count =~ /^-?\d+$/);

    my $target_user = $self->DB->getNode($target, 'user');
    return [$self->HTTP_OK, {success => 0, error => "User not found: $target"}]
        unless $target_user;

    # Read-modify-write so only numborged changes (a bare setVars of a single key
    # would wipe the rest of the user's vars).
    my $vars = $self->APP->getVars($target_user);
    $vars->{numborged} = int($count);
    Everything::setVars($target_user, $vars);
    $self->DB->updateNode($target_user, -1);

    $self->APP->devLog(
        "Borg Clinic: " . $user->title . " set numborged=" . int($count)
        . " on user " . $target_user->{title});

    return [$self->HTTP_OK, {
        success    => 1,
        user       => $target_user->{title},
        user_id    => int($target_user->{node_id}),
        borg_count => int($count),
    }];
}

__PACKAGE__->meta->make_immutable;

1;

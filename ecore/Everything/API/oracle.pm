package Everything::API::oracle;

use Moose;
extends 'Everything::API';

# POST /api/oracle/setvar -- admin-only raw user-var editor (#4405). Replaces the
# legacy render-time mutation in Everything::Page::the_oracle, which wrote ANOTHER
# user's vars off query params during buildReactData. The Oracle is the one
# sanctioned place to set an arbitrary var, so the power is contained in this
# single auditable endpoint and gated to gods -- deliberately NOT a generic
# "set any var" primitive, and NOT the allowlisted preferences API.

sub routes {
    return { 'setvar' => 'set_user_var' };
}

sub set_user_var {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $data   = $REQUEST->JSON_POSTDATA;
    my $target = $data->{user};
    my $var    = $data->{var};
    my $value  = $data->{value};
    $value = '' unless defined $value;

    unless (defined $target && length $target && defined $var && length $var) {
        return [$self->HTTP_OK,
            {success => 0, error => 'A user and a variable name are required'}];
    }

    my $target_user = $self->DB->getNode($target, 'user');
    return [$self->HTTP_OK, {success => 0, error => "User not found: $target"}]
        unless $target_user;

    # Read-modify-write so only the one key changes (a bare setVars of a single
    # key would wipe the rest of the user's vars).
    my $vars = $self->APP->getVars($target_user);
    $vars->{$var} = $value;
    Everything::setVars($target_user, $vars);
    $self->DB->updateNode($target_user, -1);

    # Audit the write (admin + var + target) to the dev log. Deliberately not a
    # node note: we just cleaned up Recent Node Notes, and the value can be
    # sensitive -- securityLog is the better home if a durable channel is wanted.
    $self->APP->devLog(
        "Oracle: " . $user->title . " set var '$var' on user " . $target_user->{title});

    return [$self->HTTP_OK, {
        success => 1,
        user    => $target_user->{title},
        var     => $var,
        value   => $value,
    }];
}

__PACKAGE__->meta->make_immutable;

1;

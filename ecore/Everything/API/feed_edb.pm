package Everything::API::feed_edb;

use Moose;
extends 'Everything::API';

=head1 Everything::API::feed_edb

Backs the Feed EDB admin tool ("simulate being borged by EDB"). The borg/unborg
self-mutation used to run as a side effect inside the page controller on a
C<?numborgings=N> query param; it now lives here as C<POST /api/feed_edb/borg> so the
page controller can be a pure-render resolver (#4390 / roadmap step 2 — every mutating
action becomes a React-driven API call).

=cut

sub routes {
    return {
        'borg' => 'set_borgings',
    };
}

# POST /api/feed_edb/borg  { numborgings: <int> }
# Borg (t>0) / unborg (t<=0) the admin themselves: writes their numborged/borged VARS and
# flips room.borgd. Admin-only -- this is a debug/simulation toy for editors playing with EDB.
sub set_borgings {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Login required'}]
        if $user->is_guest;
    return [$self->HTTP_OK, {success => 0, error => 'Admins only'}]
        unless $user->is_admin;

    my $DB        = $self->DB;
    my $VARS      = $user->VARS;
    my $USER_DATA = $user->NODEDATA;
    my $UID       = $USER_DATA->{node_id};

    my $data = $REQUEST->JSON_POSTDATA;
    my $numborgings = $data->{numborgings};
    return [$self->HTTP_OK, {success => 0, error => 'numborgings must be an integer'}]
        unless defined $numborgings && $numborgings =~ /^-?\d+$/;
    my $t = int($numborgings);

    my $message;
    if ($t > 0) {
        # Borg self
        $VARS->{numborged} = $t;
        $VARS->{borged}    = time;
        $message = "Simulating being borged $t time" . ($t == 1 ? '' : 's') . ".";
        $DB->sqlUpdate('room', {borgd => 1}, "member_user=$UID");
    } else {
        # Unborg self (t == 0 -> unborged; t < 0 -> borg-proof)
        delete $VARS->{borged};
        $VARS->{numborged} = $t;
        if ($t == 0) {
            $message = 'Unborged.';
        } else {
            my $abs_t = -$t;
            $message = "Borg-proof $abs_t time" . ($t == -1 ? '' : 's') . ".";
        }
        $DB->sqlUpdate('room', {borgd => 0}, "member_user=$UID");
    }

    $user->set_vars($VARS);

    # Return $t (the count we just set), NOT a re-read of $VARS->{numborged}: the VARS storage
    # round-trips a stored 0 back into " " (a space), and "$VARS->{numborged} || 0" would then
    # surface that truthy space instead of falling through to 0 -> React renders it blank. (#4390)
    return [$self->HTTP_OK, {
        success       => 1,
        message       => $message,
        current_count => $t,
    }];
}

__PACKAGE__->meta->make_immutable;

1;

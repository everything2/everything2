package Everything::Page::e2_penny_jar;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::e2_penny_jar - E2 Penny Jar

=head1 DESCRIPTION

A community GP sharing feature. Users can give or take a penny (1 GP) from a shared jar.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with penny jar state and handles give/take actions.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $query = $REQUEST->cgi;
    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;
    my $VARS = $APP->getVars($USER);

    # Check if guest
    if ($APP->isGuest($USER)) {
        return {
            type => 'e2_penny_jar',
            error => 'You must be logged in to touch the pennies.',
            user_gp => 0,
            pennies_in_jar => 0,
            can_interact => 0
        };
    }

    # Check if GP opt-out
    if ($VARS->{GPoptout}) {
        return {
            type => 'e2_penny_jar',
            error => 'Sorry, it seems you are not interested in pennies right now.',
            user_gp => $USER->{GP} || 0,
            pennies_in_jar => 0,
            can_interact => 0
        };
    }

    # Get penny jar setting
    my $pennynode = $DB->getNode('penny jar', 'setting');
    my $pennies = $APP->getVars($pennynode);
    my $pennies_count = $pennies->{1} || 0;

    my $message = '';
    my $action_taken = 0;

    # Handle give action
    if ($query->param('give')) {
        if ($USER->{GP} < 1) {
            $message = 'Sorry, you do not have any GP to give!';
        } else {
            $pennies->{1}++;
            $pennies_count = $pennies->{1};
            Everything::setVars($pennynode, $pennies);
            $DB->updateNode($pennynode, -1);
            $APP->adjustGP($USER, -1);
            $message = 'You gave a penny to the jar!';
            $action_taken = 1;
        }
    }

    # Handle take action
    if ($query->param('take')) {
        if ($pennies_count < 1) {
            $message = 'Sorry, there are no more pennies in the jar! Would you like to donate one?';
        } else {
            $pennies->{1}--;
            $pennies_count = $pennies->{1};
            Everything::setVars($pennynode, $pennies);
            $DB->updateNode($pennynode, -1);
            $APP->adjustGP($USER, 1);
            $message = 'You took a penny from the jar!';
            $action_taken = 1;
        }
    }

    # Refresh user GP if action was taken
    my $user_gp = $USER->{GP} || 0;
    if ($action_taken) {
        my $refreshed_user = $DB->getNodeById($USER->{node_id});
        $user_gp = $refreshed_user->{GP} || 0;
    }

    return {
        type => 'e2_penny_jar',
        user_gp => $user_gp,
        pennies_in_jar => $pennies_count,
        can_interact => 1,
        message => $message
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

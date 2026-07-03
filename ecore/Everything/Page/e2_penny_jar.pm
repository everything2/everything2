package Everything::Page::e2_penny_jar;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::e2_penny_jar - E2 Penny Jar

=head1 DESCRIPTION

A community GP sharing feature. Users can give or take a penny (1 GP) from a shared jar.

=head1 METHODS

=head2 buildReactData($REQUEST)

Pure-render: returns the current penny jar state (user GP + jar count). The give/take
WRITE moved to POST /api/e2_penny_jar/give|take (Everything::API::e2_penny_jar, #4453,
Refs #4298), so this page no longer mutates off C<give>/C<take> query params.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
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

    # Get penny jar setting (current jar count lives in the setting vars under key '1')
    my $pennynode = $DB->getNode('penny jar', 'setting');
    my $pennies = $APP->getVars($pennynode);
    my $pennies_count = $pennies->{1} || 0;

    return {
        type => 'e2_penny_jar',
        user_gp => $USER->{GP} || 0,
        pennies_in_jar => $pennies_count,
        can_interact => 1
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

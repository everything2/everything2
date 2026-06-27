package Everything::Page::the_costume_shop;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $VARS = $USER->VARS;

    # Check if Halloween period (uses centralized method from Application.pm)
    my $is_halloween = $APP->inHalloweenPeriod();

    my $user_gp = int($USER->NODEDATA->{GP} || 0);
    my $is_admin = $USER->is_admin;
    my $costume_cost = $is_admin ? 0 : 30;
    my $current_costume = $VARS->{costume} // '';

    return {
        # isAdmin + userGP dropped: they duplicate e2.user.admin / e2.user.gp, which the React
        # component reads from the `user` prop. $is_admin/$user_gp still drive the server-side
        # cost + affordability below. (#4390)
        costumeShop => {
            isHalloween     => $is_halloween ? \1 : \0,
            costumeCost     => $costume_cost,
            currentCostume  => $current_costume,
            hasCostume      => $current_costume ? \1 : \0,
            canAfford       => ($user_gp >= $costume_cost) ? \1 : \0,
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;

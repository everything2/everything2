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
        costumeShop => {
            isHalloween     => $is_halloween ? \1 : \0,
            isAdmin         => $is_admin ? \1 : \0,
            userGP          => $user_gp,
            costumeCost     => $costume_cost,
            currentCostume  => $current_costume,
            hasCostume      => $current_costume ? \1 : \0,
            canAfford       => ($user_gp >= $costume_cost) ? \1 : \0,
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;

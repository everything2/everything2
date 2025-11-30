package Everything::Page::decloaker;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $APP  = $REQUEST->APP;
    my $user = $REQUEST->user;

    if ( $APP->isGuest( $user->NODEDATA ) ) {
        return {
            success => 0,
            message => 'The Treaty of Algeron prohibits your presence.'
        };
    }

    # React component will call /api/chatroom/set_cloaked to uncloak
    # and update global state
    return {
        success => 1,
        message => 'Uncloaking...'
    };
}

__PACKAGE__->meta->make_immutable;

1;

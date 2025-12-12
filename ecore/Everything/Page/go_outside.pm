package Everything::Page::go_outside;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::go_outside

React page for Go Outside - moves user to "outside" room (room 0).

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $VARS  = $APP->getVars( $USER->NODEDATA );

    # Guest users cannot use this
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type    => 'go_outside',
            success => 0,
            message => 'Guests cannot change rooms.'
        };
    }

    # Check if user is locked in
    my $is_cool_person = $APP->isEditor( $USER->NODEDATA ) || $APP->isChanop( $USER->NODEDATA );
    my $locked_in = $VARS->{lockedin} || 0;

    if ( $locked_in > time && !$is_cool_person ) {
        my $remaining_time = int( ( $locked_in - time ) / 60 + 0.5 );
        return {
            type           => 'go_outside',
            success        => 0,
            locked_in      => 1,
            remaining_time => $remaining_time,
            message        => "You cannot change rooms for $remaining_time minutes. You can still send private messages, however, or talk to people in your current room."
        };
    }

    # Move user outside
    $APP->changeRoom( $USER->NODEDATA, 0 );

    return {
        type    => 'go_outside',
        success => 1,
        message => 'You step outside. You see many noders here.'
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

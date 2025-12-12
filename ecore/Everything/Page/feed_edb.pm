package Everything::Page::feed_edb;

use Moose;
extends 'Everything::Page';

use Everything qw(getId getVars setVars);

=head1 Everything::Page::feed_edb

React page for Feed EDB - admin tool to simulate being borged by EDB.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $VARS  = $APP->getVars( $USER->NODEDATA );

    my $UID = getId( $USER->NODEDATA );
    my $is_admin = $APP->isAdmin( $USER->NODEDATA );

    # Non-admins escape EDB
    unless ( $is_admin ) {
        return {
            type       => 'feed_edb',
            is_admin   => 0,
            message    => "You narrowly escape EDB's mouth."
        };
    }

    my $message = '';
    my $action_taken = 0;

    # Handle numborgings parameter
    my $numborgings = $query->param('numborgings');
    if ( defined $numborgings && $numborgings =~ /^(-?\d+)$/ ) {
        my $t = $1 || 0;
        $action_taken = 1;

        if ( $t > 0 ) {
            # Borg self
            $VARS->{numborged} = $t;
            $VARS->{borged} = time;
            $message = "Simulating being borged $t time" . ( $t == 1 ? '' : 's' ) . ".";
            $DB->sqlUpdate( 'room', { borgd => 1 }, "member_user=$UID" );
        } else {
            # Unborg self
            delete $VARS->{borged};
            $VARS->{numborged} = $t;

            if ( $t == 0 ) {
                $message = 'Unborged.';
            } else {
                my $abs_t = -$t;
                $message = "Borg-proof $abs_t time" . ( $t == -1 ? '' : 's' ) . ".";
            }
            $DB->sqlUpdate( 'room', { borgd => 0 }, "member_user=$UID" );
        }

        setVars( $USER->NODEDATA, $VARS );
    }

    return {
        type          => 'feed_edb',
        is_admin      => 1,
        current_count => $VARS->{numborged} || 0,
        action_taken  => $action_taken,
        message       => $message,
        borg_options  => [ -100, -10, -2, -1, 0, 1, 2, 5, 10, 25, 50, 100 ]
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

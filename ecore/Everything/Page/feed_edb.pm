package Everything::Page::feed_edb;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::feed_edb

React page for Feed EDB - admin tool to simulate being borged by EDB. The borg/unborg
self-mutation moved to Everything::API::feed_edb (POST /api/feed_edb/borg); this controller
is now a pure-render resolver -- no side effects in buildReactData (#4390 / roadmap step 2).

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;
    my $VARS = $APP->getVars( $USER->NODEDATA );

    # Non-admins escape EDB
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type    => 'feed_edb',
            message => "You narrowly escape EDB's mouth."
        };
    }

    # numborged round-trips through VARS storage as " " (a truthy space) when it's 0, so a plain
    # "|| 0" would surface the space rather than 0 -> blank in React. Coerce to an integer. (#4390)
    my $count = ( $VARS->{numborged} // '' ) =~ /^(-?\d+)$/ ? $1 : 0;

    return {
        type          => 'feed_edb',
        current_count => $count,
        borg_options  => [ -100, -10, -2, -1, 0, 1, 2, 5, 10, 25, 50, 100 ]
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

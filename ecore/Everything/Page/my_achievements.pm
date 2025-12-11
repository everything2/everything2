package Everything::Page::my_achievements;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::my_achievements

React page for My Achievements - displays user's earned and available achievements.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Guest check
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type  => 'my_achievements',
            guest => 1
        };
    }

    my $user_id = $USER->node_id;

    # Get all achievements with user's progress
    my $csr = $DB->sqlSelectMany(
        'achievement_id, display, achievement_still_available, achievement_type, subtype, achieved_achievement',
        'achievement LEFT OUTER JOIN achieved ON achieved_achievement=achievement_id AND achieved_user=?',
        '',
        'ORDER BY achievement_type, subtype DESC',
        [ $user_id ]
    );

    my @achieved = ();
    my @unachieved = ();

    while ( my $row = $csr->fetchrow_hashref ) {
        my $achievement = {
            id => $row->{achievement_id},
            display => $row->{display},
            type => $row->{achievement_type},
            subtype => $row->{subtype}
        };

        if ( $row->{achieved_achievement} ) {
            push @achieved, $achievement;
        } elsif ( $row->{achievement_still_available} ) {
            push @unachieved, $achievement;
        }
    }

    my $achieved_count = scalar @achieved;
    my $total_count = $achieved_count + scalar @unachieved;

    # Check for debug mode (edev only)
    my $debug_mode = 0;
    if ( $query->param('debug') ) {
        my $edev_group = $DB->getNode( 'edev', 'usergroup' );
        if ( $edev_group && $DB->isApproved( $USER->NODEDATA, $edev_group ) ) {
            $debug_mode = 1;
        }
    }

    my $debug_data = {};
    if ( $debug_mode ) {
        # Get achievement counts by type
        $debug_data = $self->getAchievementDebugData( $user_id );
    }

    return {
        type => 'my_achievements',
        achieved => \@achieved,
        unachieved => \@unachieved,
        achieved_count => $achieved_count,
        total_count => $total_count,
        debug_mode => $debug_mode,
        debug_data => $debug_data
    };
}

=head2 getAchievementDebugData

Gets achievement counts by type for debug mode.

=cut

sub getAchievementDebugData
{
    my ( $self, $user_id ) = @_;

    my $DB = $self->DB;
    my %debug = ();

    my @types = qw(user usergroup miscellaneous reputation cool vote karma experience writeup);

    foreach my $type (@types) {
        my $achieved = $DB->sqlSelect(
            'COUNT(*)',
            'achievement JOIN achieved ON achievement_id=achieved_achievement',
            'achievement_type=? AND achieved_user=?',
            '',
            [ $type, $user_id ]
        ) || 0;

        my $total = $DB->sqlSelect(
            'COUNT(*)',
            'achievement',
            'achievement_type=? AND achievement_still_available=1',
            '',
            [ $type ]
        ) || 0;

        $debug{$type} = {
            achieved => $achieved,
            total => $total
        };
    }

    return \%debug;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

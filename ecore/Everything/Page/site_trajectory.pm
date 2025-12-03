package Everything::Page::site_trajectory;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::site_trajectory

React page for Site Trajectory - historical site statistics.

Displays monthly statistics for new writeups, contributing users, and C!s spent.
Uses the same React component as Site Trajectory 2.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Get current year
    my (undef, undef, undef, undef, undef, $year) = gmtime(time);
    $year += 1900;

    # Get back_to_year parameter (default to 5 years ago)
    my $back_to_year = int($REQUEST->param("y") || ($year - 5));

    # Minimum year is 1999
    $back_to_year = 1999 if $back_to_year < 1999;

    return {
        type => 'site_trajectory',
        back_to_year => $back_to_year,
        current_year => $year
    };
}

__PACKAGE__->meta->make_immutable;

1;

package Everything::API::trajectory;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 Everything::API::trajectory

API for Site Trajectory - historical site statistics by month.

=cut

sub routes
{
    return {
        "get_data" => "get_data"
    };
}

=head2 get_data

Get site trajectory data (monthly writeups, users, cools).

GET /api/trajectory/get_data?back_to_year=2020

Returns monthly statistics from specified year to present.

=cut

sub get_data
{
    my ($self, $REQUEST) = @_;

    my $USER = $REQUEST->user->NODEDATA;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Block guest users
    if ($APP->isGuest($USER)) {
        return [$self->HTTP_FORBIDDEN, {
            error => 'You must be logged in to view site trajectory data.'
        }];
    }

    # Get current date
    my ($sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst) = gmtime(time);
    $year += 1900;

    # Get back_to_year parameter (default to 5 years ago)
    my $back_to_year = int($REQUEST->param("back_to_year") || ($year - 5));

    # Minimum year is 1999 (when E2 started)
    $back_to_year = 1999 if $back_to_year < 1999;

    my @data;
    my $current_year = $year;
    my $current_month = $month;

    # Get node type IDs
    my $writeup_type_id = $DB->getType('writeup')->{node_id};

    # Loop through months from now back to back_to_year
    while ($current_year >= $back_to_year) {
        my $str_month = sprintf("%02d", $current_month + 1);
        my $str_date = "$current_year-$str_month-01";

        # Count new writeups in this month
        my $writeup_count = $DB->sqlSelect(
            'count(*)',
            'node JOIN writeup on writeup.writeup_id=node.node_id',
            "type_nodetype=$writeup_type_id " .
            "AND publishtime >= '$str_date' " .
            "AND publishtime < DATE_ADD('$str_date', INTERVAL 1 MONTH)"
        );

        # Count contributing users (distinct authors who wrote in this month)
        my $user_count = $DB->sqlSelect(
            'count(DISTINCT author_user)',
            'node',
            "type_nodetype='$writeup_type_id' " .
            "AND createtime >= '$str_date' " .
            "AND createtime < DATE_ADD('$str_date', INTERVAL 1 MONTH)"
        );

        # Count C!s spent in this month
        my $cool_count = $DB->sqlSelect(
            'count(*)',
            'coolwriteups',
            "tstamp >= '$str_date' " .
            "AND tstamp < DATE_ADD('$str_date', INTERVAL 1 MONTH)"
        );

        # Calculate C!:NW ratio
        my $cnw_ratio = $writeup_count > 0 ? $cool_count / $writeup_count : 0;

        push @data, {
            year => int($current_year),
            month => int($current_month + 1),
            writeup_count => int($writeup_count),
            user_count => int($user_count),
            cool_count => int($cool_count),
            cnw_ratio => sprintf("%.2f", $cnw_ratio)
        };

        # Move to previous month
        $current_month--;
        if ($current_month < 0) {
            $current_month = 11;
            $current_year--;
        }
    }

    return [$self->HTTP_OK, {
        data => \@data,
        current_year => $year,
        back_to_year => $back_to_year
    }];
}

__PACKAGE__->meta->make_immutable;

1;

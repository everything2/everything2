package Everything::Page::log_archive;

use Moose;
extends 'Everything::Page';

use DateTime;

=head1 Everything::Page::log_archive

React page for Log Archive - displays monthly archives of day logs, dream logs,
editor logs, and root logs.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $query = $REQUEST->cgi;

    my $cur_date  = DateTime->now;
    my $min_year  = 1997;
    my $max_year  = $cur_date->year;

    # Parse month parameter
    my $month = int( $query->param('m') || 0 );
    if ( $month < 1 || $month > 12 ) {
        $month = $cur_date->month;
    }

    # Parse year parameter
    my $year = int( $query->param('y') || 0 );
    if ( $year < $min_year || $year > $max_year ) {
        $year = $cur_date->year;
    }

    # Calculate previous/next month navigation
    my $prev_year  = $year;
    my $prev_month = $month - 1;
    if ( $prev_month < 1 ) {
        $prev_month = 12;
        $prev_year--;
    }

    my $next_year  = $year;
    my $next_month = $month + 1;
    if ( $next_month > 12 ) {
        $next_month = 1;
        $next_year++;
    }

    # Get month names
    my @month_names = qw(January February March April May June July August September October November December);
    my $month_name  = $month_names[ $month - 1 ];

    # Build SQL query to find log writeups
    my $sql = qq{
        SELECT
            writeupNode.node_id AS writeup_id,
            writeupNode.title AS writeup_title,
            writeupNode.author_user,
            writeupNode.reputation,
            authorNode.title AS author_title,
            writeup.wrtype_writeuptype,
            nodeTypeNode.title AS writeup_type,
            writeup.parent_e2node,
            e2node.title AS parent_title,
            writeupNode.createtime
        FROM node writeupNode
        JOIN writeup ON writeupNode.node_id = writeup.writeup_id
        JOIN node authorNode ON writeupNode.author_user = authorNode.node_id
        JOIN node nodeTypeNode ON nodeTypeNode.node_id = writeup.wrtype_writeuptype
        JOIN node e2node ON e2node.node_id = writeup.parent_e2node
        WHERE (
            e2node.title LIKE '$month_name %, $year'
            OR e2node.title LIKE 'Dream Log: $month_name %, $year'
            OR e2node.title = 'Editor Log: $month_name $year'
            OR e2node.title = 'root log: $month_name $year'
        )
        ORDER BY writeupNode.createtime
    };

    my $cursor = $DB->{dbh}->prepare($sql);
    $cursor->execute();

    my @day_logs;
    my @dream_logs;
    my @editor_logs;
    my @root_logs;

    while ( my $row = $cursor->fetchrow_hashref ) {
        my $entry = {
            writeup_id    => $row->{writeup_id},
            writeup_title => $row->{writeup_title},
            author_id     => $row->{author_user},
            author_title  => $row->{author_title},
            writeup_type  => $row->{writeup_type},
            parent_id     => $row->{parent_e2node},
            parent_title  => $row->{parent_title},
            createtime    => $row->{createtime}
        };

        my $title = $row->{parent_title} || '';

        # Categorize by log type based on parent title pattern
        if ( $title =~ /^(January|February|March|April|May|June|July|August|September|October|November|December) \d{1,2}, \d{4}$/ ) {
            push @day_logs, $entry;
        }
        elsif ( $title =~ /^Dream Log: / ) {
            push @dream_logs, $entry;
        }
        elsif ( $title =~ /^Editor Log: / ) {
            push @editor_logs, $entry;
        }
        elsif ( $title =~ /^root log: / ) {
            push @root_logs, $entry;
        }
    }

    # Build month options for the selector
    my @months;
    for my $i ( 1 .. 12 ) {
        push @months, {
            value    => $i,
            label    => $month_names[ $i - 1 ],
            selected => ( $i == $month ) ? 1 : 0
        };
    }

    # Build year options for the selector
    my @years;
    for my $y ( reverse $min_year .. $max_year ) {
        push @years, {
            value    => $y,
            selected => ( $y == $year ) ? 1 : 0
        };
    }

    return {
        type         => 'log_archive',
        month        => $month,
        year         => $year,
        month_name   => $month_name,
        months       => \@months,
        years        => \@years,
        min_year     => $min_year,
        max_year     => $max_year,
        prev_month   => $prev_month,
        prev_year    => $prev_year,
        next_month   => $next_month,
        next_year    => $next_year,
        prev_month_name => $month_names[ $prev_month - 1 ],
        next_month_name => $month_names[ $next_month - 1 ],
        day_logs     => \@day_logs,
        dream_logs   => \@dream_logs,
        editor_logs  => \@editor_logs,
        root_logs    => \@root_logs
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

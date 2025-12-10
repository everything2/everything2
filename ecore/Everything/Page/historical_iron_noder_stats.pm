package Everything::Page::historical_iron_noder_stats;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::historical_iron_noder_stats - Historical Iron Noder statistics

=head1 DESCRIPTION

Shows historical Iron Noder challenge statistics for past years.
Currently defaults to 2013 but supports year parameter.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with historical Iron Noder stats.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Get year from parameter or default to 2013 (the original hardcoded year)
    my $year = $REQUEST->cgi->param('year') || 2013;
    $year = int($year);

    # Validate year is reasonable (Iron Noder started around 2008)
    if ($year < 2008 || $year > 2030) {
        $year = 2013;
    }

    my $date_min = $year . '-11-01';
    my $date_max = $year . '-12-01';

    # Constants
    my $user_id = $USER->node_id;
    my $WRITEUP_COUNT_FOR_IRON = 30;
    my $MAX_DAYLOG_COUNT = 5;

    # Get the ironnoders usergroup for the specific year
    # Try year-specific group first, fall back to generic
    my $group_title = "ironnoders$year";
    my $group = $DB->getNode($group_title, 'usergroup');

    # Fall back to generic ironnoders group if year-specific doesn't exist
    unless ($group) {
        $group_title = 'ironnoders';
        $group = $DB->getNode($group_title, 'usergroup');
    }

    unless ($group) {
        return {
            type => 'iron_noder_progress',
            year => $year,
            is_historical => 1,
            available_years => [$self->_get_available_years($DB)],
            error => 'Unable to find a list of iron noders for this year.'
        };
    }

    # Get group members
    my $group_members = $group->{group} || [];
    my $iron_leader_id = @$group_members ? $group_members->[0] : undef;

    # Get writeup type ID
    my $writeup_type = $DB->getType('writeup');
    my $writeup_type_id = $writeup_type->{node_id};

    # Build participant list with writeups
    my @participants = ();
    my $stats = {
        total_writeups => 0,
        total_noders => 0,
        noders_with_writeups => 0,
        iron_noders => 0,
        min_writeups => undef,
        min_writeups_positive => undef,
        max_writeups => 0,
        your_writeups => 0,
        voted_writeups => 0
    };

    foreach my $member_id (@$group_members) {
        my $member = $DB->getNodeById($member_id, 'light');
        next unless $member;

        # Get writeups for this member in the date range
        my $writeups = $self->_get_member_writeups(
            $DB, $member_id, $writeup_type_id, $date_min, $date_max, $user_id
        );

        # Filter out maintenance nodes and excess daylogs
        my $daylog_count = 0;
        my @valid_writeups = ();
        my $excess_daylogs = 0;

        foreach my $wu (@$writeups) {
            next if $APP->isMaintenanceNode($wu);

            my $is_daylog = $self->_is_daylog_node($wu->{parenttitle});
            if ($is_daylog) {
                $daylog_count++;
                if ($daylog_count <= $MAX_DAYLOG_COUNT) {
                    push @valid_writeups, $wu;
                } else {
                    $excess_daylogs++;
                }
            } else {
                push @valid_writeups, $wu;
            }
        }

        my $writeup_count = scalar(@valid_writeups);
        my $voted_count = scalar(grep { $_->{has_voted} } @valid_writeups);

        push @participants, {
            user => {
                node_id => $member->{node_id},
                title => $member->{title}
            },
            writeup_count => $writeup_count,
            excess_daylogs => $excess_daylogs,
            is_iron => $writeup_count >= $WRITEUP_COUNT_FOR_IRON ? 1 : 0,
            writeups => \@valid_writeups
        };

        # Update stats
        $stats->{total_noders}++;
        $stats->{total_writeups} += $writeup_count;
        if ($writeup_count > 0) {
            $stats->{noders_with_writeups}++;
            if (!defined $stats->{min_writeups_positive} || $writeup_count < $stats->{min_writeups_positive}) {
                $stats->{min_writeups_positive} = $writeup_count;
            }
        }
        if ($writeup_count >= $WRITEUP_COUNT_FOR_IRON) {
            $stats->{iron_noders}++;
        }
        if (!defined $stats->{min_writeups} || $writeup_count < $stats->{min_writeups}) {
            $stats->{min_writeups} = $writeup_count;
        }
        if ($writeup_count > $stats->{max_writeups}) {
            $stats->{max_writeups} = $writeup_count;
        }
        if ($member_id == $user_id) {
            $stats->{your_writeups} = $writeup_count;
        }
        $stats->{voted_writeups} += $voted_count;
    }

    # Sort participants alphabetically by username
    @participants = sort { lc($a->{user}{title}) cmp lc($b->{user}{title}) } @participants;

    # Calculate average
    if ($stats->{total_noders} > 0) {
        $stats->{average_writeups} = sprintf('%.2f', $stats->{total_writeups} / $stats->{total_noders});
    }

    # Calculate vote percentage
    my $other_writeups = $stats->{total_writeups} - $stats->{your_writeups};
    if ($other_writeups > 0) {
        $stats->{vote_percentage} = int(100 * $stats->{voted_writeups} / $other_writeups);
    }

    # List of available historical years (years that have ironnoders groups)
    my @available_years = $self->_get_available_years($DB);

    return {
        type => 'iron_noder_progress',
        year => $year,
        group_title => $group_title,
        participants => \@participants,
        stats => $stats,
        is_participant => (grep { $_->{user}{node_id} == $user_id } @participants) ? 1 : 0,
        is_historical => 1,
        writeup_goal => $WRITEUP_COUNT_FOR_IRON,
        max_daylogs => $MAX_DAYLOG_COUNT,
        available_years => \@available_years
    };
}

sub _get_member_writeups {
    my ($self, $DB, $member_id, $writeup_type_id, $date_min, $date_max, $viewer_id) = @_;

    my $query = qq|
        SELECT
            node.node_id, node.title,
            parent.title AS parenttitle, writeup.parent_e2node,
            writeup.publishtime,
            CASE WHEN vote.vote_id IS NOT NULL THEN 1 ELSE 0 END AS has_voted
        FROM node
        LEFT OUTER JOIN vote ON voter_user = ? AND vote_id = node.node_id
        JOIN writeup ON node.node_id = writeup.writeup_id
        LEFT OUTER JOIN node AS parent ON writeup.parent_e2node = parent.node_id
        WHERE
            node.type_nodetype = ?
            AND node.author_user = ?
            AND writeup.publishtime >= ?
            AND writeup.publishtime < ?
        ORDER BY writeup.publishtime ASC
    |;

    my $sth = $DB->{dbh}->prepare($query);
    $sth->execute($viewer_id, $writeup_type_id, $member_id, $date_min, $date_max);

    my @writeups = ();
    while (my $row = $sth->fetchrow_hashref()) {
        push @writeups, {
            node_id => $row->{node_id},
            title => $row->{title},
            parenttitle => $row->{parenttitle},
            parent_id => $row->{parent_e2node},
            publishtime => $row->{publishtime},
            has_voted => $row->{has_voted} ? 1 : 0
        };
    }
    $sth->finish();

    return \@writeups;
}

sub _is_daylog_node {
    my ($self, $parent_title) = @_;
    return 0 unless $parent_title;

    # Month Day, Year format
    return 1 if $parent_title =~ m/^(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}$/i;

    # Dream/Editor/Root Log format
    return 1 if $parent_title =~ m/^(dream|editor|root)\s+log:/i;

    # Letters to the editors
    return 1 if $parent_title =~ m/^letters\s+to\s+the\s+editors:/i;

    return 0;
}

sub _get_available_years {
    my ($self, $DB) = @_;

    # Return all years from 2013 to current year
    # Iron Noder challenge has run annually since 2008, but user requested 2013+
    my $current_year = (localtime)[5] + 1900;
    my @years = ();

    # Generate years from 2013 to current year
    for (my $year = $current_year; $year >= 2013; $year--) {
        push @years, $year;
    }

    return @years;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::Page::iron_noder_progress;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::iron_noder_progress - Iron Noder challenge progress tracker

=head1 DESCRIPTION

Shows progress for the current year's Iron Noder challenge, listing all
participants and their writeups during November.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with Iron Noder progress.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    my $current_year = $year + 1900;
    my $date_min = $current_year . '-11-01';
    my $date_max = $current_year . '-12-01';

    # Constants
    my $user_id = $USER->node_id;
    my $is_guest = $APP->isGuest($USER->NODEDATA);
    my $WRITEUP_COUNT_FOR_IRON = 30;
    my $MAX_DAYLOG_COUNT = 5;

    # Get the ironnoders usergroup
    my $group = $DB->getNode('ironnoders', 'usergroup');
    unless ($group) {
        return {
            type => 'iron_noder_progress',
            year => $current_year,
            is_historical => 0,
            error => 'Unable to find a list of iron noders.'
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

    return {
        type => 'iron_noder_progress',
        year => $current_year,
        participants => \@participants,
        stats => $stats,
        is_participant => (grep { $_->{user}{node_id} == $user_id } @participants) ? 1 : 0,
        is_iron_leader => ($iron_leader_id && $iron_leader_id == $user_id) ? 1 : 0,
        is_historical => 0,
        writeup_goal => $WRITEUP_COUNT_FOR_IRON,
        max_daylogs => $MAX_DAYLOG_COUNT
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

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

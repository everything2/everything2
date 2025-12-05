package Everything::Page::everything_s_best_users;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_s_best_users - Everything's Best Users List

=head1 DESCRIPTION

Displays the top 50 users by experience (or devotion/addiction if requested).
Allows filtering by new users and excluding fled users.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with user list and filter options.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $query = $REQUEST->cgi;

    # Get filter options from query parameters
    my $showDevotion = $query->param('ebu_showdevotion') || 0;
    my $showAddiction = $query->param('ebu_showaddiction') || 0;
    my $showNewUsers = $query->param('ebu_newusers') || 0;
    my $showRecent = $query->param('ebu_showrecent') || 0;

    # Users to skip (legacy/system users)
    my $skip = {
        'dbrown' => 1,
        'nate' => 1,
        'Webster 1913' => 1,
        'ShadowLost' => 1,
        'EDB' => 1
    };

    # Get level experience and titles
    my $lvlexp_node = $DB->getNode('level experience', 'setting');
    my $lvlttl_node = $DB->getNode('level titles', 'setting');
    my $lvlexp = $APP->getVars($lvlexp_node);
    my $lvlttl = $APP->getVars($lvlttl_node);

    # Query users - always sort by experience since devotion/addiction are calculated
    # Fetch extra users to account for filtering
    my $limit = 200;  # Get more than needed for filtering/sorting

    # Calculate cutoff date for new users (2 years ago)
    my $two_years_ago = time() - (2 * 365 * 24 * 60 * 60);

    my $sql = qq{
        SELECT
            node.node_id,
            node.title,
            node.createtime,
            user.experience,
            user.lasttime,
            user.numwriteups,
            setting.vars
        FROM user
        LEFT JOIN node ON node_id = user_id
        LEFT JOIN setting ON setting_id = user_id
        ORDER BY user.experience DESC
        LIMIT $limit
    };

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @all_users;

    while (my $row = $sth->fetchrow_hashref()) {
        # Skip system users
        next if exists $skip->{$row->{title}};

        # Get vars using getVars (handles parsing from TEXT field)
        my $vars = $APP->getVars($row);

        # Get writeup count - check vars first (authoritative), fallback to user table
        my $writeup_count = $vars->{numwriteups} || $row->{numwriteups} || 0;

        # Check new user filter - created within last 2 years
        if ($showNewUsers) {
            # Parse createtime from MySQL format (YYYY-MM-DD HH:MM:SS)
            my $createtime = $row->{createtime};
            # Skip users with invalid createtime (0000-00-00) - these are very old users
            next if !$createtime || $createtime eq '0000-00-00 00:00:00' || $createtime =~ /^0000-/;

            if ($createtime =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
                require Time::Local;
                my ($year, $month, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
                # Convert month from 1-12 to 0-11 for Time::Local
                my $timestamp = Time::Local::timegm($sec, $min, $hour, $day, $month - 1, $year);
                next if $timestamp < $two_years_ago;
            }
        } else {
            # Normal mode - require at least 25 writeups
            next if $writeup_count < 25;
        }

        # Check fled user filter - "Don't show fled users"
        if ($showRecent) {
            my $lasttime = $row->{lasttime};
            # Skip users with no last login time (NULL) - they're fled
            next if !$lasttime || $lasttime eq '0000-00-00 00:00:00' || $lasttime =~ /^0000-/;

            # Parse lasttime from MySQL format (YYYY-MM-DD HH:MM:SS)
            if ($lasttime =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
                require Time::Local;
                my ($year, $month, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
                my $timestamp = Time::Local::timegm($sec, $min, $hour, $day, $month - 1, $year);
                # Skip users who haven't logged in within 2 years - they're fled
                next if (time() - $timestamp) > (2 * 365 * 24 * 60 * 60);
            } else {
                # If lasttime doesn't match expected format, skip them
                next;
            }
        }

        # Get level information
        my $level_value = $APP->getLevel($row);
        my $level_title = $lvlttl->{$level_value} || 'Initiate';

        # Calculate devotion (experience per writeup)
        my $devotion = 0;
        if ($writeup_count > 0) {
            $devotion = int($row->{experience} / $writeup_count);
        }

        # Calculate addiction (writeups per day as member)
        my $addiction = 0;
        my $created = $vars->{created_on} || 0;
        if ($created > 0) {
            my $days_member = int((time() - $created) / (24 * 60 * 60));
            if ($days_member > 0) {
                $addiction = $writeup_count / $days_member;
            }
        }

        push @all_users, {
            node_id => $row->{node_id},
            title => $row->{title},
            experience => $row->{experience},
            devotion => $devotion,
            addiction => $addiction,
            writeup_count => $writeup_count,
            level_value => $level_value,
            level_title => $level_title
        };
    }

    $sth->finish();

    # Sort users based on selected metric
    my @sorted_users;
    if ($showDevotion) {
        @sorted_users = sort { $b->{devotion} <=> $a->{devotion} } @all_users;
    } elsif ($showAddiction) {
        @sorted_users = sort { $b->{addiction} <=> $a->{addiction} } @all_users;
    } else {
        @sorted_users = sort { $b->{experience} <=> $a->{experience} } @all_users;
    }

    # Take top 50
    my @users = splice(@sorted_users, 0, 50);

    return {
        type => 'everything_s_best_users',
        users => \@users,
        showDevotion => $showDevotion ? 1 : 0,
        showAddiction => $showAddiction ? 1 : 0,
        showNewUsers => $showNewUsers ? 1 : 0,
        showRecent => $showRecent ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::Page::noding_speedometer;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::noding_speedometer - Calculate user noding speed

=head1 DESCRIPTION

Calculates a user's noding speed (days per node) based on their last N writeups,
and projects time to reach the next level.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns noding speed data and level-up projections.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $CGI = $REQUEST->cgi;
    my $USER = $REQUEST->user;
    my $APP = $self->APP;

    # Guests cannot use this
    if ($APP->isGuest($USER)) {
        return {
            type => 'noding_speedometer',
            error => 'Sorry, but only registered members can use the Noding Speedometer.'
        };
    }

    # Get parameters
    my $speedyuser = $CGI->param('speedyuser') || '';
    my $clock_nodes = $CGI->param('clocknodes') || 50;

    # Validate clock_nodes is a positive number
    unless ($clock_nodes =~ /^\d+$/ && $clock_nodes > 0) {
        return {
            type => 'noding_speedometer',
            error => 'Please enter a number of nodes greater than 0.',
            username => $speedyuser || $USER->title,
            clock_nodes => 50
        };
    }

    # If no user specified, show form
    unless ($speedyuser) {
        return {
            type => 'noding_speedometer',
            username => $USER->title,
            clock_nodes => $clock_nodes
        };
    }

    # Look up the user
    my $target_user = $DB->getNode($speedyuser, 'user');
    unless ($target_user) {
        return {
            type => 'noding_speedometer',
            error => "Your aim is way off. $speedyuser isn't a user. Try again.",
            username => $speedyuser,
            clock_nodes => $clock_nodes
        };
    }

    # Get writeup type ID
    my $writeup_type = $DB->getType('writeup');
    my $writeup_type_id = $writeup_type->{node_id};

    # Count total writeups
    my $total_writeups = $DB->sqlSelect(
        "COUNT(*)",
        "node",
        "author_user=" . $target_user->{node_id} . " AND type_nodetype=$writeup_type_id"
    );

    if ($total_writeups == 0) {
        return {
            type => 'noding_speedometer',
            error => "Um, user " . $target_user->{title} . " has no writeups!",
            username => $speedyuser,
            clock_nodes => $clock_nodes
        };
    }

    # Adjust clock_nodes if needed
    my $actual_count = $clock_nodes;
    if ($total_writeups < $clock_nodes) {
        $actual_count = $total_writeups;
    }

    # Get the Nth most recent writeup's age in days
    my $days_elapsed = $DB->sqlSelect(
        "TO_DAYS(NOW()) - TO_DAYS(publishtime)",
        "node JOIN writeup ON writeup_id=node_id",
        "author_user=" . $target_user->{node_id} . " ORDER BY publishtime DESC LIMIT " . ($actual_count - 1) . ",1"
    );

    # Need at least 1 day for speed calculation
    if ($days_elapsed < 1) {
        return {
            type => 'noding_speedometer',
            error => "Wait a while, do at least one lap around the track before timing yourself.",
            username => $speedyuser,
            clock_nodes => $clock_nodes
        };
    }

    # Calculate speed (days per node)
    my $speed = $days_elapsed / $actual_count;

    # Determine speedometer color and width
    my ($color, $width, $comment) = $self->_calculateSpeedometer($speed, $target_user->{title});

    # Get clocked writeups for XP calculation
    my $csr = $DB->sqlSelectMany(
        'title, node_id, reputation, cooled',
        'node INNER JOIN writeup ON node_id=writeup_id',
        "author_user=" . $target_user->{node_id} . " AND type_nodetype=$writeup_type_id",
        "ORDER BY publishtime DESC LIMIT 0, $actual_count"
    );

    my $total_upvotes = 0;
    my $total_cools = 0;

    while (my $row = $csr->fetchrow_hashref) {
        # Skip administrative nodes
        next if $row->{title} =~ /^(E2 Nuke Request|Edit these E2 titles|Nodeshells marked for destruction|Broken Nodes) \(/;

        # Calculate upvotes
        my $votes_cast = $DB->sqlSelect('COUNT(*)', 'vote', 'vote_id=' . $row->{node_id});
        my $upvotes = ($votes_cast + $row->{reputation}) / 2;

        # If not a whole number, get actual upvote count
        if (int($upvotes) != $upvotes) {
            $upvotes = $DB->sqlSelect('COUNT(*)', 'vote', 'vote_id=' . $row->{node_id} . ' AND weight=1');
        }

        $total_upvotes += $upvotes;
        $total_cools += $row->{cooled};
    }

    # Calculate average XP per writeup
    my $avg_xp = (($actual_count * 5) + ($total_cools * 20) + $total_upvotes) / $actual_count;

    # Get level requirements
    my $level_wu_node = $DB->getNode('level writeups', 'setting');
    my $level_xp_node = $DB->getNode('level experience', 'setting');
    my $level_wu_vars = $APP->getVars($level_wu_node);
    my $level_xp_vars = $APP->getVars($level_xp_node);

    my $current_level = $APP->getLevel($target_user);
    my $current_xp = $target_user->{experience};

    my $req_wu = ($level_wu_vars->{$current_level + 1} || 0) - $total_writeups;
    my $req_xp = ($level_xp_vars->{$current_level + 1} || 0) - $current_xp;

    # Calculate days to level up
    my $days_wu = $req_wu > 0 ? $req_wu * $speed : 0;
    my $days_xp = $req_xp > 0 ? $req_xp / ((1 / $speed) * $avg_xp) : 0;
    my $days_to_level = $days_wu > $days_xp ? $days_wu : $days_xp;

    my $nodes_needed = $req_wu > 0 ? $req_wu : 0;
    if ($req_xp > 0) {
        my $temp = $req_xp / $avg_xp;
        $nodes_needed = $temp if $temp > $nodes_needed;
    }

    return {
        type => 'noding_speedometer',
        username => $target_user->{title},
        clock_nodes => $clock_nodes,
        total_writeups => $total_writeups,
        actual_count => $actual_count,
        days_elapsed => $days_elapsed,
        speed => $speed,
        color => $color,
        width => $width,
        comment => $comment,
        level_data => {
            current_level => $current_level,
            next_level => $current_level + 1,
            req_wu => $req_wu > 0 ? $req_wu : 0,
            req_xp => $req_xp > 0 ? $req_xp : 0,
            avg_xp => $avg_xp,
            nodes_needed => $nodes_needed,
            days_to_level => $days_to_level
        }
    };
}

sub _calculateSpeedometer {
    my ($self, $speed, $username) = @_;

    if ($speed <= 0.75) {
        return ('#6600CC', 100, "$username has broken the speedometer and is probably not even human...");
    }
    elsif ($speed <= 1) {
        return ('red', 90, "IRON NODER speed! $username has been issued a ticket.");
    }
    elsif ($speed <= 3) {
        return ('orange', 75, "Pretty fast! A warning and a doughnut bribe may be in order.");
    }
    elsif ($speed <= 7) {
        return ('yellow', 50, "Nothing the node police need to worry about just yet.");
    }
    elsif ($speed <= 20) {
        return ('green', 25, "We all get there in our own time, even if we cause tailbacks on the way...");
    }
    else {
        return ('#330000', 10, "We politely suggest that you exit your vehicle and get a taxi. Perhaps the conversation will inspire you.");
    }
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

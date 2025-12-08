package Everything::API::reputation;

use Moose;
use namespace::autoclean;
use Time::Piece;

extends 'Everything::API';

=head1 NAME

Everything::API::reputation - API for reputation graph data

=head1 DESCRIPTION

Provides API endpoint for fetching vote data for writeup reputation graphs.

=head1 METHODS

=head2 routes

Define API routes.

=cut

sub routes {
    return {
        "votes" => "votes"
    };
}

=head2 votes($REQUEST)

Returns monthly vote breakdown for a writeup.

GET /api/reputation/votes?writeup_id=12345

Permission: User must have voted on the writeup, be the author, or be an admin.

Returns JSON with monthly upvotes, downvotes, and cumulative reputation.

=cut

sub votes {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    my $writeup_id = $REQUEST->param('writeup_id');

    # Validate writeup_id
    unless ($writeup_id && $writeup_id =~ /^\d+$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid writeup ID'
        }];
    }

    my $writeup = $DB->getNodeById($writeup_id);

    unless ($writeup) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Writeup not found'
        }];
    }

    # Verify it's a writeup (type 117)
    unless ($writeup->{type_nodetype} == 117) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Node is not a writeup'
        }];
    }

    # Permission check
    my $is_admin = $USER->is_admin;
    my $can_view = $is_admin;

    # Users can view their own writeups
    if (!$can_view) {
        $can_view = ($writeup->{author_user} == $USER->{node_id});
    }

    # Check if user has voted
    if (!$can_view) {
        my $sth = $DB->{dbh}->prepare(
            'SELECT weight FROM vote WHERE vote_id = ? AND voter_user = ?'
        );
        $sth->execute($writeup_id, $USER->{node_id});
        $can_view = 1 if $sth->rows > 0;
    }

    unless ($can_view) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Access denied'
        }];
    }

    # Get publishtime to know starting point
    my $publishtime = $writeup->{publishtime};
    my ($start_year, $start_month) = _parse_date($publishtime);

    # Fetch all votes ordered by time
    my $sth = $DB->{dbh}->prepare(
        'SELECT weight, votetime, revotetime FROM vote WHERE vote_id = ? ORDER BY GREATEST(revotetime, votetime)'
    );
    $sth->execute($writeup_id);

    # Build monthly data
    my %monthly;  # "YYYY-MM" => { upvotes => N, downvotes => N }
    my $current_year = $start_year;
    my $current_month = $start_month;

    while (my $row = $sth->fetchrow_hashref) {
        # Use revotetime if it's later than votetime
        my $votetime = $row->{votetime};
        if ($row->{revotetime} && $row->{revotetime} gt $votetime) {
            $votetime = $row->{revotetime};
        }

        my ($vote_year, $vote_month) = _parse_date($votetime);

        # Fill in any months between current position and this vote
        while ($vote_year > $current_year ||
               ($vote_year == $current_year && $vote_month > $current_month)) {
            my $key = sprintf("%04d-%02d", $current_year, $current_month);
            $monthly{$key} //= { upvotes => 0, downvotes => 0 };

            $current_month++;
            if ($current_month > 12) {
                $current_month = 1;
                $current_year++;
            }
        }

        # Record this vote in current month
        my $key = sprintf("%04d-%02d", $vote_year, $vote_month);
        $monthly{$key} //= { upvotes => 0, downvotes => 0 };

        if ($row->{weight} > 0) {
            $monthly{$key}{upvotes} += $row->{weight};
        } elsif ($row->{weight} < 0) {
            $monthly{$key}{downvotes} += $row->{weight};
        }

        $current_year = $vote_year;
        $current_month = $vote_month;
    }

    # Make sure we have at least the current month if no votes
    my @now = localtime();
    my $now_year = $now[5] + 1900;
    my $now_month = $now[4] + 1;

    # Fill to current month
    while ($now_year > $current_year ||
           ($now_year == $current_year && $now_month >= $current_month)) {
        my $key = sprintf("%04d-%02d", $current_year, $current_month);
        $monthly{$key} //= { upvotes => 0, downvotes => 0 };

        last if $current_year == $now_year && $current_month == $now_month;

        $current_month++;
        if ($current_month > 12) {
            $current_month = 1;
            $current_year++;
        }
    }

    # Convert to array and calculate cumulative reputation
    my @months;
    my $cumulative_up = 0;
    my $cumulative_down = 0;

    for my $key (sort keys %monthly) {
        my ($year, $month) = split(/-/, $key);
        $cumulative_up += $monthly{$key}{upvotes};
        $cumulative_down += $monthly{$key}{downvotes};

        push @months, {
            year => int($year),
            month => int($month),
            label => "$month/$year",
            upvotes => $cumulative_up,
            downvotes => $cumulative_down,
            reputation => $cumulative_up + $cumulative_down,
            is_january => (int($month) == 1) ? 1 : 0
        };
    }

    return [$self->HTTP_OK, {
        success => 1,
        data => {
            writeup_id => $writeup_id,
            months => \@months
        }
    }];
}

# Helper to parse MySQL datetime to (year, month)
sub _parse_date {
    my ($datetime) = @_;

    # Handle NULL or invalid dates
    return (1900, 1) unless $datetime;
    return (1900, 1) if $datetime =~ /^0000/;

    # Parse YYYY-MM-DD format
    if ($datetime =~ /^(\d{4})-(\d{2})-/) {
        return (int($1), int($2));
    }

    return (1900, 1);
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::Page::reputation_graph>

=cut

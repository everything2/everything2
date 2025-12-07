package Everything::Page::voting_oracle;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::voting_oracle - Display user's voting statistics

=head1 DESCRIPTION

The Voting Oracle shows the logged-in user their voting history statistics,
including total votes cast, percentage of all votes, percentage of votable
writeups covered, and the ratio of upvotes to downvotes.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns voting statistics for the current user.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Guest users can't see voting stats
    if ($APP->isGuest($user->NODEDATA)) {
        return {
            is_guest => 1
        };
    }

    my $user_id = $user->NODEDATA->{node_id};

    # Get user's vote count (only regular votes between -1 and 1)
    my $vote_count = $DB->sqlSelect(
        "count(*)",
        "vote",
        "voter_user = $user_id AND weight BETWEEN -1 AND 1"
    ) || 0;

    # Get user's upvote count
    my $upvote_count = $DB->sqlSelect(
        "count(*)",
        "vote",
        "voter_user = $user_id AND weight = 1"
    ) || 0;

    # Check if user has cast any votes
    if ($vote_count == 0) {
        my $level = $APP->getLevel($user->NODEDATA);
        return {
            no_votes => 1,
            is_level_zero => ($level == 0) ? 1 : 0
        };
    }

    # Get total votes across all users
    my $total_votes = $DB->sqlSelect("count(*)", "vote") || 1;

    # Get total writeup count
    my $total_writeups = $DB->sqlSelect("count(*)", "writeup") || 0;

    # Get Webster 1913's writeup count (node_id 176726)
    my $webster_writeups = $DB->sqlSelect(
        "count(*)",
        "node",
        "type_nodetype = 117 AND author_user = 176726"
    ) || 0;

    # Votable writeups exclude Webster's
    my $votable_writeups = $total_writeups - $webster_writeups;
    $votable_writeups = 1 if $votable_writeups <= 0;  # Prevent division by zero

    # Calculate percentages
    my $percent_of_all_votes = sprintf("%.4f", 100 * ($vote_count / $total_votes));
    my $percent_upvotes = sprintf("%.3f", 100 * ($upvote_count / $vote_count));
    my $percent_writeups_voted = sprintf("%.3f", 100 * ($vote_count / $votable_writeups));

    return {
        vote_count => $vote_count,
        upvote_count => $upvote_count,
        downvote_count => $vote_count - $upvote_count,
        total_votes => $total_votes,
        votable_writeups => $votable_writeups,
        percent_of_all_votes => $percent_of_all_votes,
        percent_upvotes => $percent_upvotes,
        percent_writeups_voted => $percent_writeups_voted
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

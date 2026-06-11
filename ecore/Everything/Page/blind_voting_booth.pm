package Everything::Page::blind_voting_booth;

use Moose;
extends 'Everything::Page';

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitMagicNumbers)

=head1 NAME

Everything::Page::blind_voting_booth - Blind Voting Booth

=head1 DESCRIPTION

Anonymous voting on random writeups. Shows writeup content without
revealing the author, allows voting, then reveals author after vote.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $user = $REQUEST->user;

    # Guest check
    if ($user->is_guest) {
        return {
            type => 'blind_voting_booth',
            error => 'guest',
            message => 'You must be logged in to use the Blind Voting Booth.'
        };
    }

    my $USER = $user->NODEDATA;
    my $votes_left = int($USER->{votesleft} || 0);

    # No votes left
    if ($votes_left == 0) {
        return {
            type => 'blind_voting_booth',
            noVotesLeft => 1,
        };
    }

    # Find a random writeup the user hasn't voted on. The booth is BLIND: the
    # server never sends the author or reputation. Both are revealed
    # client-side only after a successful vote, via the vote API response
    # (Everything::API::vote -> BlindVotingBooth.js). The author-reveal used to
    # ride on an op=vote/votedon round-trip through the legacy vote opcode;
    # that opcode is gone (#4266) and React posts to /api/vote instead.
    my $writeup;
    my $attempts = 0;
    my $max_attempts = 30;

    while (!$writeup && $attempts < $max_attempts) {
        my $max_id = $DB->sqlSelect('max(writeup_id)', 'writeup');
        my $min_id = $DB->sqlSelect('min(writeup_id)', 'writeup');

        my $random_id = int(rand($max_id - $min_id)) + $min_id;

        my $candidate_id = $DB->sqlSelect('writeup_id', 'writeup', "writeup_id=$random_id");

        if ($candidate_id) {
            my $candidate = $DB->getNodeById($candidate_id);

            # Skip log writeups (wrtype_writeuptype 177599) and user's own writeups
            if ($candidate &&
                $candidate->{wrtype_writeuptype} != 177599 &&
                $candidate->{author_user} != $USER->{user_id} &&
                !$APP->hasVoted($candidate, $USER)) {
                $writeup = $candidate;
            }
        }

        $attempts++;
    }

    # Couldn't find a writeup after max attempts
    if (!$writeup) {
        return {
            type => 'blind_voting_booth',
            error => 'no_writeups',
            message => 'Could not find a writeup to vote on. Try again later.',
        };
    }

    my $parent = $DB->getNodeById($writeup->{parent_e2node});

    # Blind payload: author and reputation are withheld until the user votes.
    return {
        type => 'blind_voting_booth',
        writeup => {
            node_id => int($writeup->{node_id}),
            title => $writeup->{title},
            doctext => $writeup->{doctext},
            reputation => undef
        },
        parent => $parent ? {
            node_id => int($parent->{node_id}),
            title => $parent->{title}
        } : undef,
        votesLeft => $votes_left,
        nodeId => int($REQUEST->node->node_id),
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

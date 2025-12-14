package Everything::API::vote;

use Moose;
extends 'Everything::API';

# API endpoint for casting votes on writeups
# POST /api/vote
# Body: { writeup_id: 123, weight: 1 or -1 }

sub command_post {
    my ( $self, $REQUEST ) = @_;

    my $user = $REQUEST->user;

    # Check if user is logged in
    if ( $user->is_guest ) {
        return $self->error('You must be logged in to vote');
    }

    # Get request data
    my $data       = $self->get_json_data;
    my $writeup_id = int( $data->{writeup_id} || 0 );
    my $weight     = int( $data->{weight}     || 0 );

    # Validate inputs
    unless ($writeup_id) {
        return $self->error('Missing writeup_id');
    }

    unless ( $weight == 1 || $weight == -1 ) {
        return $self->error('Vote weight must be 1 (upvote) or -1 (downvote)');
    }

    # Get writeup node
    my $writeup = $self->APP->node_by_id($writeup_id);
    unless ( $writeup && $writeup->type->title eq 'writeup' ) {
        return $self->error('Writeup not found');
    }

    # Check if user is the author
    if ( $writeup->author_user == $user->node_id ) {
        return $self->error('You cannot vote on your own writeup');
    }

    # Check if user has already voted
    my $existing_vote = $self->DB->sqlSelectHashref( '*', 'vote',
        'voter_user=' . $user->node_id . ' AND vote_id=' . $writeup_id );

    if ($existing_vote) {
        return $self->error('You have already voted on this writeup');
    }

    # Check user voting power
    my $votes_left = $user->votesleft;
    unless ( $votes_left && $votes_left > 0 ) {
        return $self->error('You have no votes remaining');
    }

    # Cast the vote
    my $vote_result = $self->APP->insertVote( $user, $writeup, $weight );

    unless ($vote_result) {
        return $self->error('Failed to cast vote');
    }

    return $self->success(
        {
            message         => 'Vote cast successfully',
            writeup_id      => $writeup_id,
            weight          => $weight,
            votes_remaining => $votes_left - 1
        }
    );
}

__PACKAGE__->meta->make_immutable;
1;

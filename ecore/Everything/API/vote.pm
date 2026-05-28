package Everything::API::vote;

use Moose;
extends 'Everything::API';

# API endpoint for casting votes on writeups
# POST /api/vote/writeup/:id
# Body: { weight: 1 or -1 }

sub routes {
    return { "writeup/:id" => "cast_vote(:id)" };
}

sub cast_vote {
    my ( $self, $REQUEST, $writeup_id ) = @_;

    my $user = $REQUEST->user;

    # Check if user is logged in
    if ( $user->is_guest ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'You must be logged in to vote' }
        ];
    }

    # Get request data
    my $data   = $REQUEST->JSON_POSTDATA;
    my $weight = int( $data->{weight} || 0 );

    # Validate inputs
    $writeup_id = int( $writeup_id || 0 );
    unless ($writeup_id) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'Missing or invalid writeup_id' }
        ];
    }

    unless ( $weight == 1 || $weight == -1 ) {
        return [
            $self->HTTP_OK,
            {
                success => 0,
                error   => 'Vote weight must be 1 (upvote) or -1 (downvote)'
            }
        ];
    }

    # Get writeup node
    my $writeup = $self->APP->node_by_id($writeup_id);
    unless ( $writeup && $writeup->type->title eq 'writeup' ) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'Writeup not found' } ];
    }

    # Check if user is the author
    if ( $writeup->author_user == $user->node_id ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'You cannot vote on your own writeup' }
        ];
    }

    # Check if user has already voted
    my $existing_vote = $self->DB->sqlSelectHashref( '*', 'vote',
        'voter_user=' . $user->node_id . ' AND vote_id=' . $writeup_id );

    # If user has already voted with the same weight, don't allow duplicate vote
    if ( $existing_vote && $existing_vote->{weight} == $weight ) {
        return [
            $self->HTTP_OK,
            { success => 0, error => 'You have already cast this vote' }
        ];
    }

    # Check user voting power (only needed for new votes, not vote changes)
    unless ($existing_vote) {
        my $votes_left = $user->votesleft;
        unless ( $votes_left && $votes_left > 0 ) {
            return [
                $self->HTTP_OK,
                { success => 0, error => 'You have no votes remaining' }
            ];
        }
    }

 # If changing vote, delete the existing vote first to avoid duplicate key error
    if ($existing_vote) {
        $self->DB->sqlDelete( 'vote',
            'voter_user=' . $user->node_id . ' AND vote_id=' . $writeup_id );
    }

    # Cast the vote (convert blessed objects to hashrefs for legacy insertVote)
    my $vote_result =
      $self->APP->insertVote( $writeup->NODEDATA, $user->NODEDATA, $weight );

    unless ($vote_result) {
        return [ $self->HTTP_OK,
            { success => 0, error => 'Failed to cast vote' } ];
    }

    # Decrement votesleft if this is a new vote (not a vote swap)
    unless ($existing_vote) {
        $self->DB->sqlUpdate(
            'user',
            { '-votesleft' => 'votesleft - 1' },
            'user_id=' . $user->node_id
        );
    }

    # Recalculate reputation by summing all vote weights — source of truth
    # rather than delta math. See the reconciliation job at
    # jobs/job_reconcile_rep_and_cools.pl and the rep cluster (#4137 et al).
    #
    # updateNode (rather than raw sqlUpdate on the node table) is required
    # so NodeCache::incrementGlobalVersion ticks the version table and
    # other Apache webheads invalidate their cached copy. Without that,
    # stale rep keeps serving from per-webhead memory until TTL.
    my $new_reputation =
      $self->DB->sqlSelect( 'COALESCE(SUM(weight),0)', 'vote',
                            'vote_id=' . $writeup_id ) // 0;
    my $WRITEUP = $self->APP->node_by_id($writeup_id);
    my $NODE    = $WRITEUP ? $WRITEUP->NODEDATA : undef;
    if ($NODE) {
        $NODE->{reputation} = $new_reputation;
        $self->DB->updateNode($NODE, -1);
    }

    # Get updated vote counts (these are calculated on-the-fly from vote table)
    my $updated_writeup = $self->APP->node_by_id($writeup_id);
    my $upvotes         = $updated_writeup->upvotes;
    my $downvotes       = $updated_writeup->downvotes;

   # Calculate votes remaining (don't deduct a vote when changing existing vote)
    my $current_votes_left = $user->votesleft;
    my $votes_remaining =
      $existing_vote ? $current_votes_left : ( $current_votes_left - 1 );

    return [
        $self->HTTP_OK,
        {
            success => 1,
            message => $existing_vote
            ? 'Vote changed successfully'
            : 'Vote cast successfully',
            writeup_id      => $writeup_id,
            weight          => $weight,
            votes_remaining => $votes_remaining,
            reputation      => $new_reputation,
            upvotes         => $upvotes,
            downvotes       => $downvotes
        }
    ];
}

__PACKAGE__->meta->make_immutable;
1;

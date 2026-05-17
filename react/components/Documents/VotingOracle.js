import React from 'react';

/**
 * VotingOracle - Voting statistics display
 * Styles in CSS: .voting-oracle__*
 *
 * Displays user's voting statistics including total votes,
 * upvote/downvote counts, and percentage breakdowns.
 */
const VotingOracle = ({ data, e2 }) => {
  const {
    is_guest,
    no_votes,
    is_level_zero,
    vote_count,
    upvote_count,
    downvote_count,
    percent_of_all_votes,
    percent_upvotes,
    percent_writeups_voted
  } = data;

  // Guest users
  if (is_guest) {
    return (
      <div className="voting-oracle">
        <p className="voting-oracle__oracle">
          The Oracle requires you to identify yourself. Please log in to consult the Oracle.
        </p>
      </div>
    );
  }

  // Users who haven't voted yet
  if (no_votes) {
    return (
      <div className="voting-oracle">
        <p className="voting-oracle__oracle">
          {is_level_zero
            ? '...thou art too young yet. Come back soon.'
            : 'Thou hast grown, but are still yet a man. Prove thy judgment!'}
        </p>
      </div>
    );
  }

  return (
    <div className="voting-oracle">
      <div className="voting-oracle__box">
        <p className="voting-oracle__oracle">
          Thou hast cast <strong>{vote_count.toLocaleString()}</strong> votes...{' '}
          <strong>{percent_of_all_votes}%</strong> of the judgements made of all time,{' '}
          across <strong>{percent_writeups_voted}%</strong> of all votable writeups.{' '}
          Of these, <strong>{percent_upvotes}%</strong> are upvotes.
        </p>
      </div>

      <div className="voting-oracle__stats-grid">
        <div className="voting-oracle__stat-box">
          <div className="voting-oracle__stat-value">{vote_count.toLocaleString()}</div>
          <div className="voting-oracle__stat-label">Total Votes Cast</div>
        </div>
        <div className="voting-oracle__stat-box">
          <div className="voting-oracle__stat-value">{upvote_count.toLocaleString()}</div>
          <div className="voting-oracle__stat-label">Upvotes</div>
        </div>
        <div className="voting-oracle__stat-box">
          <div className="voting-oracle__stat-value">{downvote_count.toLocaleString()}</div>
          <div className="voting-oracle__stat-label">Downvotes</div>
        </div>
      </div>

      <div className="voting-oracle__percent-grid">
        <div className="voting-oracle__percent-box">
          <div className="voting-oracle__percent-value">{percent_of_all_votes}%</div>
          <div className="voting-oracle__percent-label">of all votes ever cast</div>
        </div>
        <div className="voting-oracle__percent-box">
          <div className="voting-oracle__percent-value">{percent_writeups_voted}%</div>
          <div className="voting-oracle__percent-label">of votable writeups covered</div>
        </div>
        <div className="voting-oracle__percent-box">
          <div className="voting-oracle__percent-value">{percent_upvotes}%</div>
          <div className="voting-oracle__percent-label">upvote ratio</div>
        </div>
      </div>
    </div>
  );
};

export default VotingOracle;

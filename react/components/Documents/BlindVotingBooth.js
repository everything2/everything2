import React, { useState, useMemo } from 'react';
import { renderE2Content } from '../Editor/E2HtmlSanitizer';

/**
 * BlindVotingBooth - Anonymous writeup voting interface
 *
 * Shows a random writeup without revealing the author. User can:
 * - Vote up (+1) or down (-1) with stylized buttons
 * - Pass to get a different writeup
 * - After voting, see the author and reputation
 *
 * Uses POST /api/vote/writeup/:id for voting.
 */
const BlindVotingBooth = ({ data }) => {
  const {
    writeup,
    parent,
    author,
    hasVoted: initialHasVoted,
    votesLeft: initialVotesLeft = 0,
    nodeId,
    noVotesLeft,
    error,
    message
  } = data;

  const [selectedVote, setSelectedVote] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hoverVote, setHoverVote] = useState(null);
  const [hasVoted, setHasVoted] = useState(initialHasVoted);
  const [votesLeft, setVotesLeft] = useState(initialVotesLeft);
  const [reputation, setReputation] = useState(writeup?.reputation || 0);
  const [voteError, setVoteError] = useState(null);

  // Error states
  if (error === 'guest') {
    return (
      <div className="voting-booth">
        <div className="voting-booth__error">
          <p>{message || 'You must be logged in to use the Blind Voting Booth.'}</p>
          <p>
            <a href="/title/Login" className="voting-booth__link">Log in</a> or{' '}
            <a href="/title/Sign%20up" className="voting-booth__link">Register</a> to continue.
          </p>
        </div>
      </div>
    );
  }

  if (noVotesLeft) {
    return (
      <div className="voting-booth">
        <h2 className="voting-booth__title">Blind Voting Booth</h2>
        <p className="voting-booth__intro">
          Welcome to the blind voting booth. You can give anonymous feedback
          without knowing who wrote a writeup here, if you so choose.
        </p>
        <div className="voting-booth__notice">
          You're done for today - no votes remaining.
        </div>
      </div>
    );
  }

  if (error === 'no_writeups') {
    return (
      <div className="voting-booth">
        <h2 className="voting-booth__title">Blind Voting Booth</h2>
        <p className="voting-booth__intro">
          Welcome to the blind voting booth. You can give anonymous feedback
          without knowing who wrote a writeup here, if you so choose.
        </p>
        <div className="voting-booth__notice">
          {message || 'Could not find a writeup to vote on. Try again later.'}
        </div>
        <p className="voting-booth__try-again-wrapper">
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="voting-booth__try-again-btn"
          >
            Try again
          </button>
        </p>
      </div>
    );
  }

  if (!writeup) {
    return (
      <div className="voting-booth">
        <h2 className="voting-booth__title">Blind Voting Booth</h2>
        <div className="voting-booth__error">No writeup available.</div>
      </div>
    );
  }

  // Render writeup content with E2 link parsing and HTML sanitization
  // Uses the same renderE2Content as E2 Editor Beta for consistent display
  const formattedContent = useMemo(() => {
    if (!writeup?.doctext) return '';
    const { html } = renderE2Content(writeup.doctext);
    return html;
  }, [writeup?.doctext]);

  // Handle skip button
  const handleSkip = () => {
    window.location.href = `/node/${nodeId}?garbage=${Date.now()}`;
  };

  // Handle vote submission via API
  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!selectedVote || isSubmitting) return;

    setIsSubmitting(true);
    setVoteError(null);

    try {
      const response = await fetch(`/api/vote/writeup/${writeup.node_id}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ weight: parseInt(selectedVote, 10) })
      });

      const result = await response.json();

      if (result.success) {
        setHasVoted(true);
        setVotesLeft(result.votes_remaining);
        setReputation(result.reputation);
      } else {
        setVoteError(result.error || 'Failed to cast vote');
      }
    } catch (err) {
      setVoteError('Network error: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Build CSS classes for vote buttons
  const getUpvoteClasses = () => {
    const classes = ['voting-booth__vote-btn', 'voting-booth__vote-btn--up'];
    if (selectedVote === '1') classes.push('voting-booth__vote-btn--selected');
    if (hoverVote === '1' && selectedVote !== '1') classes.push('voting-booth__vote-btn--hover');
    return classes.join(' ');
  };

  const getDownvoteClasses = () => {
    const classes = ['voting-booth__vote-btn', 'voting-booth__vote-btn--down'];
    if (selectedVote === '-1') classes.push('voting-booth__vote-btn--selected');
    if (hoverVote === '-1' && selectedVote !== '-1') classes.push('voting-booth__vote-btn--hover');
    return classes.join(' ');
  };

  // Determine reputation display class
  const getReputationClass = () => {
    if (reputation > 0) return 'voting-booth__rep-value voting-booth__rep-value--positive';
    if (reputation < 0) return 'voting-booth__rep-value voting-booth__rep-value--negative';
    return 'voting-booth__rep-value voting-booth__rep-value--neutral';
  };

  return (
    <div className="voting-booth">
      <h2 className="voting-booth__title">Blind Voting Booth</h2>

      <p className="voting-booth__intro">
        Welcome to the blind voting booth. You can give anonymous feedback
        without knowing who wrote a writeup here, if you so choose.
      </p>

      {voteError && (
        <div className="voting-booth__vote-error">
          {voteError}
        </div>
      )}

        {/* Writeup Card */}
        <div className="voting-booth__card">
          {/* Header with title and author */}
          <div className="voting-booth__header">
            <div className="voting-booth__title-row">
              <h3 className="voting-booth__writeup-title">{writeup.title}</h3>
              {parent && (
                <a
                  href={`/node/${parent.node_id}`}
                  className="voting-booth__node-link"
                  title="View full node"
                >
                  view e2node
                </a>
              )}
            </div>
            <div className="voting-booth__byline">
              {hasVoted && author ? (
                <>
                  by{' '}
                  <a href={`/user/${encodeURIComponent(author.title)}`} className="voting-booth__author-link">
                    {author.title}
                  </a>
                </>
              ) : (
                <span className="voting-booth__anonymous">by ???</span>
              )}
            </div>
          </div>

          {/* Writeup content */}
          <div
            className="writeup-content voting-booth__content"
            dangerouslySetInnerHTML={{ __html: formattedContent }}
          />

          {/* Footer with voting or reputation */}
          <div className="voting-booth__footer">
            {!hasVoted ? (
              <div className="voting-booth__voting-area">
                <div className="voting-booth__vote-buttons">
                  <button
                    type="button"
                    onClick={() => setSelectedVote('1')}
                    onMouseEnter={() => setHoverVote('1')}
                    onMouseLeave={() => setHoverVote(null)}
                    className={getUpvoteClasses()}
                    title="Upvote this writeup"
                  >
                    <span className="voting-booth__vote-icon">&#9650;</span>
                    <span className="voting-booth__vote-label">Upvote</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setSelectedVote('-1')}
                    onMouseEnter={() => setHoverVote('-1')}
                    onMouseLeave={() => setHoverVote(null)}
                    className={getDownvoteClasses()}
                    title="Downvote this writeup"
                  >
                    <span className="voting-booth__vote-icon">&#9660;</span>
                    <span className="voting-booth__vote-label">Downvote</span>
                  </button>
                </div>

                <div className="voting-booth__vote-actions">
                  <button
                    type="button"
                    onClick={handleSubmit}
                    disabled={!selectedVote || isSubmitting}
                    className="voting-booth__submit-btn"
                  >
                    {isSubmitting ? 'Submitting...' : 'Cast Vote'}
                  </button>

                  <button
                    type="button"
                    onClick={handleSkip}
                    className="voting-booth__skip-btn"
                  >
                    Skip this writeup
                  </button>
                </div>
              </div>
            ) : (
              <div className="voting-booth__post-vote">
                <div className="voting-booth__reputation">
                  <span className="voting-booth__rep-label">Reputation</span>
                  <span className={getReputationClass()}>
                    {reputation > 0 ? '+' : ''}{reputation}
                  </span>
                </div>

                {votesLeft > 0 ? (
                  <a
                    href={`/node/${nodeId}?garbage=${Date.now()}`}
                    className="voting-booth__next-btn"
                  >
                    Another writeup, please
                  </a>
                ) : (
                  <div className="voting-booth__no-votes">
                    No votes remaining for today.
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

      {/* Votes remaining indicator */}
      {!hasVoted && votesLeft > 0 && (
        <div className="voting-booth__votes-remaining">
          {votesLeft} vote{votesLeft !== 1 ? 's' : ''} remaining today
        </div>
      )}
    </div>
  );
};

export default BlindVotingBooth;

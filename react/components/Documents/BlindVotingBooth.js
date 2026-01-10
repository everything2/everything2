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
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{message || 'You must be logged in to use the Blind Voting Booth.'}</p>
          <p>
            <a href="/title/Login" style={styles.link}>Log in</a> or{' '}
            <a href="/title/Sign%20up" style={styles.link}>Register</a> to continue.
          </p>
        </div>
      </div>
    );
  }

  if (noVotesLeft) {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>Blind Voting Booth</h2>
        <p style={styles.intro}>
          Welcome to the blind voting booth. You can give anonymous feedback
          without knowing who wrote a writeup here, if you so choose.
        </p>
        <div style={styles.notice}>
          You're done for today - no votes remaining.
        </div>
      </div>
    );
  }

  if (error === 'no_writeups') {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>Blind Voting Booth</h2>
        <p style={styles.intro}>
          Welcome to the blind voting booth. You can give anonymous feedback
          without knowing who wrote a writeup here, if you so choose.
        </p>
        <div style={styles.notice}>
          {message || 'Could not find a writeup to vote on. Try again later.'}
        </div>
        <p style={{ marginTop: '20px', textAlign: 'center' }}>
          <button
            type="button"
            onClick={() => window.location.reload()}
            style={styles.tryAgainButton}
          >
            Try again
          </button>
        </p>
      </div>
    );
  }

  if (!writeup) {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>Blind Voting Booth</h2>
        <div style={styles.error}>No writeup available.</div>
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

  // Get dynamic vote button styles (Kernel Blue palette)
  const getUpvoteStyle = () => {
    const isSelected = selectedVote === '1';
    const isHovered = hoverVote === '1';
    return {
      ...styles.voteButtonBase,
      ...styles.upvoteButton,
      backgroundColor: isSelected ? '#4060b0' : (isHovered ? '#e8eef8' : '#f8f9f9'),
      color: isSelected ? '#ffffff' : '#4060b0',
      borderColor: isSelected ? '#4060b0' : (isHovered ? '#4060b0' : '#dee2e6'),
      transform: isSelected ? 'scale(1.05)' : 'scale(1)'
    };
  };

  const getDownvoteStyle = () => {
    const isSelected = selectedVote === '-1';
    const isHovered = hoverVote === '-1';
    return {
      ...styles.voteButtonBase,
      ...styles.downvoteButton,
      backgroundColor: isSelected ? '#38495e' : (isHovered ? '#e8ecf0' : '#f8f9f9'),
      color: isSelected ? '#ffffff' : '#38495e',
      borderColor: isSelected ? '#38495e' : (isHovered ? '#38495e' : '#dee2e6'),
      transform: isSelected ? 'scale(1.05)' : 'scale(1)'
    };
  };

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Blind Voting Booth</h2>

      <p style={styles.intro}>
        Welcome to the blind voting booth. You can give anonymous feedback
        without knowing who wrote a writeup here, if you so choose.
      </p>

      {voteError && (
        <div style={styles.voteError}>
          {voteError}
        </div>
      )}

        {/* Writeup Card */}
        <div style={styles.writeupCard}>
          {/* Header with title and author */}
          <div style={styles.writeupHeader}>
            <div style={styles.writeupTitleRow}>
              <h3 style={styles.writeupTitle}>{writeup.title}</h3>
              {parent && (
                <a
                  href={`/node/${parent.node_id}`}
                  style={styles.fullNodeLink}
                  title="View full node"
                >
                  view e2node
                </a>
              )}
            </div>
            <div style={styles.byline}>
              {hasVoted && author ? (
                <>
                  by{' '}
                  <a href={`/user/${encodeURIComponent(author.title)}`} style={styles.authorLink}>
                    {author.title}
                  </a>
                </>
              ) : (
                <span style={styles.anonymousAuthor}>by ???</span>
              )}
            </div>
          </div>

          {/* Writeup content */}
          <div
            className="writeup-content"
            style={styles.writeupContent}
            dangerouslySetInnerHTML={{ __html: formattedContent }}
          />

          {/* Footer with voting or reputation */}
          <div style={styles.writeupFooter}>
            {!hasVoted ? (
              <div style={styles.votingArea}>
                <div style={styles.voteButtons}>
                  <button
                    type="button"
                    onClick={() => setSelectedVote('1')}
                    onMouseEnter={() => setHoverVote('1')}
                    onMouseLeave={() => setHoverVote(null)}
                    style={getUpvoteStyle()}
                    title="Upvote this writeup"
                  >
                    <span style={styles.voteIcon}>&#9650;</span>
                    <span style={styles.voteLabel}>Upvote</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setSelectedVote('-1')}
                    onMouseEnter={() => setHoverVote('-1')}
                    onMouseLeave={() => setHoverVote(null)}
                    style={getDownvoteStyle()}
                    title="Downvote this writeup"
                  >
                    <span style={styles.voteIcon}>&#9660;</span>
                    <span style={styles.voteLabel}>Downvote</span>
                  </button>
                </div>

                <div style={styles.voteActions}>
                  <button
                    type="button"
                    onClick={handleSubmit}
                    disabled={!selectedVote || isSubmitting}
                    style={{
                      ...styles.submitButton,
                      opacity: (!selectedVote || isSubmitting) ? 0.5 : 1,
                      cursor: (!selectedVote || isSubmitting) ? 'not-allowed' : 'pointer'
                    }}
                  >
                    {isSubmitting ? 'Submitting...' : 'Cast Vote'}
                  </button>

                  <button
                    type="button"
                    onClick={handleSkip}
                    style={styles.skipButton}
                  >
                    Skip this writeup
                  </button>
                </div>
              </div>
            ) : (
              <div style={styles.postVoteArea}>
                <div style={styles.reputationDisplay}>
                  <span style={styles.reputationLabel}>Reputation</span>
                  <span style={{
                    ...styles.reputationValue,
                    color: reputation > 0 ? '#4060b0' : (reputation < 0 ? '#38495e' : '#507898')
                  }}>
                    {reputation > 0 ? '+' : ''}{reputation}
                  </span>
                </div>

                {votesLeft > 0 ? (
                  <a
                    href={`/node/${nodeId}?garbage=${Date.now()}`}
                    style={styles.nextWriteupButton}
                  >
                    Another writeup, please
                  </a>
                ) : (
                  <div style={styles.noVotesNotice}>
                    No votes remaining for today.
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

      {/* Votes remaining indicator */}
      {!hasVoted && votesLeft > 0 && (
        <div style={styles.votesRemaining}>
          {votesLeft} vote{votesLeft !== 1 ? 's' : ''} remaining today
        </div>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px'
  },
  title: {
    color: '#38495e',
    marginBottom: '8px',
    fontSize: '24px'
  },
  intro: {
    marginBottom: '24px',
    color: '#507898',
    fontSize: '14px'
  },
  writeupCard: {
    border: '1px solid #dee2e6',
    borderRadius: '8px',
    overflow: 'hidden',
    backgroundColor: '#ffffff',
    boxShadow: '0 2px 4px rgba(0, 0, 0, 0.05)'
  },
  writeupHeader: {
    padding: '16px 20px',
    backgroundColor: '#f8f9f9',
    borderBottom: '1px solid #dee2e6'
  },
  writeupTitleRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: '16px'
  },
  writeupTitle: {
    margin: 0,
    color: '#38495e',
    fontSize: '18px',
    fontWeight: '600',
    flex: 1
  },
  fullNodeLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontSize: '12px',
    padding: '4px 8px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    whiteSpace: 'nowrap'
  },
  byline: {
    marginTop: '8px',
    color: '#507898',
    fontSize: '14px'
  },
  authorLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: '500'
  },
  anonymousAuthor: {
    color: '#888888',
    fontStyle: 'italic'
  },
  writeupContent: {
    padding: '20px',
    lineHeight: '1.7',
    minHeight: '100px'
  },
  writeupFooter: {
    padding: '16px 20px',
    backgroundColor: '#f8f9f9',
    borderTop: '1px solid #dee2e6'
  },
  votingArea: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px'
  },
  voteButtons: {
    display: 'flex',
    gap: '12px',
    justifyContent: 'center'
  },
  voteButtonBase: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '12px 24px',
    border: '2px solid',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'all 0.15s ease',
    minWidth: '100px'
  },
  upvoteButton: {
    // Dynamic styles applied in getUpvoteStyle()
  },
  downvoteButton: {
    // Dynamic styles applied in getDownvoteStyle()
  },
  voteIcon: {
    fontSize: '20px',
    lineHeight: '1'
  },
  voteLabel: {
    fontSize: '12px',
    fontWeight: '600',
    marginTop: '4px',
    textTransform: 'uppercase',
    letterSpacing: '0.5px'
  },
  voteActions: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '16px'
  },
  submitButton: {
    padding: '10px 32px',
    backgroundColor: '#4060b0',
    color: '#ffffff',
    border: 'none',
    borderRadius: '6px',
    fontSize: '14px',
    fontWeight: '600',
    cursor: 'pointer'
  },
  skipButton: {
    padding: '10px 24px',
    backgroundColor: 'transparent',
    color: '#507898',
    border: '1px solid #dee2e6',
    borderRadius: '6px',
    fontSize: '14px',
    cursor: 'pointer'
  },
  postVoteArea: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  reputationDisplay: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px'
  },
  reputationLabel: {
    color: '#507898',
    fontSize: '14px'
  },
  reputationValue: {
    fontSize: '24px',
    fontWeight: '700'
  },
  nextWriteupButton: {
    padding: '10px 20px',
    backgroundColor: '#4060b0',
    color: '#ffffff',
    textDecoration: 'none',
    borderRadius: '6px',
    fontSize: '14px',
    fontWeight: '500'
  },
  noVotesNotice: {
    color: '#507898',
    fontSize: '14px',
    fontStyle: 'italic'
  },
  votesRemaining: {
    textAlign: 'center',
    marginTop: '16px',
    color: '#507898',
    fontSize: '13px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  error: {
    padding: '20px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    textAlign: 'center'
  },
  voteError: {
    padding: '12px 16px',
    marginBottom: '16px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    fontSize: '14px'
  },
  notice: {
    padding: '20px',
    backgroundColor: '#f8f9f9',
    borderRadius: '8px',
    color: '#507898',
    textAlign: 'center'
  },
  tryAgainButton: {
    padding: '10px 24px',
    backgroundColor: '#4060b0',
    color: '#ffffff',
    border: 'none',
    borderRadius: '6px',
    fontSize: '14px',
    cursor: 'pointer'
  }
};

export default BlindVotingBooth;

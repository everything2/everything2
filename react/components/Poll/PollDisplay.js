import React, { useState } from 'react'

/**
 * PollDisplay - Display an E2 poll with voting or results
 *
 * Props:
 * - poll: Poll object with title, question, options, results, user_vote, poll_status
 * - showStatus: Whether to show poll status in header
 * - isOwnPage: Whether this poll is being displayed on its own page
 * - canEdit: Whether user can edit this poll
 * - onVote: Callback when user votes (poll_id, choice)
 * - onDeleteVote: Callback when admin deletes vote (poll_id, user_id)
 * - isAdmin: Whether current user is admin
 * - userId: Current user ID for delete vote
 */
const PollDisplay = ({ poll, showStatus = false, isOwnPage = false, canEdit = false, onVote, onDeleteVote, isAdmin = false, userId = null }) => {
  const [voting, setVoting] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [selectedOption, setSelectedOption] = useState(null)

  const hasVoted = poll.user_vote !== null && poll.user_vote !== undefined
  const isClosed = poll.poll_status === 'closed'
  const isNew = poll.poll_status === 'new'
  const showResults = hasVoted || isClosed

  const handleVote = async () => {
    if (selectedOption === null || voting) return

    setVoting(true)
    if (onVote) {
      await onVote(poll.poll_id, selectedOption)
    }
    setVoting(false)
  }

  const handleDeleteVote = async () => {
    if (!isAdmin || !hasVoted || deleting) return
    if (!confirm('Delete your vote from this poll?')) return

    setDeleting(true)
    if (onDeleteVote) {
      await onDeleteVote(poll.poll_id, userId)
    }
    setDeleting(false)
  }

  return (
    <div className="poll-display">
      {/* Title - only show if not on own page */}
      {!isOwnPage && (
        <div className="poll-display__header">
          <h2 className="poll-display__title">
            <a href={`/node/${poll.poll_id}`} className="poll-display__title-link">
              {poll.title}
            </a>
            {showStatus && ` (${poll.poll_status})`}
          </h2>
        </div>
      )}

      {/* Author */}
      <div className="poll-display__author">
        by <a href={`/user/${poll.poll_author.title}`} className="poll-display__author-link">{poll.poll_author.title}</a>
        {canEdit && isNew && (
          <small>
            {' '}(<a href={`/node/${poll.poll_id}?displaytype=edit`} className="poll-display__author-link">edit</a>)
          </small>
        )}
      </div>

      {/* Question */}
      <h3 className="poll-display__question">{poll.question}</h3>

      {/* Voting form or results */}
      {!showResults && !isNew ? (
        <div>
          {poll.options.map((option, idx) => (
            <div key={idx} className="poll-display__option">
              <label>
                <input
                  type="radio"
                  name={`poll_${poll.poll_id}`}
                  value={idx}
                  checked={selectedOption === idx}
                  onChange={() => setSelectedOption(idx)}
                  className="poll-display__radio"
                />
                {option}
              </label>
            </div>
          ))}
          <button
            onClick={handleVote}
            disabled={selectedOption === null || voting}
            className="poll-display__vote-btn"
          >
            {voting ? 'Voting...' : 'vote'}
          </button>
        </div>
      ) : isNew ? (
        <div>
          {poll.options.map((option, idx) => (
            <div key={idx} className="poll-display__option">
              <input type="radio" disabled className="poll-display__radio" />
              {option}
            </div>
          ))}
        </div>
      ) : (
        <table className="poll-display__results-table">
          <tbody>
            {poll.options.map((option, idx) => {
              const votes = poll.results[idx] || 0
              const percentage = poll.totalvotes > 0 ? (votes / poll.totalvotes) * 100 : 0
              const isUserVote = poll.user_vote === idx

              return (
                <React.Fragment key={idx}>
                  <tr className="poll-display__result-row">
                    <td className="poll-display__result-cell">
                      {isUserVote ? <strong>{option}</strong> : option}
                    </td>
                    <td className="poll-display__result-cell poll-display__result-cell--votes">
                      {votes}
                    </td>
                    <td className="poll-display__result-cell poll-display__result-cell--percent">
                      {percentage.toFixed(2)}%
                    </td>
                  </tr>
                  <tr>
                    <td colSpan="3" className="poll-display__bar-cell">
                      <div className="poll-display__bar" style={{ width: `${Math.min(100, percentage * 1.8)}%` }} />
                    </td>
                  </tr>
                </React.Fragment>
              )
            })}
            <tr className="poll-display__total-row">
              <td className="poll-display__total-cell">Total</td>
              <td className="poll-display__total-cell poll-display__total-cell--right">
                {poll.totalvotes}
              </td>
              <td className="poll-display__total-cell poll-display__total-cell--right">
                100.00%
              </td>
            </tr>
          </tbody>
        </table>
      )}

      {/* Admin delete vote button */}
      {isAdmin && hasVoted && showResults && onDeleteVote && (
        <div className="poll-display__delete-vote">
          <button
            onClick={handleDeleteVote}
            disabled={deleting}
            className="poll-display__delete-btn"
          >
            {deleting ? 'Deleting...' : 'Delete my vote (admin)'}
          </button>
        </div>
      )}
    </div>
  )
}

export default PollDisplay

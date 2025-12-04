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

  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111'
  }

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

  // Styles
  const containerStyle = {
    marginBottom: '30px'
  }

  const headerStyle = {
    marginBottom: '10px'
  }

  const titleStyle = {
    fontSize: '24px',
    color: colors.primary,
    marginBottom: '5px'
  }

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none'
  }

  const authorStyle = {
    fontSize: '14px',
    color: colors.secondary,
    fontStyle: 'italic',
    marginBottom: '15px'
  }

  const questionStyle = {
    fontSize: '18px',
    color: colors.text,
    fontWeight: '600',
    marginBottom: '20px'
  }

  const optionStyle = {
    marginBottom: '8px',
    fontSize: '14px'
  }

  const radioStyle = {
    marginRight: '8px'
  }

  const buttonStyle = {
    padding: '8px 20px',
    backgroundColor: voting ? '#999' : colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: voting ? 'wait' : 'pointer',
    fontSize: '14px',
    fontWeight: '600',
    marginTop: '15px'
  }

  const tableStyle = {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px'
  }

  const rowStyle = {
    borderBottom: `1px solid ${colors.background}`
  }

  const cellStyle = {
    padding: '8px 4px'
  }

  const barStyle = (percentage) => ({
    height: '8px',
    backgroundColor: colors.accent,
    width: `${Math.min(100, percentage)}%`,
    marginTop: '4px'
  })

  return (
    <div style={containerStyle}>
      {/* Title - only show if not on own page */}
      {!isOwnPage && (
        <div style={headerStyle}>
          <h2 style={titleStyle}>
            <a href={`/node/${poll.poll_id}`} style={linkStyle}>
              {poll.title}
            </a>
            {showStatus && ` (${poll.poll_status})`}
          </h2>
        </div>
      )}

      {/* Author */}
      <div style={authorStyle}>
        by <a href={`/user/${poll.poll_author.title}`} style={linkStyle}>{poll.poll_author.title}</a>
        {canEdit && isNew && (
          <small>
            {' '}(<a href={`/node/${poll.poll_id}?displaytype=edit`} style={linkStyle}>edit</a>)
          </small>
        )}
      </div>

      {/* Question */}
      <h3 style={questionStyle}>{poll.question}</h3>

      {/* Voting form or results */}
      {!showResults && !isNew ? (
        <div>
          {poll.options.map((option, idx) => (
            <div key={idx} style={optionStyle}>
              <label>
                <input
                  type="radio"
                  name={`poll_${poll.poll_id}`}
                  value={idx}
                  checked={selectedOption === idx}
                  onChange={() => setSelectedOption(idx)}
                  style={radioStyle}
                />
                {option}
              </label>
            </div>
          ))}
          <button
            onClick={handleVote}
            disabled={selectedOption === null || voting}
            style={buttonStyle}
          >
            {voting ? 'Voting...' : 'vote'}
          </button>
        </div>
      ) : isNew ? (
        <div>
          {poll.options.map((option, idx) => (
            <div key={idx} style={optionStyle}>
              <input type="radio" disabled style={radioStyle} />
              {option}
            </div>
          ))}
        </div>
      ) : (
        <table style={tableStyle}>
          <tbody>
            {poll.options.map((option, idx) => {
              const votes = poll.results[idx] || 0
              const percentage = poll.totalvotes > 0 ? (votes / poll.totalvotes) * 100 : 0
              const isUserVote = poll.user_vote === idx

              return (
                <React.Fragment key={idx}>
                  <tr style={rowStyle}>
                    <td style={cellStyle}>
                      {isUserVote ? <strong>{option}</strong> : option}
                    </td>
                    <td style={{ ...cellStyle, textAlign: 'right', width: '60px' }}>
                      {votes}
                    </td>
                    <td style={{ ...cellStyle, textAlign: 'right', width: '60px' }}>
                      {percentage.toFixed(2)}%
                    </td>
                  </tr>
                  <tr>
                    <td colSpan="3" style={{ padding: '0 4px 8px 4px' }}>
                      <div style={barStyle(percentage * 1.8)} />
                    </td>
                  </tr>
                </React.Fragment>
              )
            })}
            <tr style={{ borderTop: `2px solid ${colors.primary}` }}>
              <td style={{ ...cellStyle, fontWeight: 'bold' }}>Total</td>
              <td style={{ ...cellStyle, textAlign: 'right', fontWeight: 'bold' }}>
                {poll.totalvotes}
              </td>
              <td style={{ ...cellStyle, textAlign: 'right', fontWeight: 'bold' }}>
                100.00%
              </td>
            </tr>
          </tbody>
        </table>
      )}

      {/* Admin delete vote button */}
      {isAdmin && hasVoted && showResults && onDeleteVote && (
        <div style={{ marginTop: '15px' }}>
          <button
            onClick={handleDeleteVote}
            disabled={deleting}
            style={{
              padding: '6px 12px',
              backgroundColor: deleting ? '#999' : colors.error || '#c75050',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: deleting ? 'wait' : 'pointer',
              fontSize: '12px'
            }}
          >
            {deleting ? 'Deleting...' : 'Delete my vote (admin)'}
          </button>
        </div>
      )}
    </div>
  )
}

export default PollDisplay

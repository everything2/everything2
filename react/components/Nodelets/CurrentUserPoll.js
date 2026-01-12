import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

const CurrentUserPoll = (props) => {
  const [selectedOption, setSelectedOption] = React.useState(null)
  const [pollData, setPollData] = React.useState(props.currentPoll)
  const [isVoting, setIsVoting] = React.useState(false)
  const [isDeleting, setIsDeleting] = React.useState(false)
  const [voteError, setVoteError] = React.useState(null)

  // Update local poll data when props change
  React.useEffect(() => {
    if (props.currentPoll) {
      setPollData(props.currentPoll)
    }
  }, [props.currentPoll])

  if (!pollData) {
    return (
      <NodeletContainer
        id={props.id}
      title="Current Poll"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p className="poll-empty">No current poll.</p>
      </NodeletContainer>
    )
  }

  const poll = pollData
  const hasVoted = poll.userVote !== null && poll.userVote !== undefined && poll.userVote >= 0
  const isClosed = poll.poll_status === 'closed'
  const isNew = poll.poll_status === 'new'
  const showVoting = !hasVoted && !isClosed && !isNew
  const showResults = hasVoted || isClosed
  const isAdmin = props.user && props.user.admin

  const handleVote = async (e) => {
    e.preventDefault()
    if (selectedOption === null) return

    setIsVoting(true)
    setVoteError(null)

    try {
      const response = await fetch('/api/poll/vote', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          poll_id: poll.node_id,
          choice: selectedOption
        }),
        credentials: 'include'
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || 'Failed to submit vote')
      }

      // Update poll data with the response
      if (data.poll) {
        setPollData(data.poll)
        setSelectedOption(null)
      }
    } catch (error) {
      setVoteError(error.message)
    } finally {
      setIsVoting(false)
    }
  }

  const handleDeleteVote = async () => {
    if (!isAdmin || !hasVoted) return
    if (!confirm('Delete your vote from this poll?')) return

    setIsDeleting(true)
    setVoteError(null)

    try {
      const response = await fetch('/api/poll/delete_vote', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          poll_id: poll.node_id,
          voter_user: props.user.node_id
        }),
        credentials: 'include'
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || 'Failed to delete vote')
      }

      // Refresh poll data after deletion
      // Set userVote to -1 to indicate no vote
      const updatedPoll = {
        ...poll,
        totalvotes: data.new_total,
        userVote: -1
      }

      // Recalculate results
      const newResults = [...poll.e2poll_results]
      if (poll.userVote >= 0 && poll.userVote < newResults.length) {
        newResults[poll.userVote] = Math.max(0, newResults[poll.userVote] - 1)
        updatedPoll.e2poll_results = newResults
      }

      setPollData(updatedPoll)
    } catch (error) {
      setVoteError(error.message)
    } finally {
      setIsDeleting(false)
    }
  }

  const calculatePercentage = (votes, total) => {
    if (total === 0) return '0.00'
    return ((votes / total) * 100).toFixed(2)
  }

  const calculateBarWidth = (votes, total) => {
    if (total === 0) return 0
    return Math.round((votes / total) * 180)
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Current Poll"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <div className="poll-content">
        <h2 className="poll-title">
          <LinkNode id={poll.node_id} display={poll.title} />
          {poll.poll_status !== 'current' && ` (${poll.poll_status})`}
        </h2>
        <p className="poll-author">
          by <LinkNode id={poll.poll_author} display={poll.author_name} className="author" />
        </p>
        <h3 className="poll-question">
          <ParseLinks text={poll.question} />
        </h3>

        {showVoting && (
          <form
            className="poll-form"
            onSubmit={handleVote}
          >
            {voteError && (
              <div className="poll-error">
                {voteError}
              </div>
            )}
            {poll.options.map((option, index) => (
              <div key={index} className="poll-option">
                <label className={`poll-option-label${isVoting ? ' poll-option-label--disabled' : ''}`}>
                  <input
                    type="radio"
                    name="vote_radio"
                    value={index}
                    checked={selectedOption === index}
                    onChange={() => setSelectedOption(index)}
                    disabled={isVoting}
                    className="poll-radio"
                  />
                  <ParseLinks text={option} />
                </label>
              </div>
            ))}
            <input
              type="submit"
              value={isVoting ? 'Voting...' : 'vote'}
              disabled={isVoting || selectedOption === null}
              className="poll-vote-btn"
            />
          </form>
        )}

        {isNew && (
          <form className="poll-form">
            {poll.options.map((option, index) => (
              <div key={index} className="poll-option">
                <label className="poll-option-label poll-option-label--disabled">
                  <input
                    type="radio"
                    name="vote_inactive"
                    disabled
                    className="poll-radio"
                  />
                  <ParseLinks text={option} />
                </label>
              </div>
            ))}
          </form>
        )}

        {showResults && (
          <>
            <table className="poll-results-table">
              <tbody>
                {poll.options.map((option, index) => {
                  const votes = poll.e2poll_results[index] || 0
                  const percentage = calculatePercentage(votes, poll.totalvotes)
                  const barWidth = calculateBarWidth(votes, poll.totalvotes)
                  const isUserVote = index === poll.userVote

                  return (
                    <React.Fragment key={index}>
                      <tr>
                        <td className="poll-results-cell">
                          {isUserVote ? <strong><ParseLinks text={option} /></strong> : <ParseLinks text={option} />}
                        </td>
                        <td align="right" className="poll-results-cell">
                          &nbsp;{votes}&nbsp;
                        </td>
                        <td align="right" className="poll-results-cell">
                          {percentage}%
                        </td>
                      </tr>
                      <tr>
                        <td colSpan="3" className="poll-results-bar-cell">
                          <div
                            className="poll-results-bar"
                            style={{ width: `${barWidth}px` }}
                          />
                        </td>
                      </tr>
                    </React.Fragment>
                  )
                })}
                <tr>
                  <td className="poll-results-cell">
                    <strong>Total</strong>
                  </td>
                  <td align="right" className="poll-results-cell">
                    &nbsp;{poll.totalvotes}&nbsp;
                  </td>
                  <td align="right" className="poll-results-cell">
                    100.00%
                  </td>
                </tr>
              </tbody>
            </table>
            {isAdmin && hasVoted && (
              <div className="poll-admin-actions">
                <button
                  onClick={handleDeleteVote}
                  disabled={isDeleting}
                  className="poll-delete-vote-btn"
                >
                  {isDeleting ? 'Deleting...' : 'Delete my vote (admin)'}
                </button>
              </div>
            )}
          </>
        )}

        {voteError && showResults && (
          <div className="poll-error poll-error--results">
            {voteError}
          </div>
        )}
      </div>

      <div className="nodeletfoot poll-footer">
        <LinkNode title="Everything Poll Archive" type="superdoc" display="Past polls" />
        {' | '}
        <LinkNode title="Everything Poll Directory" type="superdoc" display="Future polls" />
        {' | '}
        <LinkNode title="Everything Poll Creator" type="superdoc" display="New poll" />
        <br />
        <LinkNode title="Polls" display="About polls" />
      </div>
    </NodeletContainer>
  )
}

export default CurrentUserPoll

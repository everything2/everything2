import React, { useState, useEffect } from 'react'
import PollDisplay from '../Poll/PollDisplay'

/**
 * EverythingUserPoll - Display the current active poll
 *
 * Features:
 * - Shows the current poll with voting or results
 * - Links to Archive, Directory, Creator, and About polls
 */
const EverythingUserPoll = ({ data, user }) => {
  const [poll, setPoll] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111',
    error: '#c75050'
  }

  useEffect(() => {
    fetchCurrentPoll()
  }, [])

  const fetchCurrentPoll = async () => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch('/api/polls/list?status=current&limit=1')
      const result = await response.json()

      if (result.success) {
        if (result.polls && result.polls.length > 0) {
          setPoll(result.polls[0])
        } else {
          setError('No current poll.')
        }
      } else {
        setError(result.error || 'Failed to load current poll')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }

    setLoading(false)
  }

  const handleVote = async (pollId, choice) => {
    setError(null)

    try {
      const response = await fetch('/api/poll/vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          poll_id: pollId,
          choice: choice
        })
      })

      const result = await response.json()

      if (result.success && result.poll) {
        // Update poll with new data
        setPoll({
          ...poll,
          totalvotes: result.poll.totalvotes,
          results: result.poll.e2poll_results,
          user_vote: result.poll.userVote
        })
      } else {
        setError(result.error || 'Failed to submit vote')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '900px',
    margin: '0 auto'
  }

  const footerStyle = {
    marginTop: '30px',
    padding: '15px',
    backgroundColor: colors.background,
    borderTop: `2px solid ${colors.primary}`,
    textAlign: 'center',
    fontSize: '14px'
  }

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    marginRight: '10px'
  }

  const errorStyle = {
    padding: '15px',
    backgroundColor: '#fff5f5',
    border: `1px solid #feb2b2`,
    color: colors.error,
    borderRadius: '4px',
    marginBottom: '20px'
  }

  const loadingStyle = {
    textAlign: 'center',
    padding: '40px',
    color: colors.secondary,
    fontSize: '16px'
  }

  return (
    <div style={containerStyle}>
      {/* Error message */}
      {error && <div style={errorStyle}>{error}</div>}

      {/* Loading state */}
      {loading && <div style={loadingStyle}>Loading current poll...</div>}

      {/* Current poll */}
      {!loading && poll && (
        <>
          <PollDisplay
            poll={poll}
            showStatus={false}
            isOwnPage={true}
            canEdit={false}
            onVote={handleVote}
          />

          {/* Footer with links */}
          <div style={footerStyle}>
            <a href="/title/Everything%20Poll%20Archive" style={linkStyle}>Past polls</a>
            <span> | </span>
            <a href="/title/Everything%20Poll%20Directory" style={linkStyle}>Future polls</a>
            <span> | </span>
            <a href="/title/Everything%20Poll%20Creator" style={linkStyle}>New poll</a>
            <br />
            <a href="/node/Polls" style={linkStyle}>About polls</a>
          </div>
        </>
      )}
    </div>
  )
}

export default EverythingUserPoll

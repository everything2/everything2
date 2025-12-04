import React, { useState, useEffect } from 'react'
import PollDisplay from '../Poll/PollDisplay'

/**
 * EverythingPollArchive - Browse closed/completed polls
 *
 * Features:
 * - List closed polls with results
 * - Pagination
 * - Simple display-only (no voting or admin actions)
 */
const EverythingPollArchive = ({ data, user }) => {
  const [polls, setPolls] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [startat, setStartat] = useState(0)
  const [hasMore, setHasMore] = useState(false)

  const limit = 10

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
    fetchPolls()
  }, [startat])

  const fetchPolls = async () => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch(`/api/polls/list?status=closed&startat=${startat}&limit=${limit}`)
      const result = await response.json()

      if (result.success) {
        setPolls(result.polls)
        setHasMore(result.has_more)
      } else {
        setError(result.error || 'Failed to load polls')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }

    setLoading(false)
  }

  const handlePrevious = () => {
    if (startat >= limit) {
      setStartat(startat - limit)
    }
  }

  const handleNext = () => {
    if (hasMore) {
      setStartat(startat + limit)
    }
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '900px',
    margin: '0 auto'
  }

  const headerStyle = {
    marginBottom: '30px',
    borderBottom: `2px solid ${colors.primary}`,
    paddingBottom: '15px'
  }

  const titleStyle = {
    fontSize: '28px',
    color: colors.primary,
    marginBottom: '15px'
  }

  const paginationStyle = {
    textAlign: 'right',
    marginTop: '20px',
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
      {/* Header */}
      <div style={headerStyle}>
        <h1 style={titleStyle}>Everything Poll Archive</h1>
      </div>

      {/* Error message */}
      {error && <div style={errorStyle}>{error}</div>}

      {/* Loading state */}
      {loading && <div style={loadingStyle}>Loading polls...</div>}

      {/* Polls list */}
      {!loading && (
        <>
          {polls.length === 0 ? (
            <div style={loadingStyle}>No polls found in the archive.</div>
          ) : (
            <ul style={{ listStyleType: 'none', padding: 0 }}>
              {polls.map((poll) => (
                <li key={poll.poll_id} style={{ marginBottom: '40px' }}>
                  <PollDisplay
                    poll={poll}
                    showStatus={false}
                    isOwnPage={false}
                    canEdit={false}
                  />
                </li>
              ))}
            </ul>
          )}

          {/* Pagination */}
          {(startat > 0 || hasMore) && (
            <div style={paginationStyle}>
              {startat > 0 && (
                <>
                  <a href="#" onClick={(e) => { e.preventDefault(); handlePrevious() }} style={linkStyle}>
                    previous
                  </a>
                  {' '}
                </>
              )}
              {hasMore && (
                <a href="#" onClick={(e) => { e.preventDefault(); handleNext() }} style={linkStyle}>
                  next
                </a>
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default EverythingPollArchive

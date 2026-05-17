import React, { useState, useEffect } from 'react'
import PollDisplay from '../Poll/PollDisplay'

/**
 * EverythingPollArchive - Browse closed/completed polls
 * Styles in CSS: .poll-archive__*
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

  return (
    <div className="poll-archive">
      {/* Header */}
      <div className="poll-archive__header">
        <h1 className="poll-archive__title">Everything Poll Archive</h1>
      </div>

      {/* Error message */}
      {error && <div className="poll-archive__error">{error}</div>}

      {/* Loading state */}
      {loading && <div className="poll-archive__loading">Loading polls...</div>}

      {/* Polls list */}
      {!loading && (
        <>
          {polls.length === 0 ? (
            <div className="poll-archive__loading">No polls found in the archive.</div>
          ) : (
            <ul className="poll-archive__list">
              {polls.map((poll) => (
                <li key={poll.poll_id} className="poll-archive__list-item">
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
            <div className="poll-archive__pagination">
              {startat > 0 && (
                <>
                  <a href="#" onClick={(e) => { e.preventDefault(); handlePrevious() }} className="poll-archive__link">
                    previous
                  </a>
                  {' '}
                </>
              )}
              {hasMore && (
                <a href="#" onClick={(e) => { e.preventDefault(); handleNext() }} className="poll-archive__link">
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

import React, { useState, useCallback } from 'react'
import PollDisplay from '../Poll/PollDisplay'
import { FaList, FaPoll, FaPlus, FaBook } from 'react-icons/fa'

/**
 * E2Poll - Display page for e2poll nodes (user polls)
 *
 * Features:
 * - Displays poll question with voting interface
 * - Shows results after voting or when closed
 * - Links to poll directory, archive, and creator
 */
const E2Poll = ({ data, user }) => {
  const { poll, user: userData } = data || {}

  // Local state for poll data (to update after voting)
  const [pollData, setPollData] = useState(poll)
  const [error, setError] = useState(null)

  if (!pollData) return null

  const isGuest = user?.guest || userData?.is_guest
  const isAdmin = user?.admin || userData?.is_admin

  const {
    poll_id,
    title,
    question,
    options,
    results,
    totalvotes,
    poll_status,
    poll_author,
    user_vote,
    can_edit,
    type_nodetype
  } = pollData

  // Handle vote submission
  const handleVote = useCallback(async (pollId, choice) => {
    setError(null)

    try {
      const response = await fetch('/api/poll/vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({
          poll_id: pollId,
          choice: choice
        })
      })

      const result = await response.json()

      if (result.success && result.poll) {
        // Update local poll data with new results
        setPollData(prev => ({
          ...prev,
          totalvotes: result.poll.totalvotes,
          results: result.poll.e2poll_results,
          user_vote: result.poll.userVote
        }))
      } else {
        setError(result.error || 'Failed to submit vote')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }
  }, [])

  // Handle vote deletion (admin only)
  const handleDeleteVote = useCallback(async (pollId, userId) => {
    setError(null)

    try {
      const response = await fetch('/api/poll/delete_vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({
          poll_id: pollId,
          voter_user: userId
        })
      })

      const result = await response.json()

      if (result.success) {
        // Refresh page to get accurate results
        window.location.reload()
      } else {
        setError(result.error || 'Failed to delete vote')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }
  }, [])

  // Transform poll data for PollDisplay component
  const pollForDisplay = {
    poll_id,
    title,
    question,
    options,
    results,
    totalvotes,
    poll_status,
    poll_author,
    user_vote
  }

  // Get status badge class based on status
  const getStatusBadgeClass = (status) => {
    const base = 'e2poll__status-badge'
    switch (status) {
      case 'current':
        return `${base} e2poll__status-badge--current`
      case 'open':
        return `${base} e2poll__status-badge--open`
      case 'closed':
        return `${base} e2poll__status-badge--closed`
      case 'new':
      default:
        return `${base} e2poll__status-badge--new`
    }
  }

  return (
    <div className="e2poll">
      {/* Action Bar */}
      <div className="e2poll__action-bar">
        <a
          href="/title/Everything%20Poll%20Directory"
          className="e2poll__action-btn"
        >
          <FaList size={12} /> Poll Directory
        </a>
        <a
          href="/title/Everything%20Poll%20Archive"
          className="e2poll__action-btn e2poll__action-btn--secondary"
        >
          <FaPoll size={12} /> Poll Archive
        </a>
        {!isGuest && (
          <a
            href="/title/Everything%20Poll%20Creator"
            className="e2poll__action-btn e2poll__action-btn--secondary"
          >
            <FaPlus size={12} /> Create Poll
          </a>
        )}
        <a
          href="/title/Polls"
          className="e2poll__action-btn e2poll__action-btn--secondary"
        >
          <FaBook size={12} /> About Polls
        </a>
      </div>

      {/* Error message */}
      {error && <div className="e2poll__error">{error}</div>}

      {/* Poll Display */}
      <div className="e2poll__container">
        {/* Status badge at top */}
        <div className="e2poll__status-row">
          <span className={getStatusBadgeClass(poll_status)}>
            {poll_status}
          </span>
        </div>

        <PollDisplay
          poll={pollForDisplay}
          showStatus={false}
          isOwnPage={true}
          canEdit={can_edit}
          isAdmin={isAdmin}
          userId={userData?.node_id}
          onVote={handleVote}
          onDeleteVote={handleDeleteVote}
        />
      </div>

      {/* Links Section */}
      <div className="e2poll__links">
        <a href="/title/Everything%20Poll%20Archive" className="e2poll__link">
          Past polls
        </a>
        <span className="e2poll__link-separator"> | </span>
        <a href="/title/Everything%20Poll%20Directory" className="e2poll__link">
          Future polls
        </a>
        <span className="e2poll__link-separator"> | </span>
        <a href="/title/Everything%20Poll%20Creator" className="e2poll__link">
          New poll
        </a>
        <span className="e2poll__link-separator"> | </span>
        <a href="/title/Polls" className="e2poll__link">
          About polls
        </a>
      </div>
    </div>
  )
}

export default E2Poll

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

  const styles = {
    container: {
      maxWidth: '900px',
      margin: '0 auto',
      padding: '0'
    },
    actionBar: {
      display: 'flex',
      gap: '10px',
      marginBottom: '20px',
      flexWrap: 'wrap'
    },
    actionButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      backgroundColor: '#4060b0',
      color: 'white',
      textDecoration: 'none',
      borderRadius: '4px',
      fontSize: '13px',
      fontWeight: '500',
      border: 'none',
      cursor: 'pointer'
    },
    actionButtonSecondary: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      backgroundColor: '#507898',
      color: 'white',
      textDecoration: 'none',
      borderRadius: '4px',
      fontSize: '13px',
      fontWeight: '500',
      border: 'none',
      cursor: 'pointer'
    },
    pollContainer: {
      backgroundColor: '#f8f9fa',
      borderRadius: '6px',
      border: '1px solid #dee2e6',
      padding: '20px',
      marginBottom: '20px'
    },
    statusBadge: {
      display: 'inline-block',
      padding: '4px 10px',
      borderRadius: '12px',
      fontSize: '12px',
      fontWeight: '500',
      marginLeft: '10px'
    },
    error: {
      padding: '15px',
      backgroundColor: '#fff5f5',
      border: '1px solid #feb2b2',
      color: '#c75050',
      borderRadius: '4px',
      marginBottom: '20px'
    },
    linksSection: {
      marginTop: '20px',
      padding: '15px',
      backgroundColor: '#f8f9fa',
      borderRadius: '6px',
      border: '1px solid #dee2e6',
      textAlign: 'right'
    },
    link: {
      color: '#4060b0',
      textDecoration: 'none',
      marginLeft: '15px',
      fontSize: '14px'
    }
  }

  // Get status badge style
  const getStatusStyle = (status) => {
    switch (status) {
      case 'current':
        return { backgroundColor: '#d4edda', color: '#155724' }
      case 'open':
        return { backgroundColor: '#cce5ff', color: '#004085' }
      case 'closed':
        return { backgroundColor: '#e2e3e5', color: '#383d41' }
      case 'new':
      default:
        return { backgroundColor: '#fff3cd', color: '#856404' }
    }
  }

  return (
    <div style={styles.container}>
      {/* Action Bar */}
      <div style={styles.actionBar}>
        <a
          href="/title/Everything%20Poll%20Directory"
          style={styles.actionButton}
        >
          <FaList size={12} /> Poll Directory
        </a>
        <a
          href="/title/Everything%20Poll%20Archive"
          style={styles.actionButtonSecondary}
        >
          <FaPoll size={12} /> Poll Archive
        </a>
        {!isGuest && (
          <a
            href="/title/Everything%20Poll%20Creator"
            style={styles.actionButtonSecondary}
          >
            <FaPlus size={12} /> Create Poll
          </a>
        )}
        <a
          href="/title/Polls"
          style={styles.actionButtonSecondary}
        >
          <FaBook size={12} /> About Polls
        </a>
      </div>

      {/* Error message */}
      {error && <div style={styles.error}>{error}</div>}

      {/* Poll Display */}
      <div style={styles.pollContainer}>
        {/* Status badge at top */}
        <div style={{ marginBottom: '15px' }}>
          <span style={{ ...styles.statusBadge, ...getStatusStyle(poll_status), marginLeft: 0 }}>
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
      <div style={styles.linksSection}>
        <a href="/title/Everything%20Poll%20Archive" style={styles.link}>
          Past polls
        </a>
        <span style={{ color: '#999' }}> | </span>
        <a href="/title/Everything%20Poll%20Directory" style={styles.link}>
          Future polls
        </a>
        <span style={{ color: '#999' }}> | </span>
        <a href="/title/Everything%20Poll%20Creator" style={styles.link}>
          New poll
        </a>
        <span style={{ color: '#999' }}> | </span>
        <a href="/title/Polls" style={styles.link}>
          About polls
        </a>
      </div>
    </div>
  )
}

export default E2Poll

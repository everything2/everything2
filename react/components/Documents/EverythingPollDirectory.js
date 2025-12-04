import React, { useState, useEffect } from 'react'
import Modal from 'react-modal'
import { FaExclamationTriangle, FaTrashAlt } from 'react-icons/fa'
import PollDisplay from '../Poll/PollDisplay'

/**
 * EverythingPollDirectory - Browse and manage polls in the queue
 *
 * Features:
 * - List active polls (not closed)
 * - Admin: Set current poll, edit, delete
 * - Pagination
 * - Option to show/hide old polls
 */
const EverythingPollDirectory = ({ data, user }) => {
  const { is_admin = false } = data || {}

  const [polls, setPolls] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [startat, setStartat] = useState(0)
  const [hasMore, setHasMore] = useState(false)
  const [showOldPolls, setShowOldPolls] = useState(false)
  const [settingCurrent, setSettingCurrent] = useState(null)
  const [deletingVote, setDeletingVote] = useState(null)
  const [deleteModalOpen, setDeleteModalOpen] = useState(false)
  const [pollToDelete, setPollToDelete] = useState(null)
  const [isDeleting, setIsDeleting] = useState(false)

  const limit = 8

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
  }, [startat, showOldPolls])

  const fetchPolls = async () => {
    setLoading(true)
    setError(null)

    try {
      const status = showOldPolls ? 'closed' : 'active'
      const response = await fetch(`/api/polls/list?status=${status}&startat=${startat}&limit=${limit}`)
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

  const handleSetCurrent = async (pollId) => {
    if (!confirm('Make this the current poll? This will close the current poll.')) {
      return
    }

    setSettingCurrent(pollId)

    try {
      const response = await fetch('/api/polls/set_current', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ poll_id: pollId })
      })

      const result = await response.json()

      if (result.success) {
        // Refresh poll list
        await fetchPolls()
      } else {
        alert('Error: ' + (result.error || 'Failed to set current poll'))
      }
    } catch (err) {
      alert('Network error: ' + err.message)
    }

    setSettingCurrent(null)
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
        // Update the poll in the list with new data
        setPolls(prevPolls => prevPolls.map(poll => {
          if (poll.poll_id === pollId) {
            return {
              ...poll,
              totalvotes: result.poll.totalvotes,
              results: result.poll.e2poll_results,
              user_vote: result.poll.userVote
            }
          }
          return poll
        }))
      } else {
        setError(result.error || 'Failed to submit vote')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }
  }

  const handleDeleteVote = async (pollId, userId) => {
    setDeletingVote(pollId)
    setError(null)

    try {
      const response = await fetch('/api/poll/delete_vote', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          poll_id: pollId,
          voter_user: userId
        })
      })

      const result = await response.json()

      if (result.success) {
        // Update the poll in the list with new vote counts
        setPolls(prevPolls => prevPolls.map(poll => {
          if (poll.poll_id === pollId) {
            return {
              ...poll,
              totalvotes: result.new_total,
              user_vote: null // Clear user vote
            }
          }
          return poll
        }))

        // Refresh to get accurate results
        await fetchPolls()
      } else {
        setError(result.error || 'Failed to delete vote')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }

    setDeletingVote(null)
  }

  const openDeleteModal = (poll) => {
    setPollToDelete(poll)
    setDeleteModalOpen(true)
    setError(null)
  }

  const closeDeleteModal = () => {
    setDeleteModalOpen(false)
    setPollToDelete(null)
    setError(null)
  }

  const handleDeletePoll = async () => {
    if (!pollToDelete) return

    setIsDeleting(true)
    setError(null)

    try {
      const response = await fetch(`/api/polls/delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ poll_id: pollToDelete.poll_id })
      })

      const result = await response.json()

      if (result.success) {
        // Remove the poll from the list
        setPolls(prevPolls => prevPolls.filter(poll => poll.poll_id !== pollToDelete.poll_id))
        closeDeleteModal()
      } else {
        setError(result.error || 'Failed to delete poll')
        setIsDeleting(false)
      }
    } catch (err) {
      setError('Network error: ' + err.message)
      setIsDeleting(false)
    }
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

  const toggleOldPolls = () => {
    setStartat(0) // Reset to first page
    setShowOldPolls(!showOldPolls)
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

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    marginRight: '10px'
  }

  const buttonLinkStyle = {
    ...linkStyle,
    cursor: 'pointer',
    background: 'none',
    border: 'none',
    padding: 0,
    fontSize: '14px'
  }

  const adminActionsStyle = {
    padding: '10px',
    backgroundColor: colors.background,
    borderRadius: '4px',
    marginTop: '10px',
    fontSize: '14px'
  }

  const actionButtonStyle = (disabled) => ({
    padding: '4px 12px',
    backgroundColor: disabled ? '#999' : colors.accent,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: disabled ? 'wait' : 'pointer',
    fontSize: '12px',
    marginRight: '8px'
  })

  const paginationStyle = {
    textAlign: 'right',
    marginTop: '20px',
    fontSize: '14px'
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
        <h1 style={titleStyle}>Everything Poll Directory</h1>
        <div>
          <a href="/node/Everything%20User%20Poll" style={linkStyle}>Current User Poll</a>
          {is_admin && (
            <>
              <span> | </span>
              <button onClick={toggleOldPolls} style={buttonLinkStyle}>
                {showOldPolls ? 'Hide old polls' : 'Show old polls'}
              </button>
            </>
          )}
        </div>
      </div>

      {/* Error message */}
      {error && <div style={errorStyle}>{error}</div>}

      {/* Loading state */}
      {loading && <div style={loadingStyle}>Loading polls...</div>}

      {/* Polls list */}
      {!loading && (
        <>
          {polls.length === 0 ? (
            <div style={loadingStyle}>No polls found.</div>
          ) : (
            polls.map((poll) => (
              <div key={poll.poll_id}>
                <PollDisplay
                  poll={poll}
                  showStatus={true}
                  isOwnPage={false}
                  canEdit={false}
                  isAdmin={is_admin}
                  userId={user?.node_id}
                  onVote={handleVote}
                  onDeleteVote={handleDeleteVote}
                />

                {/* Admin actions */}
                {is_admin && (
                  <div style={adminActionsStyle}>
                    {poll.poll_status !== 'current' && (
                      <button
                        onClick={() => handleSetCurrent(poll.poll_id)}
                        disabled={settingCurrent === poll.poll_id}
                        style={actionButtonStyle(settingCurrent === poll.poll_id)}
                      >
                        {settingCurrent === poll.poll_id ? 'Setting...' : 'make current'}
                      </button>
                    )}
                    <a
                      href={`/node/${poll.poll_id}?displaytype=edit`}
                      style={actionButtonStyle(false)}
                    >
                      edit
                    </a>
                    <button
                      onClick={() => openDeleteModal(poll)}
                      style={actionButtonStyle(false)}
                    >
                      delete
                    </button>
                  </div>
                )}
              </div>
            ))
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

      {/* Delete Confirmation Modal */}
      <Modal
        isOpen={deleteModalOpen}
        onRequestClose={closeDeleteModal}
        ariaHideApp={false}
        contentLabel="Confirm Poll Deletion"
        style={{
          content: {
            top: '50%',
            left: '50%',
            right: 'auto',
            bottom: 'auto',
            marginRight: '-50%',
            transform: 'translate(-50%, -50%)',
            minWidth: '400px',
            maxWidth: '600px',
          },
        }}
      >
        <div>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#d9534f' }}>
            <FaExclamationTriangle size={20} /> Confirm Node Deletion
          </h2>

          <div style={{ margin: '20px 0', lineHeight: '1.6' }}>
            <p>
              <strong>Warning:</strong> Nuking a node <strong>removes it immediately</strong> and
              should only be used when you know what the consequences might be.
            </p>
            <p>
              Deleted nodes can be restored if necessary using the resurrection system,
              but you should still use caution.
            </p>
            {pollToDelete && (
              <p style={{ marginTop: '15px', padding: '10px', backgroundColor: '#f5f5f5', border: '1px solid #ddd' }}>
                You are about to delete: <br />
                <strong>{pollToDelete.title}</strong> (e2poll)
              </p>
            )}
          </div>

          {error && (
            <div style={{ color: 'red', padding: '10px', marginBottom: '10px', border: '1px solid red' }}>
              {error}
            </div>
          )}

          <div style={{ textAlign: 'right', marginTop: '20px' }}>
            <button
              type="button"
              onClick={closeDeleteModal}
              disabled={isDeleting}
              style={{
                marginRight: '10px',
                padding: '6px 16px',
                backgroundColor: '#f5f5f5',
                color: '#333',
                border: '1px solid #ccc',
                borderRadius: '3px',
                cursor: isDeleting ? 'not-allowed' : 'pointer',
                fontSize: '0.9em'
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleDeletePoll}
              disabled={isDeleting}
              style={{
                padding: '6px 16px',
                backgroundColor: '#d9534f',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: isDeleting ? 'not-allowed' : 'pointer',
                fontSize: '0.9em',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                opacity: isDeleting ? 0.6 : 1
              }}
            >
              <FaTrashAlt size={12} /> {isDeleting ? 'Deleting...' : 'Delete Node'}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  )
}

export default EverythingPollDirectory

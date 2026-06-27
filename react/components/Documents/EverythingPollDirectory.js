import React, { useState, useEffect } from 'react'
import Modal from 'react-modal'
import { FaExclamationTriangle, FaTrashAlt } from 'react-icons/fa'
import PollDisplay from '../Poll/PollDisplay'

/**
 * EverythingPollDirectory - Browse and manage polls in the queue
 * Styles in CSS: .poll-directory__*
 *
 * Features:
 * - List active polls (not closed)
 * - Admin: Set current poll, edit, delete
 * - Pagination
 * - Option to show/hide old polls
 */
const EverythingPollDirectory = ({ user }) => {
  const isAdmin = !!user?.admin

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

  const getActionBtnClass = (disabled) => {
    return disabled
      ? 'poll-directory__action-btn poll-directory__action-btn--disabled'
      : 'poll-directory__action-btn'
  }

  return (
    <div className="poll-directory">
      {/* Header */}
      <div className="poll-directory__header">
        <h1 className="poll-directory__title">Everything Poll Directory</h1>
        <div>
          <a href="/node/Everything%20User%20Poll" className="poll-directory__link">Current User Poll</a>
          {isAdmin && (
            <>
              <span> | </span>
              <button onClick={toggleOldPolls} className="poll-directory__toggle-btn">
                {showOldPolls ? 'Hide old polls' : 'Show old polls'}
              </button>
            </>
          )}
        </div>
      </div>

      {/* Error message */}
      {error && <div className="poll-directory__error">{error}</div>}

      {/* Loading state */}
      {loading && <div className="poll-directory__loading">Loading polls...</div>}

      {/* Polls list */}
      {!loading && (
        <>
          {polls.length === 0 ? (
            <div className="poll-directory__loading">No polls found.</div>
          ) : (
            polls.map((poll) => (
              <div key={poll.poll_id}>
                <PollDisplay
                  poll={poll}
                  showStatus={true}
                  isOwnPage={false}
                  canEdit={false}
                  isAdmin={isAdmin}
                  userId={user?.node_id}
                  onVote={handleVote}
                  onDeleteVote={handleDeleteVote}
                />

                {/* Admin actions */}
                {isAdmin && (
                  <div className="poll-directory__admin-actions">
                    {poll.poll_status !== 'current' && (
                      <button
                        onClick={() => handleSetCurrent(poll.poll_id)}
                        disabled={settingCurrent === poll.poll_id}
                        className={getActionBtnClass(settingCurrent === poll.poll_id)}
                      >
                        {settingCurrent === poll.poll_id ? 'Setting...' : 'make current'}
                      </button>
                    )}
                    <a
                      href={`/node/${poll.poll_id}?displaytype=edit`}
                      className="poll-directory__action-btn"
                    >
                      edit
                    </a>
                    <button
                      onClick={() => openDeleteModal(poll)}
                      className="poll-directory__action-btn"
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
            <div className="poll-directory__pagination">
              {startat > 0 && (
                <>
                  <a href="#" onClick={(e) => { e.preventDefault(); handlePrevious() }} className="poll-directory__link">
                    previous
                  </a>
                  {' '}
                </>
              )}
              {hasMore && (
                <a href="#" onClick={(e) => { e.preventDefault(); handleNext() }} className="poll-directory__link">
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
        className="poll-directory__modal-content"
        overlayClassName="poll-directory__modal-overlay"
      >
        <div>
          <h2 className="poll-directory__modal-header">
            <FaExclamationTriangle size={20} /> Confirm Node Deletion
          </h2>

          <div className="poll-directory__modal-body">
            <p>
              <strong>Warning:</strong> Nuking a node <strong>removes it immediately</strong> and
              should only be used when you know what the consequences might be.
            </p>
            <p>
              Deleted nodes can be restored if necessary using the resurrection system,
              but you should still use caution.
            </p>
            {pollToDelete && (
              <p className="poll-directory__modal-warning">
                You are about to delete: <br />
                <strong>{pollToDelete.title}</strong> (e2poll)
              </p>
            )}
          </div>

          {error && (
            <div className="poll-directory__modal-error">
              {error}
            </div>
          )}

          <div className="poll-directory__modal-footer">
            <button
              type="button"
              onClick={closeDeleteModal}
              disabled={isDeleting}
              className="poll-directory__modal-cancel-btn"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleDeletePoll}
              disabled={isDeleting}
              className="poll-directory__modal-delete-btn"
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

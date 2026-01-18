import React, { useState, useEffect } from 'react'
import LinkNode from './LinkNode'

/**
 * AdminModal - Modal dialog for writeup tools
 *
 * Shows different options based on user permissions:
 * - Authors: Edit writeup, Remove writeup (return to draft)
 * - Editors: Edit, Hide/unhide, insure, remove, reparent, change author, nodenotes
 * - All logged-in users: Post to usergroup (if they have permission)
 *
 * Usage:
 *   <AdminModal
 *     writeup={writeupData}
 *     user={userData}
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *     onWriteupUpdate={(updatedWriteup) => {}} // Optional callback when writeup state changes
 *     onEdit={() => {}} // Optional callback to trigger edit mode
 *     availableGroups={[{node_id, title}]} // Optional list of usergroups user can post to (fetched if not provided)
 *   />
 */
const AdminModal = ({ writeup, user, isOpen, onClose, onWriteupUpdate, onEdit, availableGroups: propGroups }) => {
  const [removeReason, setRemoveReason] = useState('')
  const [actionStatus, setActionStatus] = useState(null)
  const [isInsured, setIsInsured] = useState(writeup?.insured || false)
  const [isHidden, setIsHidden] = useState(writeup?.notnew || false)
  const [selectedGroup, setSelectedGroup] = useState('')
  const [isPostingToGroup, setIsPostingToGroup] = useState(false)
  const [fetchedGroups, setFetchedGroups] = useState([])
  const [isLoadingGroups, setIsLoadingGroups] = useState(false)

  // Fetch available groups when modal opens if not provided via props
  useEffect(() => {
    if (!isOpen || user?.is_guest || user?.guest) return
    if (propGroups && propGroups.length > 0) return

    const fetchGroups = async () => {
      setIsLoadingGroups(true)
      try {
        const response = await fetch('/api/weblog/available')
        const data = await response.json()
        if (data.success && data.groups) {
          setFetchedGroups(data.groups)
        }
      } catch (error) {
        console.error('Failed to fetch available groups:', error)
      } finally {
        setIsLoadingGroups(false)
      }
    }

    fetchGroups()
  }, [isOpen, user, propGroups])

  // Use prop groups if provided, otherwise use fetched groups
  const availableGroups = (propGroups && propGroups.length > 0) ? propGroups : fetchedGroups

  if (!isOpen || !writeup) return null

  // Use !! to ensure boolean (not 0)
  const isEditor = !!(user?.editor || user?.is_editor)
  const isAdmin = !!(user?.admin || user?.is_admin)
  // Use String() to handle type mismatch between number and string node_id
  const isAuthor = !!(user && writeup.author && String(user.node_id) === String(writeup.author.node_id))
  const hasVoted = writeup.vote !== undefined && writeup.vote !== null
  const hasCooled = writeup.cools && writeup.cools.some(c => String(c.node_id) === String(user?.node_id))

  // Close on backdrop click
  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      handleClose()
    }
  }

  // Handle close - clears action status to prevent stale confirmation messages
  const handleClose = () => {
    setActionStatus(null)
    onClose()
  }

  // Handle hide/unhide writeup
  const handleToggleHide = async () => {
    const action = isHidden ? 'show' : 'hide'
    try {
      const response = await fetch(`/api/hidewriteups/${writeup.node_id}/action/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const data = await response.json()
      if (data.node_id) {
        const newHiddenState = data.notnew
        setIsHidden(newHiddenState)
        setActionStatus({
          type: 'success',
          message: newHiddenState ? 'Writeup hidden' : 'Writeup unhidden'
        })

        // Notify parent component of the update
        if (onWriteupUpdate) {
          onWriteupUpdate({ ...writeup, notnew: newHiddenState })
        }
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Action failed' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    }
  }

  // Handle remove writeup (for editors)
  const handleRemove = async () => {
    if (!removeReason.trim() && isEditor && !isAuthor) {
      setActionStatus({ type: 'error', message: 'Please provide a reason for removal' })
      return
    }
    try {
      const response = await fetch(`/api/admin/writeup/${writeup.node_id}/remove`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reason: removeReason
        })
      })
      const data = await response.json()
      if (data.success) {
        setActionStatus({ type: 'success', message: 'Writeup removed' })
        setTimeout(() => window.location.reload(), 1000)
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Remove failed' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    }
  }

  // Handle insure/uninsure writeup
  const handleInsure = async () => {
    try {
      const response = await fetch(`/api/admin/writeup/${writeup.node_id}/insure`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const data = await response.json()
      if (data.success) {
        const newInsuredState = data.action === 'insured'
        setIsInsured(newInsuredState)
        setActionStatus({
          type: 'success',
          message: data.action === 'insured' ? 'Writeup insured' : 'Writeup uninsured'
        })

        // Notify parent component of the update
        if (onWriteupUpdate) {
          const updatedWriteup = {
            ...writeup,
            insured: newInsuredState,
            insured_by: newInsuredState ? data.insured_by : null
          }
          onWriteupUpdate(updatedWriteup)
        }
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Action failed' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    }
  }

  // Handle remove vote (admin testing only)
  const handleRemoveVote = async () => {
    try {
      const response = await fetch(`/api/admin/writeup/${writeup.node_id}/remove_vote`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const data = await response.json()
      if (data.success) {
        setActionStatus({ type: 'success', message: 'Vote removed' })

        // Notify parent component to update vote state
        if (onWriteupUpdate) {
          const updatedWriteup = {
            ...writeup,
            vote: null,
            reputation: (writeup.reputation || 0) - data.vote_removed,
            upvotes: data.vote_removed === 1 ? (writeup.upvotes || 0) - 1 : writeup.upvotes,
            downvotes: data.vote_removed === -1 ? (writeup.downvotes || 0) - 1 : writeup.downvotes
          }
          onWriteupUpdate(updatedWriteup)
        }
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Remove vote failed' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    }
  }

  // Handle remove C! (admin testing only)
  const handleRemoveCool = async () => {
    try {
      const response = await fetch(`/api/admin/writeup/${writeup.node_id}/remove_cool`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const data = await response.json()
      if (data.success) {
        setActionStatus({ type: 'success', message: 'C! removed' })

        // Notify parent component to update cool state
        if (onWriteupUpdate) {
          const updatedCools = (writeup.cools || []).filter(c => String(c.node_id) !== String(user.node_id))
          const updatedWriteup = {
            ...writeup,
            cools: updatedCools
          }
          onWriteupUpdate(updatedWriteup)
        }
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Remove C! failed' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    }
  }

  // Handle post to usergroup
  const handlePostToGroup = async () => {
    if (!selectedGroup) {
      setActionStatus({ type: 'error', message: 'Please select a usergroup' })
      return
    }

    setIsPostingToGroup(true)

    try {
      // Get the group name before the async call
      const groupName = availableGroups.find(g => String(g.node_id) === String(selectedGroup))?.title || 'usergroup'

      const response = await fetch(`/api/weblog/${selectedGroup}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to_node: writeup.node_id })
      })
      const data = await response.json()

      if (data.success) {
        setActionStatus({ type: 'success', message: `Posted to ${groupName}` })
        setSelectedGroup('')
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Failed to post' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    } finally {
      setIsPostingToGroup(false)
    }
  }

  return (
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="modal-compact">
        <div className="modal-compact__header">
          <h3 className="modal-compact__title">Writeup Tools</h3>
          <button onClick={handleClose} className="modal-compact__close">&times;</button>
        </div>

        <div className="modal-compact__content">
          {/* Status message */}
          {actionStatus && (
            <div className={`modal-compact__status modal-compact__status--${actionStatus.type}`}>
              {actionStatus.message}
            </div>
          )}

          {/* Writeup info */}
          <div className="modal-compact__info">
            <strong>{writeup.title}</strong>
            {writeup.author && (
              <span> by <LinkNode type="user" title={writeup.author.title} /></span>
            )}
            <div className="modal-compact__info-badge">
              Status: Published
              {isHidden && ' · Hidden'}
              {isInsured && ' · Insured'}
            </div>
          </div>

          {/* Edit section - for authors and editors */}
          {(isAuthor || isEditor) && (
            <div className="modal-compact__section">
              {onEdit ? (
                <button
                  onClick={() => {
                    handleClose()
                    onEdit()
                  }}
                  className="modal-compact__action-btn"
                >
                  Edit writeup
                </button>
              ) : (
                <a
                  href={`/node/${writeup.node_id}?edit=1`}
                  className="modal-compact__link-btn"
                >
                  Edit writeup
                </a>
              )}
            </div>
          )}

          {/* Editor actions */}
          {isEditor && (
            <div className="modal-compact__section">
              <h4 className="modal-compact__section-title">Editor Actions</h4>

              <button onClick={handleToggleHide} className="modal-compact__action-btn">
                {isHidden ? 'Unhide' : 'Hide'} writeup
              </button>

              <button onClick={handleInsure} className="modal-compact__action-btn">
                {isInsured ? 'Uninsure' : 'Insure'} writeup
              </button>

              <a
                href={`/node/oppressor_superdoc/Magical Writeup Reparenter?old_writeup_id=${writeup.node_id}`}
                className="modal-compact__link-btn"
              >
                Reparent writeup...
              </a>

              <a
                href={`/node/oppressor_superdoc/Renunciation Chainsaw?wu_id=${writeup.node_id}`}
                className="modal-compact__link-btn"
              >
                Change author...
              </a>
            </div>
          )}

          {/* Remove section - only show if writeup is not insured */}
          {!isInsured && (isEditor || isAuthor) && (
            <div className="modal-compact__section">
              <h4 className="modal-compact__section-title">
                {isAuthor && !isEditor ? 'Remove Writeup' : 'Remove'}
              </h4>

              {isEditor && !isAuthor && (
                <input
                  type="text"
                  placeholder="Reason for removal"
                  value={removeReason}
                  onChange={(e) => setRemoveReason(e.target.value)}
                  className="modal-compact__input"
                />
              )}

              <button
                onClick={handleRemove}
                className="modal-compact__action-btn modal-compact__action-btn--danger"
              >
                {isAuthor ? 'Return to drafts' : 'Remove writeup'}
              </button>

              {isAuthor && (
                <p className="modal-compact__help">
                  This will unpublish your writeup and return it to draft status.
                </p>
              )}
            </div>
          )}

          {/* Admin tools - only show if not author AND has voted or cooled */}
          {isAdmin && !isAuthor && (hasVoted || hasCooled) && (
            <div className="modal-compact__section">
              <h4 className="modal-compact__section-title">Admin Tools</h4>

              {hasVoted && (
                <button onClick={handleRemoveVote} className="modal-compact__action-btn">
                  Remove my vote
                </button>
              )}

              {hasCooled && (
                <button onClick={handleRemoveCool} className="modal-compact__action-btn">
                  Remove my C!
                </button>
              )}
            </div>
          )}

          {/* Post to usergroup - show for logged-in users */}
          {!user?.is_guest && !user?.guest && (isLoadingGroups || (availableGroups && availableGroups.length > 0)) && (
            <div className="modal-compact__section">
              <h4 className="modal-compact__section-title">Post to Usergroup</h4>

              {isLoadingGroups ? (
                <p className="modal-compact__help">Loading available groups...</p>
              ) : (
                <>
                  <select
                    value={selectedGroup}
                    onChange={(e) => setSelectedGroup(e.target.value)}
                    className="modal-compact__select"
                    disabled={isPostingToGroup}
                  >
                    <option value="">Select a usergroup...</option>
                    {availableGroups.map((group) => (
                      <option key={group.node_id} value={group.node_id}>
                        {group.ify_display
                          ? `${group.ify_display} (${group.title})`
                          : group.title}
                      </option>
                    ))}
                  </select>

                  <button
                    onClick={handlePostToGroup}
                    disabled={!selectedGroup || isPostingToGroup}
                    className="modal-compact__action-btn"
                  >
                    {isPostingToGroup ? 'Posting...' : 'Post to usergroup'}
                  </button>

                  <p className="modal-compact__help">
                    Share this writeup to a usergroup weblog.
                  </p>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default AdminModal

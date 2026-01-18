import React, { useState, useEffect } from 'react'
import { FaShareSquare } from 'react-icons/fa'

/**
 * AddToWeblogModal - Modal for adding a node to a usergroup weblog
 *
 * Shows available usergroups the user can post to, organized by:
 * - Groups with custom display names (from webloggables setting)
 * - Standard group names
 *
 * Usage:
 *   <AddToWeblogModal
 *     nodeId={123}
 *     nodeTitle="Some Title"
 *     nodeType="writeup"
 *     user={userData}
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *   />
 *
 * Or with the built-in button:
 *   <AddToWeblogButton nodeId={123} nodeTitle="Some Title" nodeType="writeup" user={userData} />
 */

const AddToWeblogModal = ({ nodeId, nodeTitle, nodeType, user, isOpen, onClose }) => {
  const [selectedGroup, setSelectedGroup] = useState('')
  const [isPosting, setIsPosting] = useState(false)
  const [groups, setGroups] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  const [actionStatus, setActionStatus] = useState(null)

  // Fetch available groups when modal opens
  useEffect(() => {
    if (!isOpen || user?.is_guest || user?.guest) return

    const fetchGroups = async () => {
      setIsLoading(true)
      try {
        const response = await fetch('/api/weblog/available')
        const data = await response.json()
        if (data.success && data.groups) {
          setGroups(data.groups)
        }
      } catch (error) {
        console.error('Failed to fetch available groups:', error)
      } finally {
        setIsLoading(false)
      }
    }

    fetchGroups()
  }, [isOpen, user])

  // Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setSelectedGroup('')
      setActionStatus(null)
    }
  }, [isOpen])

  if (!isOpen) return null

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  const handlePostToGroup = async () => {
    if (!selectedGroup) {
      setActionStatus({ type: 'error', message: 'Please select a usergroup' })
      return
    }

    setIsPosting(true)
    setActionStatus(null)

    try {
      const groupName = groups.find(g => String(g.node_id) === String(selectedGroup))?.title || 'usergroup'

      const response = await fetch(`/api/weblog/${selectedGroup}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to_node: nodeId })
      })

      const data = await response.json()

      if (data.success) {
        setActionStatus({
          type: 'success',
          message: `Posted to ${groupName}`
        })
        setSelectedGroup('')
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Failed to post' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    } finally {
      setIsPosting(false)
    }
  }

  return (
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="modal-compact">
        <div className="modal-compact__header">
          <h3 className="modal-compact__title">Add to Page</h3>
          <button onClick={onClose} className="modal-compact__close">&times;</button>
        </div>

        <div className="modal-compact__content">
          {/* Status message */}
          {actionStatus && (
            <div className={`modal-compact__status modal-compact__status--${actionStatus.type}`}>
              {actionStatus.message}
            </div>
          )}

          {isLoading ? (
            <p className="modal-compact__help">Loading usergroups...</p>
          ) : groups.length === 0 ? (
            <div>
              <p className="modal-compact__help">
                No usergroups available. You need to be a member of a usergroup to post to its weblog.
              </p>
              <p className="modal-compact__help mt-2">
                <a href="/node/superdoc/Edit%20weblog%20menu" className="modal-compact__link">
                  Edit weblog menu...
                </a>
              </p>
            </div>
          ) : (
            <>
              <p className="mb-3" style={{ fontSize: '12px', margin: 0 }}>
                Add <strong>{nodeTitle}</strong> to a usergroup page:
              </p>

              <select
                value={selectedGroup}
                onChange={(e) => setSelectedGroup(e.target.value)}
                className="modal-compact__select"
                disabled={isPosting}
              >
                <option value="">Select a usergroup...</option>
                {groups.map((group) => (
                  <option key={group.node_id} value={group.node_id}>
                    {group.ify_display
                      ? `${group.ify_display} (${group.title})`
                      : group.title}
                  </option>
                ))}
              </select>

              <button
                onClick={handlePostToGroup}
                disabled={!selectedGroup || isPosting}
                className="modal-compact__btn"
              >
                {isPosting ? 'Posting...' : 'Post to Page'}
              </button>

              <p className="modal-compact__help mt-2">
                <a href="/node/superdoc/Edit%20weblog%20menu" className="modal-compact__link">
                  Edit this menu...
                </a>
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

/**
 * AddToWeblogButton - Button that opens the AddToWeblogModal
 *
 * Only renders for users with can_weblog permission (have weblog groups available)
 */
export const AddToWeblogButton = ({ nodeId, nodeTitle, nodeType, user, style }) => {
  const [isOpen, setIsOpen] = useState(false)

  // Only show for logged-in users
  if (!user || user.is_guest || user.guest) return null

  // Check if user has weblog permission (can_weblog VARS is set)
  // Note: The actual check for available groups happens in the modal
  // Here we just check basic login status

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        title="Add to usergroup page"
        className="icon-btn"
        style={style}
      >
        <FaShareSquare />
      </button>

      <AddToWeblogModal
        nodeId={nodeId}
        nodeTitle={nodeTitle}
        nodeType={nodeType}
        user={user}
        isOpen={isOpen}
        onClose={() => setIsOpen(false)}
      />
    </>
  )
}

export default AddToWeblogModal

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

// Styles matching Kernel Blue theme
const styles = {
  backdrop: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10000
  },
  modal: {
    backgroundColor: '#fff',
    border: '1px solid #38495e',
    maxWidth: '400px',
    width: '90%',
    maxHeight: '80vh',
    overflow: 'auto',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif',
    fontSize: '12px'
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '8px 12px',
    backgroundColor: '#38495e',
    color: '#f9fafa'
  },
  title: {
    margin: 0,
    fontSize: '13px',
    fontWeight: 'bold'
  },
  closeButton: {
    background: 'none',
    border: 'none',
    fontSize: '18px',
    cursor: 'pointer',
    color: '#f9fafa',
    padding: '0 4px',
    lineHeight: 1
  },
  content: {
    padding: '12px'
  },
  status: {
    padding: '6px 10px',
    marginBottom: '12px',
    fontSize: '11px',
    border: '1px solid'
  },
  select: {
    width: '100%',
    padding: '6px',
    marginBottom: '8px',
    border: '1px solid #d3d3d3',
    fontSize: '12px',
    boxSizing: 'border-box',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif'
  },
  actionButton: {
    display: 'block',
    width: '100%',
    padding: '6px 10px',
    border: '1px solid #4060b0',
    backgroundColor: '#4060b0',
    color: '#fff',
    cursor: 'pointer',
    fontSize: '12px',
    textAlign: 'center',
    fontWeight: 'bold'
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
    borderColor: '#ccc',
    cursor: 'not-allowed'
  },
  helpText: {
    fontSize: '11px',
    color: '#507898',
    margin: '4px 0 0 0'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none',
    fontSize: '11px'
  },
  iconButton: {
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    fontSize: '14px',
    color: '#507898',
    padding: '2px 4px',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center'
  }
}

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
    <div style={styles.backdrop} onClick={handleBackdropClick}>
      <div style={styles.modal}>
        <div style={styles.header}>
          <h3 style={styles.title}>Add to Page</h3>
          <button onClick={onClose} style={styles.closeButton}>&times;</button>
        </div>

        <div style={styles.content}>
          {/* Status message */}
          {actionStatus && (
            <div style={{
              ...styles.status,
              backgroundColor: actionStatus.type === 'error' ? '#fee' : '#efe',
              color: actionStatus.type === 'error' ? '#c00' : '#060'
            }}>
              {actionStatus.message}
            </div>
          )}

          {isLoading ? (
            <p style={styles.helpText}>Loading usergroups...</p>
          ) : groups.length === 0 ? (
            <div>
              <p style={styles.helpText}>
                No usergroups available. You need to be a member of a usergroup to post to its weblog.
              </p>
              <p style={{ ...styles.helpText, marginTop: '8px' }}>
                <a href="/node/superdoc/Edit%20weblog%20menu" style={styles.link}>
                  Edit weblog menu...
                </a>
              </p>
            </div>
          ) : (
            <>
              <p style={{ margin: '0 0 12px 0', fontSize: '12px' }}>
                Add <strong>{nodeTitle}</strong> to a usergroup page:
              </p>

              <select
                value={selectedGroup}
                onChange={(e) => setSelectedGroup(e.target.value)}
                style={styles.select}
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
                style={{
                  ...styles.actionButton,
                  ...(!selectedGroup || isPosting ? styles.buttonDisabled : {})
                }}
              >
                {isPosting ? 'Posting...' : 'Post to Page'}
              </button>

              <p style={{ ...styles.helpText, marginTop: '8px' }}>
                <a href="/node/superdoc/Edit%20weblog%20menu" style={styles.link}>
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
        style={{ ...styles.iconButton, ...style }}
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

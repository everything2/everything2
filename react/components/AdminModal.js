import React, { useState } from 'react'
import LinkNode from './LinkNode'

/**
 * AdminModal - Modal dialog for writeup tools
 *
 * Shows different options based on user permissions:
 * - Authors: Edit writeup, Remove writeup (return to draft)
 * - Editors: Edit, Hide/unhide, insure, remove, reparent, change author, nodenotes
 *
 * Usage:
 *   <AdminModal
 *     writeup={writeupData}
 *     user={userData}
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *     onWriteupUpdate={(updatedWriteup) => {}} // Optional callback when writeup state changes
 *     onEdit={() => {}} // Optional callback to trigger edit mode
 *   />
 */
const AdminModal = ({ writeup, user, isOpen, onClose, onWriteupUpdate, onEdit }) => {
  const [removeReason, setRemoveReason] = useState('')
  const [actionStatus, setActionStatus] = useState(null)
  const [isInsured, setIsInsured] = useState(writeup?.insured || false)
  const [isHidden, setIsHidden] = useState(writeup?.notnew || false)

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

  return (
    <div className="admin-modal-backdrop" onClick={handleBackdropClick} style={styles.backdrop}>
      <div className="admin-modal" style={styles.modal}>
        <div className="admin-modal-header" style={styles.header}>
          <h3 style={styles.title}>Writeup Tools</h3>
          <button onClick={handleClose} style={styles.closeButton}>&times;</button>
        </div>

        <div className="admin-modal-content" style={styles.content}>
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

          {/* Writeup info */}
          <div style={styles.info}>
            <strong>{writeup.title}</strong>
            {writeup.author && (
              <span> by <LinkNode type="user" title={writeup.author.title} /></span>
            )}
            <div style={styles.statusBadge}>
              Status: Published
              {isHidden && ' · Hidden'}
              {isInsured && ' · Insured'}
            </div>
          </div>

          {/* Edit section - for authors and editors */}
          {(isAuthor || isEditor) && (
            <div style={styles.section}>
              {onEdit ? (
                <button
                  onClick={() => {
                    handleClose()
                    onEdit()
                  }}
                  style={styles.actionButton}
                >
                  Edit writeup
                </button>
              ) : (
                <a
                  href={`/node/${writeup.node_id}`}
                  style={styles.linkButton}
                  onClick={(e) => {
                    // If we're already on this writeup page, just close modal
                    // The edit icon is visible on the page
                    if (window.location.pathname.includes(`/node/${writeup.node_id}`)) {
                      e.preventDefault()
                      handleClose()
                      // Scroll to top where edit button is
                      window.scrollTo({ top: 0, behavior: 'smooth' })
                    }
                  }}
                >
                  Edit writeup
                </a>
              )}
            </div>
          )}

          {/* Editor actions */}
          {isEditor && (
            <div style={styles.section}>
              <h4 style={styles.sectionTitle}>Editor Actions</h4>

              <button onClick={handleToggleHide} style={styles.actionButton}>
                {isHidden ? 'Unhide' : 'Hide'} writeup
              </button>

              <button onClick={handleInsure} style={styles.actionButton}>
                {isInsured ? 'Uninsure' : 'Insure'} writeup
              </button>

              <a
                href={`/node/oppressor_superdoc/Magical Writeup Reparenter?old_writeup_id=${writeup.node_id}`}
                style={styles.linkButton}
              >
                Reparent writeup...
              </a>

              <a
                href={`/node/oppressor_superdoc/Renunciation Chainsaw?wu_id=${writeup.node_id}`}
                style={styles.linkButton}
              >
                Change author...
              </a>
            </div>
          )}

          {/* Remove section - only show if writeup is not insured */}
          {!isInsured && (isEditor || isAuthor) && (
            <div style={styles.section}>
              <h4 style={styles.sectionTitle}>
                {isAuthor && !isEditor ? 'Remove Writeup' : 'Remove'}
              </h4>

              {isEditor && !isAuthor && (
                <input
                  type="text"
                  placeholder="Reason for removal"
                  value={removeReason}
                  onChange={(e) => setRemoveReason(e.target.value)}
                  style={styles.input}
                />
              )}

              <button
                onClick={handleRemove}
                style={{ ...styles.actionButton, ...styles.dangerButton }}
              >
                {isAuthor ? 'Return to drafts' : 'Remove writeup'}
              </button>

              {isAuthor && (
                <p style={styles.helpText}>
                  This will unpublish your writeup and return it to draft status.
                </p>
              )}
            </div>
          )}

          {/* Admin tools */}
          {isAdmin && (hasVoted || hasCooled) && (
            <div style={styles.section}>
              <h4 style={styles.sectionTitle}>Admin Tools</h4>

              {hasVoted && (
                <button onClick={handleRemoveVote} style={styles.actionButton}>
                  Remove my vote
                </button>
              )}

              {hasCooled && (
                <button onClick={handleRemoveCool} style={styles.actionButton}>
                  Remove my C!
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// Styles matching Kernel Blue theme (1882070.css)
// Colors: primary #38495e, medium #c5cdd7, links #4060b0, border #d3d3d3
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
    zIndex: 1000
  },
  modal: {
    backgroundColor: '#fff',
    border: '1px solid #38495e',
    maxWidth: '350px',
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
    padding: '5px 10px',
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
    padding: '10px'
  },
  status: {
    padding: '5px 8px',
    marginBottom: '10px',
    fontSize: '11px',
    border: '1px solid'
  },
  info: {
    marginBottom: '10px',
    paddingBottom: '10px',
    borderBottom: '1px dotted #333'
  },
  statusBadge: {
    marginTop: '4px',
    fontSize: '11px',
    color: '#507898'
  },
  divider: {
    border: 'none',
    borderTop: '1px solid #d3d3d3',
    margin: '10px 0'
  },
  section: {
    marginBottom: '12px'
  },
  sectionTitle: {
    fontSize: '12px',
    fontWeight: 'bold',
    color: '#111',
    marginBottom: '6px',
    marginTop: 0
  },
  actionButton: {
    display: 'block',
    width: '100%',
    padding: '4px 8px',
    marginBottom: '4px',
    border: '1px solid #d3d3d3',
    backgroundColor: '#f8f9f9',
    cursor: 'pointer',
    fontSize: '12px',
    textAlign: 'left',
    color: '#4060b0',
    textDecoration: 'none'
  },
  linkButton: {
    display: 'block',
    padding: '4px 8px',
    marginBottom: '4px',
    border: '1px solid #d3d3d3',
    backgroundColor: '#f8f9f9',
    textDecoration: 'none',
    color: '#4060b0',
    fontSize: '12px'
  },
  dangerButton: {
    borderColor: '#8b0000',
    color: '#8b0000'
  },
  input: {
    width: '100%',
    padding: '4px',
    marginBottom: '6px',
    border: '1px solid #d3d3d3',
    fontSize: '12px',
    boxSizing: 'border-box',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif'
  },
  inputDisabled: {
    backgroundColor: '#f0f0f0',
    color: '#999',
    cursor: 'not-allowed'
  },
  buttonDisabled: {
    backgroundColor: '#f0f0f0',
    color: '#999',
    borderColor: '#ccc',
    cursor: 'not-allowed',
    opacity: 0.6
  },
  warningBox: {
    padding: '8px',
    marginBottom: '8px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '3px',
    fontSize: '12px',
    color: '#856404',
    display: 'flex',
    alignItems: 'center',
    gap: '6px'
  },
  warningIcon: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#dc3545'
  },
  helpText: {
    fontSize: '11px',
    color: '#507898',
    margin: '4px 0 0 0'
  }
}

export default AdminModal

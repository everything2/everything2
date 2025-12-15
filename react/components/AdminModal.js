import React, { useState } from 'react'
import LinkNode from './LinkNode'

/**
 * AdminModal - Modal dialog for admin/editor tools on writeups
 *
 * Shows different options based on user permissions:
 * - Authors: Remove writeup (return to draft)
 * - Editors: Hide/unhide, insure, remove, reparent, change author, nodenotes
 *
 * Usage:
 *   <AdminModal
 *     writeup={writeupData}
 *     user={userData}
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *   />
 */
const AdminModal = ({ writeup, user, isOpen, onClose }) => {
  const [removeReason, setRemoveReason] = useState('')
  const [actionStatus, setActionStatus] = useState(null)

  if (!isOpen || !writeup) return null

  const isEditor = user?.is_editor
  const isAuthor = user?.node_id === writeup.author?.node_id
  const isHidden = writeup.notnew

  // Close on backdrop click
  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  // Handle hide/unhide writeup
  const handleToggleHide = async () => {
    const op = isHidden ? 'unhidewriteup' : 'hidewriteup'
    try {
      const response = await fetch('/api/admin/writeup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          op,
          writeup_id: writeup.node_id
        })
      })
      const data = await response.json()
      if (data.success) {
        setActionStatus({ type: 'success', message: `Writeup ${isHidden ? 'unhidden' : 'hidden'}` })
        setTimeout(() => window.location.reload(), 1000)
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
      const response = await fetch('/api/admin/writeup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          op: 'remove',
          writeup_id: writeup.node_id,
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

  // Handle insure writeup
  const handleInsure = async () => {
    try {
      const response = await fetch('/api/admin/writeup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          op: 'insure',
          writeup_id: writeup.node_id
        })
      })
      const data = await response.json()
      if (data.success) {
        setActionStatus({ type: 'success', message: 'Writeup insured' })
        setTimeout(() => window.location.reload(), 1000)
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Insure failed' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    }
  }

  return (
    <div className="admin-modal-backdrop" onClick={handleBackdropClick} style={styles.backdrop}>
      <div className="admin-modal" style={styles.modal}>
        <div className="admin-modal-header" style={styles.header}>
          <h3 style={styles.title}>Admin Tools</h3>
          <button onClick={onClose} style={styles.closeButton}>&times;</button>
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
              Status: {isHidden ? 'Hidden' : 'Published'}
              {writeup.insured && ' · Insured'}
            </div>
          </div>

          <hr style={styles.divider} />

          {/* Editor actions */}
          {isEditor && (
            <div style={styles.section}>
              <h4 style={styles.sectionTitle}>Editor Actions</h4>

              <button onClick={handleToggleHide} style={styles.actionButton}>
                {isHidden ? 'Unhide' : 'Hide'} writeup
              </button>

              {!writeup.insured && (
                <button onClick={handleInsure} style={styles.actionButton}>
                  Insure writeup
                </button>
              )}

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

          {/* Remove section - available to authors and editors */}
          {(isEditor || isAuthor) && (
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
  helpText: {
    fontSize: '11px',
    color: '#507898',
    margin: '4px 0 0 0'
  }
}

export default AdminModal

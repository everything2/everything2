import React, { useState, useEffect } from 'react'
import LinkNode from './LinkNode'
import { useWriteuptypes } from '../hooks/usePublishDraft'

/**
 * DraftAdminModal - Modal dialog for draft admin tools
 *
 * Shows different options based on user permissions and draft status:
 * - For removed drafts: Republish option (editors/admins only)
 *
 * Usage:
 *   <DraftAdminModal
 *     draft={draftData}
 *     user={userData}
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *   />
 */

/**
 * Parse a draft title to extract e2node title and writeuptype
 * Writeup titles have format: "e2node title (writeuptype)"
 * Returns { e2nodeTitle, writeuptypeName } or just { e2nodeTitle } if no suffix
 */
const parseDraftTitle = (title) => {
  if (!title) return { e2nodeTitle: '' }

  // Match pattern: "some title (writeuptype)" where writeuptype is at the end
  const match = title.match(/^(.+?)\s+\(([^)]+)\)$/)
  if (match) {
    return {
      e2nodeTitle: match[1],
      writeuptypeName: match[2]
    }
  }

  return { e2nodeTitle: title }
}

const DraftAdminModal = ({ draft, user, isOpen, onClose }) => {
  const [actionStatus, setActionStatus] = useState(null)
  const [loading, setLoading] = useState(false)

  // Parse the draft title to extract e2node and writeuptype
  const parsedTitle = parseDraftTitle(draft?.title)

  // If there's a parent_e2node, use its title, otherwise use parsed title
  const defaultE2nodeTitle = draft?.parent_e2node?.title || parsedTitle.e2nodeTitle || ''

  const [e2nodeTitle, setE2nodeTitle] = useState(defaultE2nodeTitle)

  // Use shared hooks for writeuptypes
  const {
    writeuptypes,
    selectedWriteuptypeId,
    setSelectedWriteuptypeId
  } = useWriteuptypes()

  // When writeuptypes load, pre-select the one from the title (if any)
  useEffect(() => {
    if (parsedTitle.writeuptypeName && writeuptypes.length > 0) {
      const matchingType = writeuptypes.find(
        wt => wt.title.toLowerCase() === parsedTitle.writeuptypeName.toLowerCase()
      )
      if (matchingType) {
        setSelectedWriteuptypeId(matchingType.node_id)
      }
    }
  }, [writeuptypes, parsedTitle.writeuptypeName, setSelectedWriteuptypeId])

  // Reset e2nodeTitle when modal opens with new draft
  useEffect(() => {
    if (isOpen && draft) {
      setE2nodeTitle(draft?.parent_e2node?.title || parsedTitle.e2nodeTitle || '')
      setActionStatus(null)
    }
  }, [isOpen, draft, parsedTitle.e2nodeTitle])

  if (!isOpen || !draft) return null

  const isEditor = !!(user?.editor || user?.is_editor)
  const isAdmin = !!(user?.admin || user?.is_admin)
  const isRemoved = draft.publication_status === 'removed'
  const canRepublish = isRemoved && (isEditor || isAdmin)

  // Close on backdrop click
  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      handleClose()
    }
  }

  // Handle close - clears action status
  const handleClose = () => {
    setActionStatus(null)
    onClose()
  }

  // Handle republish
  const handleRepublish = async () => {
    if (!e2nodeTitle.trim()) {
      setActionStatus({ type: 'error', message: 'Please enter an e2node title' })
      return
    }

    if (!selectedWriteuptypeId) {
      setActionStatus({ type: 'error', message: 'Please select a writeup type' })
      return
    }

    setLoading(true)
    setActionStatus(null)

    try {
      const response = await fetch(`/api/drafts/${draft.node_id}/republish`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          e2node_title: e2nodeTitle.trim(),
          e2node_id: draft?.parent_e2node?.node_id || null,
          wrtype_writeuptype: selectedWriteuptypeId
        })
      })

      const result = await response.json()

      if (result.success) {
        setActionStatus({ type: 'success', message: 'Writeup republished successfully' })
        // Redirect to the e2node page after a brief delay
        setTimeout(() => {
          window.location.href = `/title/${encodeURIComponent(e2nodeTitle.trim())}`
        }, 1000)
      } else {
        setActionStatus({ type: 'error', message: result.error || result.message || 'Failed to republish' })
        setLoading(false)
      }
    } catch (err) {
      setActionStatus({ type: 'error', message: err.message })
      setLoading(false)
    }
  }

  return (
    <div className="admin-modal-backdrop" onClick={handleBackdropClick} style={styles.backdrop}>
      <div className="admin-modal" style={styles.modal}>
        <div className="admin-modal-header" style={styles.header}>
          <h3 style={styles.title}>Draft Tools</h3>
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

          {/* Draft info */}
          <div style={styles.info}>
            <strong>{draft.title}</strong>
            {draft.author && (
              <span> by <LinkNode type="user" title={draft.author.title} /></span>
            )}
            <div style={styles.statusBadge}>
              Status: {draft.publication_status}
            </div>
          </div>

          {/* Republish section - only for removed drafts */}
          {canRepublish && (
            <div style={styles.section}>
              <h4 style={styles.sectionTitle}>Republish Writeup</h4>

              {/* Info message */}
              <div style={styles.infoBox}>
                This will republish the writeup with:
                <ul style={{ margin: '5px 0 0 0', paddingLeft: '20px' }}>
                  <li>Hidden from New Writeups nodelet</li>
                  <li>Reputation and C!s reset to zero</li>
                  <li>Original publication date preserved</li>
                </ul>
              </div>

              {/* E2node title input */}
              <div style={{ marginBottom: '10px' }}>
                <label style={styles.label}>E2node Title</label>
                <input
                  type="text"
                  value={e2nodeTitle}
                  onChange={(e) => {
                    setE2nodeTitle(e.target.value)
                    setActionStatus(null)
                  }}
                  placeholder="Enter the e2node title..."
                  style={styles.input}
                  disabled={loading}
                />
                {draft?.parent_e2node && (
                  <p style={styles.helpText}>
                    Original e2node: {draft.parent_e2node.title}
                  </p>
                )}
              </div>

              {/* Writeup type selector */}
              <div style={{ marginBottom: '10px' }}>
                <label style={styles.label}>Writeup Type</label>
                <select
                  value={selectedWriteuptypeId || ''}
                  onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
                  style={styles.select}
                  disabled={loading}
                >
                  {writeuptypes.length > 0 ? (
                    writeuptypes.map((wt) => (
                      <option key={wt.node_id} value={wt.node_id}>
                        {wt.title}
                      </option>
                    ))
                  ) : (
                    <option value="">Loading...</option>
                  )}
                </select>
              </div>

              <button
                onClick={handleRepublish}
                disabled={loading || !e2nodeTitle.trim()}
                style={{
                  ...styles.actionButton,
                  ...(loading || !e2nodeTitle.trim() ? styles.buttonDisabled : {})
                }}
              >
                {loading ? 'Republishing...' : 'Republish writeup'}
              </button>
            </div>
          )}

          {/* No actions available message */}
          {!canRepublish && (
            <div style={styles.helpText}>
              No admin actions available for this draft.
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// Styles matching AdminModal (Kernel Blue theme)
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
  infoBox: {
    padding: '8px',
    marginBottom: '10px',
    backgroundColor: '#e7f3ff',
    border: '1px solid #b3d9ff',
    borderRadius: '4px',
    color: '#004085',
    fontSize: '11px'
  },
  label: {
    display: 'block',
    marginBottom: '4px',
    fontWeight: '500',
    fontSize: '11px'
  },
  input: {
    width: '100%',
    padding: '6px',
    border: '1px solid #d3d3d3',
    fontSize: '12px',
    boxSizing: 'border-box',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif'
  },
  select: {
    width: '100%',
    padding: '6px',
    border: '1px solid #d3d3d3',
    fontSize: '12px',
    backgroundColor: '#fff',
    cursor: 'pointer',
    boxSizing: 'border-box'
  },
  actionButton: {
    display: 'block',
    width: '100%',
    padding: '6px 8px',
    marginBottom: '4px',
    border: '1px solid #d3d3d3',
    backgroundColor: '#f8f9f9',
    cursor: 'pointer',
    fontSize: '12px',
    textAlign: 'center',
    color: '#4060b0'
  },
  buttonDisabled: {
    backgroundColor: '#f0f0f0',
    color: '#999',
    borderColor: '#ccc',
    cursor: 'not-allowed',
    opacity: 0.6
  },
  helpText: {
    fontSize: '11px',
    color: '#507898',
    margin: '4px 0 0 0'
  }
}

export default DraftAdminModal

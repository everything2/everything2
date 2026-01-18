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
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="modal-compact">
        <div className="modal-compact__header">
          <h3 className="modal-compact__title">Draft Tools</h3>
          <button onClick={handleClose} className="modal-compact__close">&times;</button>
        </div>

        <div className="modal-compact__content">
          {/* Status message */}
          {actionStatus && (
            <div className={`modal-compact__status modal-compact__status--${actionStatus.type}`}>
              {actionStatus.message}
            </div>
          )}

          {/* Draft info */}
          <div className="modal-compact__info">
            <strong>{draft.title}</strong>
            {draft.author && (
              <span> by <LinkNode type="user" title={draft.author.title} /></span>
            )}
            <div className="modal-compact__info-badge">
              Status: {draft.publication_status}
            </div>
          </div>

          {/* Republish section - only for removed drafts */}
          {canRepublish && (
            <div className="modal-compact__section">
              <h4 className="modal-compact__section-title">Republish Writeup</h4>

              {/* Info message */}
              <div className="modal-compact__info-box">
                This will republish the writeup with:
                <ul>
                  <li>Hidden from New Writeups nodelet</li>
                  <li>Reputation and C!s reset to zero</li>
                  <li>Original publication date preserved</li>
                </ul>
              </div>

              {/* E2node title input */}
              <div className="modal-compact__form-group">
                <label className="modal-compact__label">E2node Title</label>
                <input
                  type="text"
                  value={e2nodeTitle}
                  onChange={(e) => {
                    setE2nodeTitle(e.target.value)
                    setActionStatus(null)
                  }}
                  placeholder="Enter the e2node title..."
                  className="modal-compact__input"
                  disabled={loading}
                />
                {draft?.parent_e2node && (
                  <p className="modal-compact__help">
                    Original e2node: {draft.parent_e2node.title}
                  </p>
                )}
              </div>

              {/* Writeup type selector */}
              <div className="modal-compact__form-group">
                <label className="modal-compact__label">Writeup Type</label>
                <select
                  value={selectedWriteuptypeId || ''}
                  onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
                  className="modal-compact__select"
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
                className="modal-compact__action-btn"
              >
                {loading ? 'Republishing...' : 'Republish writeup'}
              </button>
            </div>
          )}

          {/* No actions available message */}
          {!canRepublish && (
            <p className="modal-compact__help">
              No admin actions available for this draft.
            </p>
          )}
        </div>
      </div>
    </div>
  )
}

export default DraftAdminModal

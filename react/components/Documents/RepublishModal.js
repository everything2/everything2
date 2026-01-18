import React, { useState, useEffect } from 'react'
import { useWriteuptypes } from '../../hooks/usePublishDraft'

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

/**
 * RepublishModal - Modal for republishing removed drafts as writeups
 *
 * For editors/admins to restore removed writeups.
 * Features:
 * - Uses existing parent e2node if available, or allows specifying new one
 * - Writeuptype selector dropdown
 * - Always hides from New Writeups (notnew=1)
 * - Uses original createtime as publishtime
 * - Resets reputation and C!s to zero
 * - Creates new e2node if it doesn't exist
 *
 * Props:
 * - draft: The removed draft object to republish ({ node_id, title, parent_e2node, ... })
 * - onSuccess: Callback after successful republication
 * - onClose: Callback to close the modal
 */
const RepublishModal = ({ draft, onSuccess, onClose }) => {
  // Parse the draft title to extract e2node and writeuptype
  const parsedTitle = parseDraftTitle(draft?.title)

  // If there's a parent_e2node, use its title, otherwise use parsed title
  const defaultE2nodeTitle = draft?.parent_e2node?.title || parsedTitle.e2nodeTitle || ''

  const [e2nodeTitle, setE2nodeTitle] = useState(defaultE2nodeTitle)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

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

  // Republish the draft
  const handleRepublish = async () => {
    if (!e2nodeTitle.trim()) {
      setError('Please enter an e2node title')
      return
    }

    if (!selectedWriteuptypeId) {
      setError('Please select a writeup type')
      return
    }

    setLoading(true)
    setError(null)

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
        if (onSuccess) onSuccess(result)
        // Redirect to the e2node page
        window.location.href = `/title/${encodeURIComponent(e2nodeTitle.trim())}`
      } else {
        setError(result.error || result.message || 'Failed to republish')
        setLoading(false)
      }
    } catch (err) {
      setError(err.message)
      setLoading(false)
    }
  }

  // Handle keyboard navigation
  const handleKeyDown = (e) => {
    if (e.key === 'Escape') {
      onClose()
    } else if (e.key === 'Enter') {
      e.preventDefault()
      handleRepublish()
    }
  }

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  return (
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="modal-dialog__header">
          <h2 className="modal-dialog__title">
            Republish Removed Writeup
          </h2>
          <button onClick={onClose} className="modal-dialog__close">
            Close
          </button>
        </div>

        {/* Body */}
        <div className="modal-dialog__body">
          {/* Info message */}
          <div className="modal-compact__info-box">
            This will republish the writeup with:
            <ul>
              <li>Hidden from New Writeups nodelet</li>
              <li>Reputation and C!s reset to zero</li>
              <li>Original publication date preserved</li>
            </ul>
          </div>

          {/* Error message */}
          {error && (
            <div className="modal-compact__status modal-compact__status--error">
              {error}
            </div>
          )}

          {/* E2node title input */}
          <div className="modal-dialog__form-group">
            <label className="modal-dialog__label">
              E2node Title
            </label>
            <input
              type="text"
              value={e2nodeTitle}
              onChange={(e) => {
                setE2nodeTitle(e.target.value)
                setError(null)
              }}
              onKeyDown={handleKeyDown}
              placeholder="Enter the e2node title for this writeup..."
              autoFocus
              className="modal-dialog__input"
            />
            {draft?.parent_e2node && (
              <p className="modal-compact__help">
                Original e2node: {draft.parent_e2node.title}
              </p>
            )}
          </div>

          {/* Writeup type selector */}
          <div className="modal-dialog__form-group">
            <label className="modal-dialog__label">
              Writeup Type
            </label>
            <select
              value={selectedWriteuptypeId || ''}
              onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
              className="modal-dialog__select"
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
        </div>

        {/* Footer */}
        <div className="modal-dialog__footer">
          <button
            onClick={onClose}
            disabled={loading}
            className="modal-dialog__btn modal-dialog__btn--secondary"
          >
            Cancel
          </button>
          <button
            onClick={handleRepublish}
            disabled={loading || !e2nodeTitle.trim()}
            className="modal-dialog__btn modal-dialog__btn--primary"
          >
            {loading ? 'Republishing...' : 'Republish'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default RepublishModal

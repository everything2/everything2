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

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0,0,0,0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000
      }}
      onClick={(e) => {
        // Close on backdrop click
        if (e.target === e.currentTarget) {
          onClose()
        }
      }}
    >
      <div
        style={{
          backgroundColor: '#fff',
          borderRadius: '8px',
          width: '90%',
          maxWidth: '500px',
          boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
          overflow: 'hidden'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div
          style={{
            padding: '15px 20px',
            borderBottom: '1px solid #ddd',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center'
          }}
        >
          <h2 style={{ margin: 0, color: '#38495e', fontSize: '18px' }}>
            Republish Removed Writeup
          </h2>
          <button
            onClick={onClose}
            style={{
              padding: '4px 10px',
              backgroundColor: '#f8f9f9',
              border: '1px solid #ccc',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            Close
          </button>
        </div>

        {/* Body */}
        <div style={{ padding: '20px' }}>
          {/* Info message */}
          <div
            style={{
              padding: '10px',
              marginBottom: '15px',
              backgroundColor: '#e7f3ff',
              border: '1px solid #b3d9ff',
              borderRadius: '4px',
              color: '#004085',
              fontSize: '13px'
            }}
          >
            This will republish the writeup with:
            <ul style={{ margin: '5px 0 0 0', paddingLeft: '20px' }}>
              <li>Hidden from New Writeups nodelet</li>
              <li>Reputation and C!s reset to zero</li>
              <li>Original publication date preserved</li>
            </ul>
          </div>

          {/* Error message */}
          {error && (
            <div
              style={{
                padding: '10px',
                marginBottom: '15px',
                backgroundColor: '#fee',
                border: '1px solid #fcc',
                borderRadius: '4px',
                color: '#c00',
                fontSize: '13px'
              }}
            >
              {error}
            </div>
          )}

          {/* E2node title input */}
          <div style={{ marginBottom: '15px' }}>
            <label
              style={{
                display: 'block',
                marginBottom: '5px',
                fontWeight: '500',
                fontSize: '13px'
              }}
            >
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
              style={{
                width: '100%',
                padding: '10px 12px',
                border: '1px solid #ccc',
                borderRadius: '4px',
                fontSize: '14px',
                boxSizing: 'border-box'
              }}
            />
            {draft?.parent_e2node && (
              <p
                style={{
                  marginTop: '5px',
                  marginBottom: 0,
                  fontSize: '12px',
                  color: '#888'
                }}
              >
                Original e2node: {draft.parent_e2node.title}
              </p>
            )}
          </div>

          {/* Writeup type selector */}
          <div style={{ marginBottom: '20px' }}>
            <label
              style={{
                display: 'block',
                marginBottom: '5px',
                fontWeight: '500',
                fontSize: '13px'
              }}
            >
              Writeup Type
            </label>
            <select
              value={selectedWriteuptypeId || ''}
              onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
              style={{
                width: '100%',
                padding: '10px 12px',
                border: '1px solid #ccc',
                borderRadius: '4px',
                fontSize: '14px',
                backgroundColor: '#fff',
                cursor: 'pointer',
                boxSizing: 'border-box'
              }}
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
        <div
          style={{
            padding: '15px 20px',
            borderTop: '1px solid #ddd',
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '10px'
          }}
        >
          <button
            onClick={onClose}
            disabled={loading}
            style={{
              padding: '8px 16px',
              backgroundColor: '#f8f9f9',
              border: '1px solid #ccc',
              borderRadius: '4px',
              cursor: loading ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              opacity: loading ? 0.5 : 1
            }}
          >
            Cancel
          </button>
          <button
            onClick={handleRepublish}
            disabled={loading || !e2nodeTitle.trim()}
            style={{
              padding: '8px 16px',
              backgroundColor: loading || !e2nodeTitle.trim() ? '#999' : '#28a745',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: loading || !e2nodeTitle.trim() ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            {loading ? 'Republishing...' : 'Republish'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default RepublishModal

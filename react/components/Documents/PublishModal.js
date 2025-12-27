import React, { useState, useEffect, useCallback, useRef } from 'react'
import { useWriteuptypes, useSetParentE2node, usePublishDraft } from '../../hooks/usePublishDraft'

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
 * PublishModal - Modal for publishing drafts as writeups
 *
 * Features:
 * - E2node title input with autocomplete suggestions
 * - Writeuptype selector dropdown
 * - Creates new e2node if it doesn't exist
 * - Calls set_parent_e2node then publish_draft APIs
 * - Redirects to new writeup on success
 * - If draft was previously published (title contains writeuptype suffix),
 *   pre-populates e2node title and pre-selects writeuptype
 *
 * Props:
 * - draft: The draft object to publish ({ node_id, title, ... })
 * - onSuccess: Callback after successful publication
 * - onClose: Callback to close the modal
 */
const PublishModal = ({ draft, onSuccess, onClose }) => {
  // Parse the draft title to extract e2node and writeuptype
  const parsedTitle = parseDraftTitle(draft?.title)

  const [e2nodeTitle, setE2nodeTitle] = useState(parsedTitle.e2nodeTitle || '')
  const [suggestions, setSuggestions] = useState([])
  const [selectedE2node, setSelectedE2node] = useState(null)
  const [hideFromNewWriteups, setHideFromNewWriteups] = useState(false)
  const [showSuggestions, setShowSuggestions] = useState(false)
  const hasSetWriteuptypeFromTitleRef = useRef(false) // Track if we've already set writeuptype from title

  // Use shared hooks
  const {
    writeuptypes,
    selectedWriteuptypeId,
    setSelectedWriteuptypeId
  } = useWriteuptypes()

  // When writeuptypes load, pre-select the one from the title (if any)
  // This overrides the default "thing" selection if we have a writeuptype in the title
  useEffect(() => {
    if (
      parsedTitle.writeuptypeName &&
      writeuptypes.length > 0 &&
      !hasSetWriteuptypeFromTitleRef.current
    ) {
      const matchingType = writeuptypes.find(
        wt => wt.title.toLowerCase() === parsedTitle.writeuptypeName.toLowerCase()
      )
      if (matchingType) {
        hasSetWriteuptypeFromTitleRef.current = true
        setSelectedWriteuptypeId(matchingType.node_id)
      }
    }
  }, [writeuptypes, parsedTitle.writeuptypeName, setSelectedWriteuptypeId])

  const {
    setParentE2node,
    loading: settingParent,
    error: parentError
  } = useSetParentE2node()

  const {
    publishDraft,
    publishing,
    error: publishError,
    setError: setPublishError
  } = usePublishDraft({
    draftId: draft?.node_id,
    onSuccess: (result) => {
      if (onSuccess) onSuccess(result)
      // Redirect to the e2node page
      window.location.href = `/title/${encodeURIComponent(e2nodeTitle.trim())}`
    }
  })

  const loading = settingParent || publishing
  const error = parentError || publishError

  // Debounced autocomplete search
  useEffect(() => {
    if (e2nodeTitle.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      return
    }

    const timer = setTimeout(async () => {
      try {
        const response = await fetch(
          `/api/findings?q=${encodeURIComponent(e2nodeTitle)}&limit=5`
        )
        const result = await response.json()
        if (result.success && result.findings) {
          // Filter to only e2nodes
          const e2nodes = result.findings.filter(
            f => f.type === 'e2node' || !f.type
          )
          setSuggestions(e2nodes)
          setShowSuggestions(e2nodes.length > 0)
        }
      } catch (err) {
        console.error('Search failed:', err)
        setSuggestions([])
      }
    }, 300)

    return () => clearTimeout(timer)
  }, [e2nodeTitle])

  // Handle selecting a suggestion
  const handleSelectSuggestion = useCallback((suggestion) => {
    setE2nodeTitle(suggestion.title)
    setSelectedE2node(suggestion)
    setShowSuggestions(false)
    setSuggestions([])
  }, [])

  // Handle title change - clear selected e2node if title changes
  const handleTitleChange = useCallback((e) => {
    const newTitle = e.target.value
    setE2nodeTitle(newTitle)
    // Clear selected e2node if title doesn't match
    if (selectedE2node && selectedE2node.title !== newTitle) {
      setSelectedE2node(null)
    }
    setPublishError(null)
  }, [selectedE2node, setPublishError])

  // Publish the draft
  const handlePublish = async () => {
    if (!e2nodeTitle.trim()) {
      setPublishError('Please enter an e2node title')
      return
    }

    if (!selectedWriteuptypeId) {
      setPublishError('Please select a writeup type')
      return
    }

    // Step 1: Set parent e2node (creates if needed)
    const parentResult = await setParentE2node(
      draft.node_id,
      e2nodeTitle.trim(),
      selectedE2node?.node_id || null
    )

    if (!parentResult.success) {
      return
    }

    // Step 2: Publish draft
    await publishDraft({
      parentE2nodeId: parentResult.e2node.node_id,
      writeuptypeId: selectedWriteuptypeId,
      hideFromNewWriteups
    })
  }

  // Handle keyboard navigation
  const handleKeyDown = (e) => {
    if (e.key === 'Escape') {
      onClose()
    } else if (e.key === 'Enter' && !showSuggestions) {
      e.preventDefault()
      handlePublish()
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
            Publish Draft
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
          {/* Dynamic title preview that updates with e2node title and writeup type */}
          {(() => {
            const selectedType = writeuptypes.find(wt => wt.node_id === selectedWriteuptypeId)
            const typeName = selectedType?.title || ''
            const displayTitle = e2nodeTitle.trim()
              ? (typeName ? `${e2nodeTitle.trim()} (${typeName})` : e2nodeTitle.trim())
              : draft?.title || 'Untitled'
            return (
              <p style={{ marginTop: 0, marginBottom: '15px', color: '#666' }}>
                Publishing as: <strong>{displayTitle}</strong>
              </p>
            )
          })()}

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
          <div style={{ marginBottom: '15px', position: 'relative' }}>
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
              onChange={handleTitleChange}
              onKeyDown={handleKeyDown}
              onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
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

            {/* Suggestions dropdown */}
            {showSuggestions && suggestions.length > 0 && (
              <div
                style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  right: 0,
                  backgroundColor: '#fff',
                  border: '1px solid #ccc',
                  borderTop: 'none',
                  borderRadius: '0 0 4px 4px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
                  maxHeight: '200px',
                  overflowY: 'auto',
                  zIndex: 10
                }}
              >
                {suggestions.map((s) => (
                  <div
                    key={s.node_id}
                    onClick={() => handleSelectSuggestion(s)}
                    style={{
                      padding: '10px 12px',
                      cursor: 'pointer',
                      borderBottom: '1px solid #eee',
                      fontSize: '13px'
                    }}
                    onMouseEnter={(e) => {
                      e.target.style.backgroundColor = '#f5f5f5'
                    }}
                    onMouseLeave={(e) => {
                      e.target.style.backgroundColor = 'transparent'
                    }}
                  >
                    <div style={{ fontWeight: '500' }}>{s.title}</div>
                    {s.writeup_count !== undefined && (
                      <div style={{ fontSize: '11px', color: '#888' }}>
                        {s.writeup_count} writeup{s.writeup_count !== 1 ? 's' : ''}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}

            <p
              style={{
                marginTop: '5px',
                marginBottom: 0,
                fontSize: '12px',
                color: '#888'
              }}
            >
              {selectedE2node
                ? 'Adding writeup to existing e2node'
                : "If this e2node doesn't exist, it will be created automatically."}
            </p>
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

          {/* Hide from New Writeups checkbox */}
          <div style={{ marginBottom: '20px' }}>
            <label
              style={{
                display: 'flex',
                alignItems: 'center',
                cursor: 'pointer',
                fontSize: '13px'
              }}
            >
              <input
                type="checkbox"
                checked={hideFromNewWriteups}
                onChange={(e) => setHideFromNewWriteups(e.target.checked)}
                style={{ marginRight: '8px' }}
              />
              Don't show in New Writeups nodelet
            </label>
            <p
              style={{
                marginTop: '5px',
                marginBottom: 0,
                marginLeft: '24px',
                fontSize: '12px',
                color: '#888'
              }}
            >
              Check this to publish without appearing in the New Writeups list (for maintenance, logs, etc.)
            </p>
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
            onClick={handlePublish}
            disabled={loading || !e2nodeTitle.trim()}
            style={{
              padding: '8px 16px',
              backgroundColor: loading || !e2nodeTitle.trim() ? '#999' : '#4060b0',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: loading || !e2nodeTitle.trim() ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            {loading ? 'Publishing...' : 'Publish'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default PublishModal

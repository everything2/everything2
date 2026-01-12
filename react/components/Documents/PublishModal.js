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
      className="publish-modal-overlay"
      onClick={(e) => {
        // Close on backdrop click
        if (e.target === e.currentTarget) {
          onClose()
        }
      }}
    >
      <div
        className="publish-modal"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="publish-modal-header">
          <h2 className="publish-modal-title">
            Publish Draft
          </h2>
          <button
            onClick={onClose}
            className="publish-modal-close-btn"
          >
            Close
          </button>
        </div>

        {/* Body */}
        <div className="publish-modal-body">
          {/* Dynamic title preview that updates with e2node title and writeup type */}
          {(() => {
            const selectedType = writeuptypes.find(wt => wt.node_id === selectedWriteuptypeId)
            const typeName = selectedType?.title || ''
            const displayTitle = e2nodeTitle.trim()
              ? (typeName ? `${e2nodeTitle.trim()} (${typeName})` : e2nodeTitle.trim())
              : draft?.title || 'Untitled'
            return (
              <p className="publish-modal-preview">
                Publishing as: <strong>{displayTitle}</strong>
              </p>
            )
          })()}

          {/* Error message */}
          {error && (
            <div className="publish-modal-error">
              {error}
            </div>
          )}

          {/* E2node title input */}
          <div className="publish-modal-field">
            <label className="publish-modal-label">
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
              className="publish-modal-input"
            />

            {/* Suggestions dropdown */}
            {showSuggestions && suggestions.length > 0 && (
              <div className="publish-modal-suggestions">
                {suggestions.map((s) => (
                  <div
                    key={s.node_id}
                    onClick={() => handleSelectSuggestion(s)}
                    className="publish-modal-suggestion"
                  >
                    <div className="publish-modal-suggestion-title">{s.title}</div>
                    {s.writeup_count !== undefined && (
                      <div className="publish-modal-suggestion-meta">
                        {s.writeup_count} writeup{s.writeup_count !== 1 ? 's' : ''}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}

            <p className="publish-modal-hint">
              {selectedE2node
                ? 'Adding writeup to existing e2node'
                : "If this e2node doesn't exist, it will be created automatically."}
            </p>
          </div>

          {/* Writeup type selector */}
          <div className="publish-modal-field publish-modal-field--large">
            <label className="publish-modal-label">
              Writeup Type
            </label>
            <select
              value={selectedWriteuptypeId || ''}
              onChange={(e) => setSelectedWriteuptypeId(Number(e.target.value))}
              className="publish-modal-select"
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
          <div className="publish-modal-field publish-modal-field--large">
            <label className="publish-modal-checkbox-label">
              <input
                type="checkbox"
                checked={hideFromNewWriteups}
                onChange={(e) => setHideFromNewWriteups(e.target.checked)}
                className="publish-modal-checkbox"
              />
              Don't show in New Writeups nodelet
            </label>
            <p className="publish-modal-hint publish-modal-hint--indented">
              Check this to publish without appearing in the New Writeups list (for maintenance, logs, etc.)
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="publish-modal-footer">
          <button
            onClick={onClose}
            disabled={loading}
            className={`publish-modal-cancel-btn${loading ? ' publish-modal-cancel-btn--disabled' : ''}`}
          >
            Cancel
          </button>
          <button
            onClick={handlePublish}
            disabled={loading || !e2nodeTitle.trim()}
            className={`publish-modal-submit-btn${loading || !e2nodeTitle.trim() ? ' publish-modal-submit-btn--disabled' : ''}`}
          >
            {loading ? 'Publishing...' : 'Publish'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default PublishModal

import React, { useState, useEffect, useCallback } from 'react'
import LinkNode from '../LinkNode'

/**
 * MagicalWriteupReparenter - Admin/Editor tool to move writeups between e2nodes.
 * Styles in CSS: .mwr__*
 *
 * The lookup is entirely client-side (#4502): this reads old_e2node_id / old_writeup_id /
 * new_e2node_id (and the legacy `repare` source) off the URL and resolves them via
 * GET /api/writeup_reparent. The Page ships only { type, access_denied } -- no server-side param
 * reading, no page reload. "Look Up Nodes" re-fetches and updates the URL via history.pushState.
 * The reparent itself is POST /api/writeup_reparent/reparent, after which we re-fetch to refresh.
 */
const MagicalWriteupReparenter = ({ data }) => {
  const { access_denied } = data

  // Seed the input fields from the URL so the form reflects the current lookup and a re-lookup
  // preserves the source (which arrives via ?repare=… or ?old_e2node_id=…).
  const initialParams = new URLSearchParams(window.location.search)
  const [oldE2nodeInput, setOldE2nodeInput] = useState(
    initialParams.get('old_e2node_id') || initialParams.get('repare') || ''
  )
  const [oldWriteupInput, setOldWriteupInput] = useState(initialParams.get('old_writeup_id') || '')
  const [newE2nodeInput, setNewE2nodeInput] = useState(initialParams.get('new_e2node_id') || '')

  const [resolved, setResolved] = useState({
    old_e2node: null,
    old_writeup: null,
    new_e2node: null,
    suggested_parent: null,
    errors: [],
    kvl_node_id: null
  })
  const [selectedWriteups, setSelectedWriteups] = useState({})
  const [feedback, setFeedback] = useState([])
  const [isLoading, setIsLoading] = useState(false)
  const [lookupError, setLookupError] = useState(null)

  // Resolve source/destination via the API GET. old_e2node takes precedence over old_writeup.
  const lookup = useCallback(async ({ e2, writeup, dest }) => {
    const params = new URLSearchParams()
    if (e2) params.set('old_e2node_id', e2)
    else if (writeup) params.set('old_writeup_id', writeup)
    if (dest) params.set('new_e2node_id', dest)

    if ([...params.keys()].length === 0) {
      // Nothing to look up yet (fresh page) -- leave the empty resolved state.
      return
    }

    setIsLoading(true)
    setLookupError(null)
    try {
      const res = await fetch(`/api/writeup_reparent?${params.toString()}`, {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin'
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        setResolved(json.data)
      } else {
        setLookupError((json && json.error) || 'Lookup failed')
      }
    } catch (err) {
      setLookupError(`Network error: ${err.message}`)
    } finally {
      setIsLoading(false)
    }
  }, [])

  // On mount, resolve whatever is already in the URL (?repare=…, ?old_e2node_id=…, …).
  useEffect(() => {
    if (access_denied) return
    const p = new URLSearchParams(window.location.search)
    lookup({
      e2: p.get('old_e2node_id') || p.get('repare'),
      writeup: p.get('old_writeup_id'),
      dest: p.get('new_e2node_id')
    })
  }, [access_denied, lookup])

  // Auto-select the orphaned writeup once a suggested parent is found.
  useEffect(() => {
    if (resolved.old_writeup && resolved.suggested_parent) {
      setSelectedWriteups({ [resolved.old_writeup.node_id]: true })
    }
  }, [resolved.old_writeup, resolved.suggested_parent])

  if (access_denied) {
    return (
      <div className="mwr">
        <div className="mwr__error-box">
          Access denied. This tool is only available to editors and admins.
        </div>
      </div>
    )
  }

  const { old_e2node, old_writeup, new_e2node, suggested_parent, errors = [], kvl_node_id } = resolved

  const handleLookup = (e) => {
    e.preventDefault()
    // Update the URL (shareable) without a reload, then re-resolve.
    const params = new URLSearchParams()
    if (oldE2nodeInput) params.set('old_e2node_id', oldE2nodeInput)
    else if (oldWriteupInput) params.set('old_writeup_id', oldWriteupInput)
    if (newE2nodeInput) params.set('new_e2node_id', newE2nodeInput)
    window.history.pushState({}, '', params.toString() ? `?${params.toString()}` : window.location.pathname)
    lookup({ e2: oldE2nodeInput, writeup: oldWriteupInput, dest: newE2nodeInput })
  }

  const handleCheckboxChange = (writeupId) => {
    setSelectedWriteups((prev) => ({ ...prev, [writeupId]: !prev[writeupId] }))
  }

  const handleSelectAll = () => {
    const allWriteups = {}
    if (old_e2node?.writeups) {
      old_e2node.writeups.forEach((wu) => {
        allWriteups[wu.node_id] = true
      })
    }
    setSelectedWriteups(allWriteups)
  }

  const handleSelectNone = () => setSelectedWriteups({})

  const handleReparent = async () => {
    const writeupIds = Object.keys(selectedWriteups).filter((id) => selectedWriteups[id])

    if (writeupIds.length === 0) {
      setFeedback([{ type: 'error', text: 'Please select at least one writeup to move.' }])
      return
    }

    const destE2node = new_e2node || suggested_parent
    if (!destE2node) {
      setFeedback([{ type: 'error', text: 'Please specify a destination e2node.' }])
      return
    }

    setIsLoading(true)
    setFeedback([])

    try {
      const response = await fetch('/api/writeup_reparent/reparent', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          new_e2node_id: destE2node.node_id,
          writeup_ids: writeupIds.map((id) => parseInt(id, 10))
        })
      })

      const result = await response.json()

      if (result.success) {
        const feedbackItems = []
        const successCount = result.results.filter((r) => r.success).length
        const failCount = result.results.filter((r) => !r.success).length

        if (successCount > 0 || failCount > 0) {
          feedbackItems.push({
            type: 'header',
            text:
              successCount > 0 && failCount === 0
                ? `Successfully moved ${successCount} writeup${successCount > 1 ? 's' : ''}`
                : failCount > 0 && successCount === 0
                  ? `Failed to move ${failCount} writeup${failCount > 1 ? 's' : ''}`
                  : `Moved ${successCount}, failed ${failCount}`
          })
        }

        result.results.forEach((r) => {
          feedbackItems.push(
            r.success
              ? { type: 'success', text: `Moved "${r.old_title}" to "${r.new_title}"` }
              : { type: 'error', text: `Failed to move writeup ${r.writeup_id}: ${r.error}` }
          )
        })
        setFeedback(feedbackItems)

        if (result.moved_count > 0) {
          setSelectedWriteups({})
          // Re-resolve so the source/destination writeup lists reflect the move.
          lookup({ e2: oldE2nodeInput, writeup: oldWriteupInput, dest: newE2nodeInput })
        }
      } else {
        setFeedback([{ type: 'error', text: result.error || 'Unknown error occurred' }])
      }
    } catch (err) {
      setFeedback([{ type: 'error', text: `Network error: ${err.message}` }])
    } finally {
      setIsLoading(false)
    }
  }

  const renderWriteupList = (writeups, isSource = true) => {
    if (!writeups || writeups.length === 0) {
      return <p className="mwr__nodeshell">This e2node is a nodeshell (no writeups).</p>
    }

    return (
      <ul className="mwr__writeup-list">
        {writeups.map((wu) => (
          <li key={wu.node_id} className="mwr__writeup-item">
            {isSource && (
              <input
                type="checkbox"
                checked={Boolean(selectedWriteups[wu.node_id])}
                onChange={() => handleCheckboxChange(wu.node_id)}
                className="mwr__checkbox"
              />
            )}
            <LinkNode nodeId={wu.node_id} title={wu.title} />
            {' by '}
            <LinkNode nodeId={wu.author_id} title={wu.author_title} />
            <span className="mwr__writeup-meta"> (id: {wu.node_id}, type: {wu.writeuptype})</span>
          </li>
        ))}
      </ul>
    )
  }

  return (
    <div className="mwr">
      {/* Lookup / resolution errors */}
      {(errors.length > 0 || lookupError) && (
        <div className="mwr__error-box">
          {lookupError && <p>{lookupError}</p>}
          {errors.map((err, idx) => (
            <p key={idx}>{err}</p>
          ))}
        </div>
      )}

      {/* Feedback from reparent operation */}
      {feedback.length > 0 && (
        <div
          className={`mwr__feedback-box ${feedback.some((fb) => fb.type === 'error')
            ? 'mwr__feedback-box--error'
            : 'mwr__feedback-box--success'}`}
        >
          {feedback.map((fb, idx) => (
            <p
              key={idx}
              className={
                fb.type === 'header'
                  ? 'mwr__feedback-header'
                  : fb.type === 'error'
                    ? 'mwr__feedback-error'
                    : 'mwr__feedback-success'
              }
            >
              {fb.type === 'header' ? <strong>{fb.text}</strong> : fb.text}
            </p>
          ))}
        </div>
      )}

      {/* Lookup form */}
      <form onSubmit={handleLookup} className="mwr__form">
        <div className="mwr__form-section">
          <h3 className="mwr__section-header">Source</h3>
          <div className="mwr__form-row">
            <label className="mwr__label">
              E2node ID or title:
              <input
                type="text"
                value={oldE2nodeInput}
                onChange={(e) => setOldE2nodeInput(e.target.value)}
                className="mwr__input"
                placeholder="Enter e2node ID or title"
              />
            </label>
            {old_e2node && (
              <span className="mwr__current-value">
                Current: <LinkNode nodeId={old_e2node.node_id} title={old_e2node.title} />
              </span>
            )}
          </div>
          <div className="mwr__form-row">
            <label className="mwr__label">
              - OR - Writeup ID:
              <input
                type="text"
                value={oldWriteupInput}
                onChange={(e) => setOldWriteupInput(e.target.value)}
                className="mwr__input"
                placeholder="Enter writeup ID"
              />
            </label>
            {old_writeup && !old_e2node && (
              <span className="mwr__orphan-warning">
                Writeup <LinkNode nodeId={old_writeup.node_id} title={old_writeup.title} /> is
                orphaned!
              </span>
            )}
          </div>
        </div>

        <div className="mwr__form-section">
          <h3 className="mwr__section-header">Destination</h3>
          <div className="mwr__form-row">
            <label className="mwr__label">
              E2node ID or title:
              <input
                type="text"
                value={newE2nodeInput}
                onChange={(e) => setNewE2nodeInput(e.target.value)}
                className="mwr__input"
                placeholder="Enter destination e2node ID or title"
              />
            </label>
            {new_e2node && (
              <span className="mwr__current-value">
                Current: <LinkNode nodeId={new_e2node.node_id} title={new_e2node.title} />
              </span>
            )}
            {suggested_parent && !new_e2node && (
              <span className="mwr__suggestion">
                Suggested:{' '}
                <LinkNode nodeId={suggested_parent.node_id} title={suggested_parent.title} />
              </span>
            )}
          </div>
        </div>

        <button type="submit" className="mwr__button" disabled={isLoading}>
          {isLoading ? 'Looking Up…' : 'Look Up Nodes'}
        </button>
      </form>

      {/* Source writeups */}
      {old_e2node && (
        <div className="mwr__section">
          <h3 className="mwr__section-header">
            Writeups in <LinkNode nodeId={old_e2node.node_id} title={old_e2node.title} />
          </h3>
          <div className="mwr__button-row">
            <button type="button" onClick={handleSelectAll} className="mwr__small-button">
              Select All
            </button>
            <button type="button" onClick={handleSelectNone} className="mwr__small-button">
              Select None
            </button>
          </div>
          {renderWriteupList(old_e2node.writeups, true)}
        </div>
      )}

      {/* Orphaned writeup */}
      {old_writeup && !old_e2node && (
        <div className="mwr__section">
          <h3 className="mwr__section-header">Orphaned Writeup</h3>
          <ul className="mwr__writeup-list">
            <li className="mwr__writeup-item">
              <input
                type="checkbox"
                checked={Boolean(selectedWriteups[old_writeup.node_id])}
                onChange={() => handleCheckboxChange(old_writeup.node_id)}
                className="mwr__checkbox"
              />
              <LinkNode nodeId={old_writeup.node_id} title={old_writeup.title} />
              {' by '}
              <LinkNode nodeId={old_writeup.author_id} title={old_writeup.author_title} />
            </li>
          </ul>
        </div>
      )}

      {/* Destination writeups */}
      {(new_e2node || suggested_parent) && (
        <div className="mwr__section">
          <hr className="mwr__hr" />
          <h3 className="mwr__section-header">
            Destination:{' '}
            <LinkNode
              nodeId={(new_e2node || suggested_parent).node_id}
              title={(new_e2node || suggested_parent).title}
            />
          </h3>
          {renderWriteupList((new_e2node || suggested_parent).writeups, false)}
        </div>
      )}

      {/* Reparent button */}
      {(old_e2node || old_writeup) && (new_e2node || suggested_parent) && (
        <div className="mwr__action-section">
          <button
            type="button"
            onClick={handleReparent}
            disabled={isLoading}
            className={isLoading ? 'mwr__button--disabled' : 'mwr__action-button'}
          >
            {isLoading ? 'Moving…' : 'Move Selected Writeups'}
          </button>
        </div>
      )}

      {/* Link to Klaproth Van Lines */}
      <div className="mwr__footer">
        <p>
          Try{' '}
          {kvl_node_id ? (
            <LinkNode nodeId={kvl_node_id} title="Klaproth Van Lines" />
          ) : (
            'Klaproth Van Lines'
          )}{' '}
          for bulk moves. Certain conditions apply.
        </p>
      </div>
    </div>
  )
}

export default MagicalWriteupReparenter

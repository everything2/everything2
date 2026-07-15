import React, { useState, useEffect } from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeList - the numbered "recent writeups" documents (25 / Everything New Nodes /
 * E2N / ENN / EKN). All five Pages were identical except a record count and a label;
 * they're now pure gates shipping only { type }, and this component owns the count +
 * labels (keyed on type) and fetches GET /api/newnodes?records=N (#4537).
 *
 * Features:
 * - Writeups with parent e2node, writeuptype, date, author
 * - Editors see hide/unhide controls per writeup
 * - Dropdown to switch between the sibling list sizes
 */

// The count that used to live in each Page's `records` attribute now lives here,
// keyed on document type. `selector` is the sibling node title the size dropdown
// navigates to. NOTE: EKN historically fetched 1000 while labelling itself 1024 --
// preserved as-is (cosmetic, predates this change).
const NEW_NODES_CONFIG = {
  '25':                 { records: 25,   title: '25 Most Recent Writeups',            selector: '25' },
  everything_new_nodes: { records: 100,  title: 'Everything New Nodes (100)',         selector: 'Everything New Nodes' },
  e2n:                  { records: 200,  title: 'E2N - Everything2 New (200)',         selector: 'E2N' },
  enn:                  { records: 300,  title: 'ENN - Everything New Nodes (300)',    selector: 'ENN' },
  ekn:                  { records: 1000, title: 'EKN - Everything Killer Nodes (1024)', selector: 'EKN' }
}

// The size dropdown options (size label -> sibling node title to navigate to).
const PAGE_SIZE_OPTIONS = [
  ['25', '25'],
  ['100', 'Everything New Nodes'],
  ['200', 'E2N'],
  ['300', 'ENN'],
  ['1024', 'EKN']
]

const NodeList = ({ data, user }) => {
  const config = NEW_NODES_CONFIG[data.type] || NEW_NODES_CONFIG['25']
  // e2.user ships the editor flag as `editor` (PageState.pm) -- the dominant prop
  // across components; the old `isEditor` here never matched, so editors never saw
  // the hide controls (#4537 follow-up).
  const isEditor = user?.editor || false

  const [nodelist, setNodelist] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch(`/api/newnodes?records=${config.records}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setNodelist(j.nodelist || []); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [config.records])

  // Hide/unhide a writeup via the hidewriteups API (was the dead ?op=hidewriteup
  // dispatch, removed with the opcode system in #4335). Toggles the row in place.
  const handleToggleHide = async (writeup) => {
    const action = writeup.notnew ? 'show' : 'hide'
    try {
      const res = await fetch(`/api/hidewriteups/${writeup.node_id}/action/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin'
      })
      const j = await res.json()
      if (j.node_id) {
        setNodelist((prev) => prev.map((w) => (w.node_id === writeup.node_id ? { ...w, notnew: j.notnew } : w)))
      }
    } catch (e) { /* leave the row unchanged on failure */ }
  }

  return (
    <div className="nodelist">
      <h2>{config.title}</h2>

      {/* Page size selector -- navigates on change; no submit button needed */}
      <div className="nodelist__selector-wrapper">
        <div className="nodelist__selector-form">
          <label htmlFor="nodelist-selector">Show: </label>
          <select
            name="node"
            id="nodelist-selector"
            onChange={(e) => {
              if (e.target.value) {
                window.location.href = `/title/${encodeURIComponent(e.target.value)}`
              }
            }}
            value={config.selector}
          >
            {PAGE_SIZE_OPTIONS.map(([label, page]) => (
              <option key={label} value={page}>{label}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Link to Writeups by Type page */}
      <p>
        (see also <LinkNode title="Writeups by Type" type="superdoc" />)
      </p>

      {/* Writeup list table */}
      {loading ? (
        <p>Loading...</p>
      ) : nodelist && nodelist.length > 0 ? (
        <table className="nodelist__table">
          <tbody>
            {nodelist.map((writeup, index) => {
              const isOddRow = index % 2 === 0

              return (
                <tr key={writeup.node_id} className={`nodelist__row contentinfo ${isOddRow ? 'nodelist__row--odd' : ''}`}>
                  {/* Hide/unhide control (editors only) */}
                  {isEditor && (
                    <td className="nodelist__cell--nowrap">
                      <a
                        href="#"
                        className="nodelist__hide-link"
                        onClick={(e) => { e.preventDefault(); handleToggleHide(writeup) }}
                      >
                        {writeup.notnew ? '(un-h!)' : '(h?)'}
                      </a>
                    </td>
                  )}

                  {/* Parent e2node + writeuptype */}
                  <td className="nodelist__cell">
                    <a href={`/e2node/${encodeURIComponent(writeup.parent_title)}`} className="title">
                      {writeup.parent_title}
                    </a>
                    {' '}
                    <a href={`/title/${encodeURIComponent(writeup.parent_title)}#${encodeURIComponent(writeup.author_name)}`}>
                      ({writeup.writeuptype})
                    </a>
                  </td>

                  {/* Publish date */}
                  <td className="nodelist__cell--nowrap">
                    <span className="date nodelist__date">
                      {writeup.publishtime}
                    </span>
                  </td>

                  {/* Author */}
                  <td className="nodelist__cell--nowrap">
                    <LinkNode
                      node_id={writeup.author_id}
                      title={writeup.author_name}
                      type="user"
                      className="author"
                    />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      ) : (
        <p>No writeups found.</p>
      )}
    </div>
  )
}

export default NodeList

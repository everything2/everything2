import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Recent Node Notes - Shows recent editor/admin notes on writeups
 *
 * Staff only - supports filtering and pagination
 */
const RecentNodeNotes = ({ data }) => {
  const { notes = [], total, page, perpage, onlymynotes, hidesystemnotes, node } = data

  const totalPages = Math.ceil(total / perpage)
  const hasPrev = page > 0
  const hasNext = page < totalPages - 1

  const buildUrl = (params) => {
    const query = new URLSearchParams()
    if (params.onlymynotes) query.set('onlymynotes', '1')
    if (params.hidesystemnotes) query.set('hidesystemnotes', '1')
    if (params.page !== undefined) query.set('page', params.page)

    // If we have a specific node, link to that node's page
    if (node) {
      return `/node/${node.node_id}?${query.toString()}`
    }

    // Otherwise, stay on current page (Recent Node Notes page)
    // Use window.location.pathname to keep the current path
    const currentPath = window.location.pathname
    return `${currentPath}?${query.toString()}`
  }

  return (
    <div className="document">
      <h2>Recent Node Notes</h2>

      <div style={{ marginBottom: '1em', padding: '1em', backgroundColor: '#f8f9f9', borderRadius: '4px' }}>
        <p style={{ margin: '0 0 0.5em 0' }}><strong>Filter options:</strong></p>
        <label style={{ display: 'block', marginBottom: '0.5em' }}>
          <input
            type="checkbox"
            checked={onlymynotes}
            onChange={(e) => {
              window.location.href = buildUrl({
                onlymynotes: e.target.checked,
                hidesystemnotes,
                page: 0
              })
            }}
          />{' '}
          Show only my notes
        </label>
        <label style={{ display: 'block' }}>
          <input
            type="checkbox"
            checked={hidesystemnotes}
            onChange={(e) => {
              window.location.href = buildUrl({
                onlymynotes,
                hidesystemnotes: e.target.checked,
                page: 0
              })
            }}
          />{' '}
          Hide system notes
        </label>
      </div>

      <p>
        Showing {page * perpage + 1}-{Math.min((page + 1) * perpage, total)} of {total} notes
      </p>

      {notes.length === 0 ? (
        <p><em>No notes found</em></p>
      ) : (
        <ol start={page * perpage + 1}>
          {notes.map((note, idx) => (
            <li key={idx} style={{ marginBottom: '1em' }}>
              {note.node && <LinkNode nodeId={note.node.node_id} title={note.node.title} />}
              <br />
              <small style={{ color: '#666' }}>
                {note.timestamp && new Date(note.timestamp * 1000).toLocaleString()}
              </small>
              <br />
              <span style={{
                display: 'block',
                marginTop: '0.5em',
                padding: '0.5em',
                backgroundColor: '#fffbdd',
                border: '1px solid #e8e3a8',
                borderRadius: '3px'
              }}>
                {note.note}
              </span>
            </li>
          ))}
        </ol>
      )}

      <div style={{ marginTop: '2em', textAlign: 'center' }}>
        {hasPrev && (
          <a href={buildUrl({ onlymynotes, hidesystemnotes, page: page - 1 })} style={{ marginRight: '2em' }}>
            ← Previous
          </a>
        )}
        <span>Page {page + 1} of {totalPages}</span>
        {hasNext && (
          <a href={buildUrl({ onlymynotes, hidesystemnotes, page: page + 1 })} style={{ marginLeft: '2em' }}>
            Next →
          </a>
        )}
      </div>
    </div>
  )
}

export default RecentNodeNotes

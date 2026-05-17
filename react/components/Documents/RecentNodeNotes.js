import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Recent Node Notes - Shows recent editor/admin notes on writeups
 * Styles in CSS: .recent-node-notes__*
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

      <div className="recent-node-notes__filter-box">
        <p className="recent-node-notes__filter-title"><strong>Filter options:</strong></p>
        <label className="recent-node-notes__filter-label">
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
        <label className="recent-node-notes__filter-label">
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
            <li key={idx} className="recent-node-notes__list-item">
              {note.node && <LinkNode nodeId={note.node.node_id} title={note.node.title} />}
              <br />
              <small className="recent-node-notes__timestamp">
                {note.timestamp && new Date(note.timestamp * 1000).toLocaleString()}
              </small>
              <br />
              <span className="recent-node-notes__note-text">
                {note.note}
              </span>
            </li>
          ))}
        </ol>
      )}

      <div className="recent-node-notes__pagination">
        {hasPrev && (
          <a href={buildUrl({ onlymynotes, hidesystemnotes, page: page - 1 })} className="recent-node-notes__prev-link">
            ← Previous
          </a>
        )}
        <span>Page {page + 1} of {totalPages}</span>
        {hasNext && (
          <a href={buildUrl({ onlymynotes, hidesystemnotes, page: page + 1 })} className="recent-node-notes__next-link">
            Next →
          </a>
        )}
      </div>
    </div>
  )
}

export default RecentNodeNotes

import React, { useState } from 'react'

/**
 * NodeNotesByEditor - View node notes by a specific editor
 *
 * Admin tool to view all node notes created by a specific user,
 * with pagination support.
 * Styles are in CSS classes (node-notes-editor__*)
 */
const NodeNotesByEditor = ({ data }) => {
  const {
    error,
    node_id,
    target_username = '',
    target_user_id,
    notes = [],
    total_count = 0,
    start = 0,
    limit = 50
  } = data

  const [username, setUsername] = useState(target_username)

  if (error && !target_username) {
    return <div className="error-message">{error}</div>
  }

  const end = Math.min(start + limit, total_count)
  const hasPrev = start > 0
  const hasNext = start + limit < total_count
  const prevStart = Math.max(0, start - limit)
  const nextStart = start + limit

  const buildUrl = (newStart) => {
    return `/?node_id=${node_id}&targetUser=${encodeURIComponent(target_username)}&gotime=Go!&start=${newStart}&limit=${limit}`
  }

  const renderPagination = () => {
    if (!hasPrev && !hasNext) return null
    return (
      <div className="node-notes-editor__pagination">
        {hasPrev && (
          <a href={buildUrl(prevStart)} className="node-notes-editor__pagination-link">&larr; Previous</a>
        )}
        <span className="node-notes-editor__pagination-info">
          Viewing {start + 1} &ndash; {end} of {total_count}
        </span>
        {hasNext && (
          <a href={buildUrl(nextStart)} className="node-notes-editor__pagination-link">Next &rarr;</a>
        )}
      </div>
    )
  }

  return (
    <div className="node-notes-editor">
      {/* Search form */}
      <div className="node-notes-editor__search-box">
        <form method="GET" className="node-notes-editor__form">
          <input type="hidden" name="node_id" value={node_id} />
          <label className="node-notes-editor__label">
            Editor Username:
            <input
              type="text"
              name="targetUser"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="node-notes-editor__input"
              placeholder="Enter editor username"
            />
          </label>
          <button
            type="submit"
            name="gotime"
            value="Go!"
            className="node-notes-editor__btn"
          >
            Search
          </button>
        </form>
      </div>

      {error && (
        <div className="node-notes-editor__error-box"><em>{error}</em></div>
      )}

      {/* Results */}
      {target_user_id && notes.length > 0 && (
        <>
          {renderPagination()}

          <table className="node-notes-editor__table">
            <thead>
              <tr>
                <th className="node-notes-editor__th">Node</th>
                <th className="node-notes-editor__th">Note</th>
                <th className="node-notes-editor__th">Time</th>
              </tr>
            </thead>
            <tbody>
              {notes.map((note, idx) => (
                <tr key={`${note.node_id}-${idx}`} className={idx % 2 === 1 ? 'node-notes-editor__row--even' : ''}>
                  <td className="node-notes-editor__td node-notes-editor__td--node">
                    <a href={`/?node_id=${note.node_id}`}>{note.node_title}</a>
                    {note.author_id && (
                      <cite> by <a href={`/?node_id=${note.author_id}`}>{note.author_title}</a></cite>
                    )}
                  </td>
                  <td className="node-notes-editor__td" dangerouslySetInnerHTML={{ __html: note.note }} />
                  <td className="node-notes-editor__td node-notes-editor__td--time">{note.timestamp}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {renderPagination()}
        </>
      )}

      {target_user_id && notes.length === 0 && (
        <p><em>No node notes found for this user.</em></p>
      )}
    </div>
  )
}

export default NodeNotesByEditor

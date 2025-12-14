import React, { useState } from 'react'

/**
 * NodeNotesByEditor - View node notes by a specific editor
 *
 * Admin tool to view all node notes created by a specific user,
 * with pagination support.
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

  return (
    <div className="node-notes-by-editor">
      {/* Search form */}
      <form method="GET">
        <input type="hidden" name="node_id" value={node_id} />

        <p>
          <label>
            Editor Username:{' '}
            <input
              type="text"
              name="targetUser"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              size={30}
            />
          </label>
          {' '}
          <button
            type="submit"
            name="gotime"
            value="Go!"
            style={{
              padding: '6px 15px',
              backgroundColor: '#38495e',
              color: '#fff',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
          >
            Go!
          </button>
        </p>
      </form>

      {error && (
        <p style={{ color: '#c00000' }}><em>{error}</em></p>
      )}

      {/* Results */}
      {target_user_id && notes.length > 0 && (
        <>
          {/* Pagination header */}
          {(hasPrev || hasNext) && (
            <table style={{ width: '95%', marginBottom: '1em' }}>
              <tbody>
                <tr>
                  {hasPrev && (
                    <th style={{ whiteSpace: 'nowrap' }}>
                      ( <a href={buildUrl(prevStart)}>prev</a> )
                    </th>
                  )}
                  <th style={{ width: '100%', textAlign: 'center' }}>
                    Viewing {start} through {end} of {total_count}
                  </th>
                  {hasNext && (
                    <th style={{ whiteSpace: 'nowrap' }}>
                      ( <a href={buildUrl(nextStart)}>next</a> )
                    </th>
                  )}
                </tr>
              </tbody>
            </table>
          )}

          {/* Notes table */}
          <table style={{ width: '95%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Node</th>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Note</th>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Time</th>
              </tr>
            </thead>
            <tbody>
              {notes.map((note, idx) => (
                <tr key={`${note.node_id}-${idx}`}>
                  <td style={{ padding: '4px', verticalAlign: 'top' }}>
                    <a href={`/?node_id=${note.node_id}`}>{note.node_title}</a>
                    {note.author_id && (
                      <cite> by <a href={`/?node_id=${note.author_id}`}>{note.author_title}</a></cite>
                    )}
                  </td>
                  <td style={{ padding: '4px' }} dangerouslySetInnerHTML={{ __html: note.note }} />
                  <td style={{ padding: '4px', whiteSpace: 'nowrap' }}>{note.timestamp}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Pagination footer */}
          {(hasPrev || hasNext) && (
            <table style={{ width: '95%', marginTop: '1em' }}>
              <tbody>
                <tr>
                  {hasPrev && (
                    <th style={{ whiteSpace: 'nowrap' }}>
                      ( <a href={buildUrl(prevStart)}>prev</a> )
                    </th>
                  )}
                  <th style={{ width: '100%', textAlign: 'center' }}>
                    Viewing {start} through {end} of {total_count}
                  </th>
                  {hasNext && (
                    <th style={{ whiteSpace: 'nowrap' }}>
                      ( <a href={buildUrl(nextStart)}>next</a> )
                    </th>
                  )}
                </tr>
              </tbody>
            </table>
          )}
        </>
      )}

      {target_user_id && notes.length === 0 && (
        <p><em>No node notes found for this user.</em></p>
      )}
    </div>
  )
}

export default NodeNotesByEditor

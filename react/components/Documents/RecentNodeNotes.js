import React from 'react'
import LinkNode from '../LinkNode'
import { formatDateTime } from '../../utils/dateFormat'

/**
 * Recent Node Notes - Shows recent editor/admin notes on writeups
 * Styles in CSS: .recent-node-notes__*
 *
 * Staff only - supports filtering and pagination
 */
const RecentNodeNotes = ({ data }) => {
  const { notes = [], total, page, perpage, onlymynotes, hidesystemnotes } = data

  const totalPages = Math.ceil(total / perpage)
  const hasPrev = page > 0
  const hasNext = page < totalPages - 1

  const buildUrl = (params) => {
    // Reload the CURRENT page with updated filter/pagination params. Preserve the
    // full current URL -- path AND existing query string -- because a superdoc's
    // node identity lives in the query (e.g. /index.pl?node=...&type=superdoc);
    // rebuilding from pathname alone dropped it and bounced to the homepage (#4389).
    const url = new URL(window.location.href)
    if (params.onlymynotes) url.searchParams.set('onlymynotes', '1')
    else url.searchParams.delete('onlymynotes')
    // Always emit hidesystemnotes (0 or 1): the page defaults it ON when the
    // param is absent, so an unchecked toggle must say so explicitly.
    url.searchParams.set('hidesystemnotes', params.hidesystemnotes ? '1' : '0')
    if (params.page !== undefined) url.searchParams.set('page', String(params.page))
    return url.pathname + url.search
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
          Hide automated notes
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
              {note.kind === 'auto' && <span className="recent-node-notes__badge">auto</span>}
              <br />
              <small className="recent-node-notes__timestamp">
                {note.timestamp && formatDateTime(note.timestamp)}
              </small>
              <br />
              <span className="recent-node-notes__note-text">
                {note.noter && (
                  <span className="recent-node-notes__noter">
                    <LinkNode type="user" title={note.noter} />:{' '}
                  </span>
                )}
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

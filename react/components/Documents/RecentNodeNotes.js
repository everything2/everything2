import React, { useState, useEffect, useCallback } from 'react'
import LinkNode from '../LinkNode'
import { formatDateTime } from '../../utils/dateFormat'

/**
 * Recent Node Notes - Shows recent editor/admin notes on writeups
 * Styles in CSS: .recent-node-notes__*
 *
 * Fully client-resolved (#4528): the Page is a pure gate. This fetches GET /api/recent_node_notes
 * (editor-gated) on mount, and toggles/pagination refetch IN PLACE -- no full page reload. The URL
 * is kept in sync via history.pushState so links stay shareable and back/forward work (popstate
 * refetches). During a refetch the current list stays on screen (no blank flash).
 */
const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  const hs = qs.get('hidesystemnotes')
  return {
    onlymynotes: qs.get('onlymynotes') ? 1 : 0,
    hidesystemnotes: hs === null ? 1 : (hs === '0' ? 0 : 1),
    page: parseInt(qs.get('page') || '0', 10) || 0
  }
}

const RecentNodeNotes = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  // Fetch for an explicit param set and update state. When `push` is set, also
  // reflect the params in the URL (pushState) so the view is shareable/bookmarkable
  // and the back button works -- without reloading the page. Preserve the full
  // current URL (path AND existing query) so a superdoc's node identity in the
  // query string survives (#4389).
  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams({
      hidesystemnotes: params.hidesystemnotes ? '1' : '0',
      page: String(params.page || 0)
    })
    if (params.onlymynotes) api.set('onlymynotes', '1')

    if (push) {
      const url = new URL(window.location.href)
      url.searchParams.set('hidesystemnotes', params.hidesystemnotes ? '1' : '0')
      if (params.onlymynotes) url.searchParams.set('onlymynotes', '1')
      else url.searchParams.delete('onlymynotes')
      url.searchParams.set('page', String(params.page || 0))
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/recent_node_notes?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => load(paramsFromUrl())
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  // First paint only: keep the list on screen during later refetches to avoid a flash.
  if (loading && !data) {
    return <div className="document"><h2>Recent Node Notes</h2><p>Loading...</p></div>
  }
  if (data && data.success === 0) {
    return <div className="error-message">This page is available to staff (editors and administrators).</div>
  }

  const { notes = [], total = 0, page = 0, perpage = 50, onlymynotes = 0, hidesystemnotes = 1 } = data || {}

  const totalPages = Math.ceil(total / perpage)
  const hasPrev = page > 0
  const hasNext = page < totalPages - 1

  // Real href (path + query) for shareability / open-in-new-tab; click is intercepted for SPA nav.
  const hrefFor = (params) => {
    const url = new URL(window.location.href)
    if (params.onlymynotes) url.searchParams.set('onlymynotes', '1')
    else url.searchParams.delete('onlymynotes')
    url.searchParams.set('hidesystemnotes', params.hidesystemnotes ? '1' : '0')
    url.searchParams.set('page', String(params.page || 0))
    return url.pathname + url.search
  }
  const goTo = (params) => (e) => { e.preventDefault(); load(params, { push: true }) }

  return (
    <div className="document">
      <h2>Recent Node Notes</h2>

      <div className="recent-node-notes__filter-box">
        <p className="recent-node-notes__filter-title"><strong>Filter options:</strong></p>
        <label className="recent-node-notes__filter-label">
          <input
            type="checkbox"
            checked={onlymynotes}
            onChange={(e) => load({ onlymynotes: e.target.checked ? 1 : 0, hidesystemnotes, page: 0 }, { push: true })}
          />{' '}
          Show only my notes
        </label>
        <label className="recent-node-notes__filter-label">
          <input
            type="checkbox"
            checked={hidesystemnotes}
            onChange={(e) => load({ onlymynotes, hidesystemnotes: e.target.checked ? 1 : 0, page: 0 }, { push: true })}
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
          <a href={hrefFor({ onlymynotes, hidesystemnotes, page: page - 1 })}
             onClick={goTo({ onlymynotes, hidesystemnotes, page: page - 1 })}
             className="recent-node-notes__prev-link">
            ← Previous
          </a>
        )}
        <span>Page {page + 1} of {totalPages}</span>
        {hasNext && (
          <a href={hrefFor({ onlymynotes, hidesystemnotes, page: page + 1 })}
             onClick={goTo({ onlymynotes, hidesystemnotes, page: page + 1 })}
             className="recent-node-notes__next-link">
            Next →
          </a>
        )}
      </div>
    </div>
  )
}

export default RecentNodeNotes

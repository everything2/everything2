import React, { useState, useEffect, useCallback } from 'react'

const ERROR_COPY = {
  admin: 'This page is restricted to administrators.',
  user_not_found: (u) => `Could not find user '${u}'`
}

/**
 * NodeNotesByEditor - View node notes by a specific editor (admin).
 *
 * Fully client-resolved (#4528): the Page is a pure gate. This fetches GET /api/node_notes_by_editor
 * (admin-gated) on mount, and the search form + pagination refetch IN PLACE -- no full page reload.
 * The URL is kept in sync via history.pushState so views are shareable and back/forward work
 * (popstate refetches). During a refetch the current results stay on screen (no blank flash).
 */
const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return {
    targetUser: qs.get('targetUser') || '',
    gotime: qs.get('gotime') || '',
    start: parseInt(qs.get('start') || '0', 10) || 0,
    limit: parseInt(qs.get('limit') || '50', 10) || 50
  }
}

const NodeNotesByEditor = () => {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [username, setUsername] = useState(() => paramsFromUrl().targetUser)

  // Fetch for a param set and update state. When `push` is set, reflect the params
  // in the URL (pushState) so the view is shareable and back/forward work -- without
  // reloading. The node identity lives in the query (?node_id=...), preserved here.
  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams({ start: String(params.start || 0), limit: String(params.limit || 50) })
    if (params.targetUser) api.set('targetUser', params.targetUser)
    if (params.gotime) api.set('gotime', params.gotime)

    if (push) {
      const url = new URL(window.location.href)
      url.searchParams.set('node_id', String(nodeId))
      if (params.targetUser) url.searchParams.set('targetUser', params.targetUser)
      else url.searchParams.delete('targetUser')
      if (params.gotime) url.searchParams.set('gotime', params.gotime)
      else url.searchParams.delete('gotime')
      url.searchParams.set('start', String(params.start || 0))
      url.searchParams.set('limit', String(params.limit || 50))
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/node_notes_by_editor?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [nodeId])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => {
      const p = paramsFromUrl()
      setUsername(p.targetUser)
      load(p)
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  // First paint only: keep results on screen during later refetches to avoid a flash.
  if (loading && !data) {
    return <div className="node-notes-editor"><p>Loading...</p></div>
  }

  // The admin gate is a hard error (no search form makes sense).
  if (data && data.state === 'admin') {
    return <div className="error-message">{ERROR_COPY.admin}</div>
  }

  const {
    state, target_username = '', target_user_id, notes = [], total_count = 0, start = 0, limit = 50
  } = data || {}
  const errorText = state === 'user_not_found' ? ERROR_COPY.user_not_found(target_username) : null

  const end = Math.min(start + limit, total_count)
  const hasPrev = start > 0
  const hasNext = start + limit < total_count
  const prevStart = Math.max(0, start - limit)
  const nextStart = start + limit

  const onSearch = (e) => {
    e.preventDefault()
    load({ targetUser: username, gotime: 'Go!', start: 0, limit }, { push: true })
  }

  // Real href for shareability / open-in-new-tab; click intercepted for SPA nav.
  const hrefFor = (newStart) =>
    `/?node_id=${nodeId}&targetUser=${encodeURIComponent(target_username)}&gotime=Go!&start=${newStart}&limit=${limit}`
  const goTo = (newStart) => (e) => {
    e.preventDefault()
    load({ targetUser: target_username, gotime: 'Go!', start: newStart, limit }, { push: true })
  }

  const renderPagination = () => {
    if (!hasPrev && !hasNext) return null
    return (
      <div className="node-notes-editor__pagination">
        {hasPrev && (
          <a href={hrefFor(prevStart)} onClick={goTo(prevStart)} className="node-notes-editor__pagination-link">&larr; Previous</a>
        )}
        <span className="node-notes-editor__pagination-info">
          Viewing {start + 1} &ndash; {end} of {total_count}
        </span>
        {hasNext && (
          <a href={hrefFor(nextStart)} onClick={goTo(nextStart)} className="node-notes-editor__pagination-link">Next &rarr;</a>
        )}
      </div>
    )
  }

  return (
    <div className="node-notes-editor">
      {/* Search form -- submits in place (no reload) */}
      <div className="node-notes-editor__search-box">
        <form className="node-notes-editor__form" onSubmit={onSearch}>
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
          <button type="submit" className="node-notes-editor__btn">
            Search
          </button>
        </form>
      </div>

      {errorText && (
        <div className="node-notes-editor__error-box"><em>{errorText}</em></div>
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

import React, { useState, useEffect, useCallback } from 'react'
import LinkNode from '../LinkNode'

/**
 * WhoKilledWhat - Admin tool to view a user's writeup kill history.
 *
 * Fully client-resolved (#4530): the Page is a pure gate. This fetches GET /api/who_killed_what
 * (admin-gated) on mount, reading heavenuser/offset/limit off the URL. The search form refetches
 * IN PLACE -- no full page reload -- syncing the URL via history.pushState (popstate refetches).
 * The offset/limit dropdown options are static display config owned here, not shipped by the API.
 */
const ERROR_COPY = {
  admin: 'Access denied. This tool is restricted to administrators.',
  user_not_found: (u) => `User not found: ${u}`
}
const OFFSET_OPTIONS = Array.from({ length: 26 }, (_, i) => i * 200)   // 0, 200, ... 5000
const LIMIT_OPTIONS = Array.from({ length: 10 }, (_, i) => (i + 1) * 50) // 50, 100, ... 500

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return {
    heavenuser: qs.get('heavenuser') || '',
    offset: parseInt(qs.get('offset') || '0', 10) || 0,
    limit: parseInt(qs.get('limit') || '100', 10) || 100
  }
}

const WhoKilledWhat = () => {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const init = paramsFromUrl()
  const [form, setForm] = useState({ heavenuser: init.heavenuser, offset: init.offset, limit: init.limit })

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams({ offset: String(params.offset || 0), limit: String(params.limit || 100) })
    if (params.heavenuser) api.set('heavenuser', params.heavenuser)

    if (push) {
      const url = new URL(window.location.href)
      url.searchParams.set('node_id', String(nodeId))
      if (params.heavenuser) url.searchParams.set('heavenuser', params.heavenuser)
      else url.searchParams.delete('heavenuser')
      url.searchParams.set('offset', String(params.offset || 0))
      url.searchParams.set('limit', String(params.limit || 100))
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/who_killed_what?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [nodeId])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => {
      const p = paramsFromUrl()
      setForm({ heavenuser: p.heavenuser, offset: p.offset, limit: p.limit })
      load(p)
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  if (loading && !data) {
    return <div className="who-killed-what"><p>Loading...</p></div>
  }
  if (data && data.state === 'admin') {
    return <div className="error-message">{ERROR_COPY.admin}</div>
  }

  const {
    state, target_user, total_kills = 0, kills = [], node_heaven_id, heavenuser = ''
  } = data || {}
  const errorText = state === 'user_not_found' ? ERROR_COPY.user_not_found(heavenuser) : null

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value })
  const onSubmit = (e) => {
    e.preventDefault()
    load({ heavenuser: form.heavenuser, offset: parseInt(form.offset, 10) || 0, limit: parseInt(form.limit, 10) || 100 }, { push: true })
  }

  return (
    <div className="who-killed-what">
      {/* Search form -- submits in place */}
      <form className="who-killed__form" onSubmit={onSubmit}>
        <span>And what has </span>
        <input type="text" name="heavenuser" value={form.heavenuser} onChange={handleChange} placeholder="username" size={20} />
        <span> been up to?</span>
        <br />
        <span>offset: </span>
        <select name="offset" value={form.offset} onChange={handleChange}>
          {OFFSET_OPTIONS.map((opt) => <option key={opt} value={opt}>{opt}</option>)}
        </select>
        <span> limit: </span>
        <select name="limit" value={form.limit} onChange={handleChange}>
          {LIMIT_OPTIONS.map((opt) => <option key={opt} value={opt}>{opt}</option>)}
        </select>
        <span> </span>
        <button type="submit" className="who-killed__btn">Search</button>
      </form>

      {errorText && <div className="error-message">{errorText}</div>}

      {/* Results */}
      {!errorText && (
        <table className="who-killed__table">
          <thead>
            <tr>
              <th className="who-killed__th">Time</th>
              <th className="who-killed__th">Title</th>
              <th className="who-killed__th">Author User</th>
              <th className="who-killed__th who-killed__th--right">Rep</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td colSpan={4} className="who-killed__summary-row">
                Kill count for {target_user}: {total_kills.toLocaleString()}
              </td>
            </tr>
            {kills.map((kill, idx) => (
              <tr key={kill.node_id} className={idx % 2 === 0 ? 'who-killed__row--even' : 'who-killed__row--odd'}>
                <td className="who-killed__td">{kill.createtime}</td>
                <td className="who-killed__td">
                  {node_heaven_id ? (
                    <a href={`?node_id=${node_heaven_id}&visit_id=${kill.node_id}`}>{kill.title}</a>
                  ) : (
                    kill.title
                  )}
                </td>
                <td className="who-killed__td">
                  {kill.author_id > 0 ? (
                    <LinkNode node_id={kill.author_id} title={kill.author} type="user" />
                  ) : (
                    kill.author
                  )}
                </td>
                <td className="who-killed__td--right">{kill.reputation}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

export default WhoKilledWhat

import React, { useState, useEffect, useCallback } from 'react'

/**
 * VotingData - Admin tool for analyzing voting patterns (by date range or by month).
 * Styles in CSS: .voting-data__*
 *
 * Fully client-resolved (#4530): the Page is a pure gate. This fetches GET /api/voting_data
 * (admin-gated) on mount, reading voteday/voteday2/votemonth/voteyear off the URL. Both search forms
 * submit IN PLACE -- no full page reload -- syncing the URL via history.pushState (popstate refetches).
 */
const ERROR_COPY = { admin: 'Access denied. This tool is restricted to administrators.' }

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return {
    voteday: qs.get('voteday') || '',
    voteday2: qs.get('voteday2') || '',
    votemonth: qs.get('votemonth') || '',
    voteyear: qs.get('voteyear') || ''
  }
}

const VotingData = () => {
  const nodeId = (typeof window !== 'undefined' && window.e2 && window.e2.node_id) || ''

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(paramsFromUrl)

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams()
    for (const k of ['voteday', 'voteday2', 'votemonth', 'voteyear']) {
      if (params[k]) api.set(k, params[k])
    }

    if (push) {
      const url = new URL(window.location.href)
      url.searchParams.set('node_id', String(nodeId))
      for (const k of ['voteday', 'voteday2', 'votemonth', 'voteyear']) {
        if (params[k]) url.searchParams.set(k, params[k])
        else url.searchParams.delete(k)
      }
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/voting_data?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [nodeId])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => {
      const p = paramsFromUrl()
      setForm(p)
      load(p)
    }
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  if (loading && !data) {
    return <div className="voting-data"><p>Loading...</p></div>
  }
  if (data && data.state === 'admin') {
    return <div className="error-message">{ERROR_COPY.admin}</div>
  }

  const { search_type, results = [] } = data || {}

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value })
  // Date-range search: only the two date fields (clear month/year so the API takes the date branch).
  const onSearchRange = (e) => {
    e.preventDefault()
    load({ voteday: form.voteday, voteday2: form.voteday2, votemonth: '', voteyear: '' }, { push: true })
  }
  // Monthly search: only month+year (clear dates).
  const onSearchMonthly = (e) => {
    e.preventDefault()
    load({ voteday: '', voteday2: '', votemonth: form.votemonth, voteyear: form.voteyear }, { push: true })
  }

  return (
    <div className="voting-data">
      {/* Results */}
      {search_type === 'date_range' && results.length > 0 && (
        <div className="voting-data__result-box">
          <strong>Vote Results:</strong> {results[0].count.toLocaleString()} votes
          {results[0].start_date !== results[0].end_date ? (
            <span> from {results[0].start_date} to {results[0].end_date}</span>
          ) : (
            <span> on {results[0].start_date}</span>
          )}
        </div>
      )}

      {search_type === 'monthly' && results.length > 0 && (
        <div className="voting-data__section">
          <h3>Monthly Breakdown</h3>
          <table className="voting-data__table">
            <thead>
              <tr>
                <th className="voting-data__th">Date</th>
                <th className="voting-data__th voting-data__th--right">Votes</th>
              </tr>
            </thead>
            <tbody>
              {results.map((row, idx) => (
                <tr key={row.date} className={idx % 2 === 0 ? 'voting-data__row--even' : 'voting-data__row--odd'}>
                  <td className="voting-data__td">{row.date}</td>
                  <td className="voting-data__td--right">{row.count.toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="voting-data__total-row">
                <td className="voting-data__td">Total</td>
                <td className="voting-data__td--right">
                  {results.reduce((sum, r) => sum + r.count, 0).toLocaleString()}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Date-range search form -- submits in place */}
      <form onSubmit={onSearchRange}>
        <div className="voting-data__section">
          <h3>Date Range Search</h3>
          <div className="voting-data__form-row">
            <label>
              Start Date:{' '}
              <input type="text" name="voteday" value={form.voteday} onChange={handleChange} placeholder="YYYY-MM-DD" size={12} />
            </label>
          </div>
          <div className="voting-data__form-row">
            <label>
              End Date:{' '}
              <input type="text" name="voteday2" value={form.voteday2} onChange={handleChange} placeholder="YYYY-MM-DD" size={12} />
            </label>
          </div>
          <button type="submit" className="voting-data__submit">Search date range</button>
        </div>
      </form>

      {/* Monthly search form -- submits in place */}
      <form onSubmit={onSearchMonthly}>
        <div className="voting-data__section">
          <h3>Monthly Breakdown</h3>
          <div className="voting-data__form-row">
            <label>
              Year:{' '}
              <input type="text" name="voteyear" value={form.voteyear} onChange={handleChange} placeholder="YYYY" size={6} />
            </label>
          </div>
          <div className="voting-data__form-row">
            <label>
              Month:{' '}
              <input type="text" name="votemonth" value={form.votemonth} onChange={handleChange} placeholder="MM" size={4} />
            </label>
          </div>
          <button type="submit" className="voting-data__submit">Search month</button>
        </div>
      </form>
    </div>
  )
}

export default VotingData

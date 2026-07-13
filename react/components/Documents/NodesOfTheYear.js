import React, { useState, useEffect, useMemo } from 'react'
import LinkNode from '../LinkNode'
import { formatShortDate } from '../../utils/dateFormat'

/**
 * Nodes of the Year - Best writeups by year
 * Styles in CSS: .nodes-of-year__*
 *
 * Fully client-resolved (#4524): the Page is a pure gate. This reads year/wutype/count/orderby off
 * the URL and fetches GET /api/nodes_of_the_year (which runs the query + returns the writeups and
 * type-filter options). The form navigates by query param (full page load); read back on mount.
 */
const NodesOfTheYear = () => {
  const initial = useMemo(() => {
    const qs = new URLSearchParams(window.location.search)
    return {
      year: qs.get('year') || '',
      wutype: parseInt(qs.get('wutype') || '0', 10) || 0,
      count: parseInt(qs.get('count') || '50', 10) || 50,
      orderby: qs.get('orderby') || 'cooled DESC,reputation DESC'
    }
  }, [])

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams({ wutype: initial.wutype, count: initial.count, orderby: initial.orderby })
    if (initial.year) params.set('year', initial.year)
    let cancelled = false
    fetch(`/api/nodes_of_the_year?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => {
        if (cancelled) return
        setData(j)
        setLoading(false)
        // If the URL omitted year, reflect the API's default (last year) in the form field.
        if (!initial.year && j && j.year) setYear(j.year)
      })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [initial])

  const { writeup_types = [], writeups = [] } = data || {}

  const [year, setYear] = useState(initial.year || 2014)
  const [wutype, setWutype] = useState(initial.wutype || 0)
  const [count, setCount] = useState(initial.count || 50)
  const [orderby, setOrderby] = useState(initial.orderby || 'cooled DESC,reputation DESC')

  const handleSubmit = (e) => {
    e.preventDefault()
    // Preserve the current URL -- its pathname AND any node identifier already in the query (e.g.
    // ?node_id=) -- and only override the filter params. A bare `?${params}` REPLACED the whole
    // query string, so when the page was reached via a node_id URL it dropped node_id and sent the
    // user to the homepage. Building from window.location.href keeps the node in every entry shape.
    const url = new URL(window.location.href)
    url.searchParams.set('year', year)
    url.searchParams.set('wutype', wutype)
    url.searchParams.set('count', count)
    url.searchParams.set('orderby', orderby)
    window.location.href = url.toString()
  }

  const formatDate = (dateStr) => formatShortDate(dateStr) ?? ''

  const orderOptions = [
    { value: 'cooled DESC,reputation DESC', label: 'C!, then reputation' },
    { value: 'reputation DESC', label: 'Reputation' },
    { value: 'publishtime DESC', label: 'Date, most recent first' },
    { value: 'publishtime ASC', label: 'Date, most recent last' }
  ]

  const countOptions = [15, 25, 50, 75, 100, 150, 200, 250, 500]

  if (loading) {
    return (
      <div className="nodes-of-year">
        <p className="nodes-of-year__empty-state">Loading writeups...</p>
      </div>
    )
  }

  return (
    <div className="nodes-of-year">
      <form onSubmit={handleSubmit} className="nodes-of-year__form">
        <fieldset className="nodes-of-year__fieldset">
          <legend className="nodes-of-year__legend">Choose...</legend>

          <div className="nodes-of-year__form-row">
            <label className="nodes-of-year__label">
              <strong>Year:</strong>{' '}
              <input
                type="number"
                value={year}
                onChange={(e) => setYear(parseInt(e.target.value) || 2014)}
                size="4"
                maxLength="4"
                className="nodes-of-year__input"
              />
            </label>

            <label className="nodes-of-year__label">
              <strong>Select Writeup Type:</strong>{' '}
              <select
                value={wutype}
                onChange={(e) => setWutype(parseInt(e.target.value))}
                className="nodes-of-year__select"
              >
                <option value="0">All</option>
                {writeup_types.map((type) => (
                  <option key={type.node_id} value={type.node_id}>
                    {type.title}
                  </option>
                ))}
              </select>
            </label>

            <label className="nodes-of-year__label">
              <strong>Number of writeups to display:</strong>{' '}
              <select
                value={count}
                onChange={(e) => setCount(parseInt(e.target.value))}
                className="nodes-of-year__select"
              >
                {countOptions.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="nodes-of-year__form-row">
            <label className="nodes-of-year__label">
              <strong>Order By:</strong>{' '}
              <select
                value={orderby}
                onChange={(e) => setOrderby(e.target.value)}
                className="nodes-of-year__select"
              >
                {orderOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </label>

            <button type="submit" className="nodes-of-year__submit-button">
              Get Writeups
            </button>
          </div>
        </fieldset>
      </form>

      {writeups.length === 0 ? (
        <p className="nodes-of-year__empty-state">No writeups found for the selected filters.</p>
      ) : (
        <table className="nodes-of-year__table">
          <thead>
            <tr className="nodes-of-year__header-row">
              <th className="nodes-of-year__th">Title</th>
              <th className="nodes-of-year__th">Author</th>
              <th className="nodes-of-year__th">Published</th>
              <th className="nodes-of-year__th">C/rep</th>
            </tr>
          </thead>
          <tbody>
            {writeups.map((wu, index) => (
              <tr key={wu.writeup_id} className={index % 2 === 0 ? 'nodes-of-year__row--even' : 'nodes-of-year__row--odd'}>
                <td className="nodes-of-year__td">
                  <LinkNode nodeId={wu.parent_id} title={wu.parent_title} />{' '}
                  <span className="nodes-of-year__type">({wu.type_title})</span>
                </td>
                <td className="nodes-of-year__td">
                  <LinkNode nodeId={wu.author_id} title={wu.author_title} />
                </td>
                <td className="nodes-of-year__td nodes-of-year__td--right">
                  <small>{formatDate(wu.publishtime)}</small>
                </td>
                <td className="nodes-of-year__td">
                  <small>{wu.cooled}/{wu.reputation}</small>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

export default NodesOfTheYear

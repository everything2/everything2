import React, { useState, useEffect } from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything's Richest Noders - Display GP wealth distribution
 * Styles in CSS: .richest-noders__*
 *
 * Fetch-driven (#4546): the Page is a pure gate; this fetches GET /api/everything_s_richest_noders.
 * Admin-only: the restricted-superdoc gate lives in the API, which returns
 * success:0/state:'permission' to non-admins.
 */
const EverythingSRichestNoders = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/everything_s_richest_noders', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="richest-noders"><p>Loading...</p></div>
  }

  const {
    success = 0,
    total_gp = 0,
    richest_all = [],
    poorest = [],
    richest_top = [],
    top_percentage = 0,
    limit_all = 1500,
    limit_top = 10
  } = data || {}

  if (!success) {
    return (
      <div className="richest-noders">
        <p>This page is restricted to administrators.</p>
      </div>
    )
  }

  return (
    <div className="richest-noders">
      {/* Top 1500 Richest Users */}
      <h3 className="richest-noders__heading">{limit_all} Richest Noders</h3>
      <ol className="richest-noders__list">
        {richest_all.map((user) => (
          <li key={user.user_id} className="richest-noders__list-item">
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      <hr className="richest-noders__divider" />

      {/* 10 Poorest Users (excluding 0 GP) */}
      <h3 className="richest-noders__heading">{limit_top} Poorest Noders (ignore 0GP)</h3>
      <ol className="richest-noders__list">
        {poorest.map((user) => (
          <li key={user.user_id} className="richest-noders__list-item">
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      <hr className="richest-noders__divider" />

      {/* Top 10 Richest Users */}
      <h3 className="richest-noders__heading">{limit_top} Richest Noders</h3>
      <ol className="richest-noders__list">
        {richest_top.map((user) => (
          <li key={user.user_id} className="richest-noders__list-item">
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      {/* GP Statistics */}
      <p className="richest-noders__stats">
        <strong>Total GP in circulation:</strong> {Number(total_gp).toLocaleString()}
      </p>
      <p className="richest-noders__stats">
        The top {limit_top} users hold {Number(top_percentage).toFixed(2)}% of all the GP
      </p>
    </div>
  )
}

export default EverythingSRichestNoders

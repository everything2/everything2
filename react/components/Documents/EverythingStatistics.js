import React, { useState, useEffect } from 'react'
import LinkNode from '../LinkNode'

/**
 * EverythingStatistics - Site-wide statistics display
 * Styles in CSS: .everything-statistics__*
 *
 * Fetch-driven (#4546): the Page is a pure gate; this fetches GET /api/everything_statistics.
 * Admin-only: the restricted-superdoc gate lives in the API, which returns
 * success:0/state:'permission' to non-admins.
 */
const EverythingStatistics = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/everything_statistics', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  const formatNumber = (num) => Number(num || 0).toLocaleString()

  if (loading) {
    return <div className="everything-statistics"><p>Loading...</p></div>
  }

  const {
    success = 0,
    total_nodes,
    total_writeups,
    total_users,
    total_links,
    finger_node_id,
    news_node_id
  } = data || {}

  if (!success) {
    return (
      <div className="everything-statistics">
        <p>This page is restricted to administrators.</p>
      </div>
    )
  }

  return (
    <div className="everything-statistics">
      <p>Total Number of Nodes: {formatNumber(total_nodes)}</p>
      <p>Total Number of Writeups: {formatNumber(total_writeups)}</p>
      <p>Total Number of Users: {formatNumber(total_users)}</p>
      <p>Total Number of Links: {formatNumber(total_links)}</p>

      <p>
        You may also find the{' '}
        {finger_node_id ? (
          <LinkNode nodeId={finger_node_id} title="Everything Finger" />
        ) : (
          'Everything Finger'
        )}{' '}
        interesting if you are looking to pull something useful out of all these nodes. Useful? Ha.
      </p>

      {news_node_id && (
        <p>
          <LinkNode nodeId={news_node_id} title="news for noders. stuff that matters." />
        </p>
      )}
    </div>
  )
}

export default EverythingStatistics

import React, { useState, useEffect } from 'react'

/**
 * UserStatistics - Display user activity statistics
 *
 * Fetch-driven (#4546): the Page is a pure gate; this fetches GET /api/user_statistics.
 * Admin-only: the restricted-superdoc gate lives in the API, which returns
 * success:0/state:'permission' to non-admins.
 */
const UserStatistics = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/user_statistics', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="user-statistics"><p>Loading...</p></div>
  }

  const {
    success = 0,
    total_users = 0,
    users_ever_logged_in = 0,
    users_last_24h = 0,
    users_last_week = 0,
    users_last_2weeks = 0,
    users_last_4weeks = 0
  } = data || {}

  if (!success) {
    return (
      <div className="user-statistics">
        <p>This page is restricted to administrators.</p>
      </div>
    )
  }

  const stats = [
    { value: total_users, label: 'total users registered' },
    { value: users_ever_logged_in, label: 'unique users logged in ever' },
    { value: users_last_4weeks, label: 'users logged in within the last 4 weeks' },
    { value: users_last_2weeks, label: 'users logged in within the last 2 weeks' },
    { value: users_last_week, label: 'users logged in within the last week' },
    { value: users_last_24h, label: 'users logged in within the last 24 hours' }
  ]

  return (
    <div className="user-statistics">
      <table>
        <tbody>
          {stats.map((stat, idx) => (
            <tr key={idx}>
              <td className="user-statistics__value-cell">
                <strong>{Number(stat.value).toLocaleString()}</strong>
              </td>
              <td>{stat.label}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default UserStatistics

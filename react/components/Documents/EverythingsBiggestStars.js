import React, { useState, useEffect } from 'react'

/**
 * Everything's Biggest Stars - top users by star count.
 *
 * Fetch-driven (#4546): the Page is a pure gate; this fetches GET /api/everything_s_biggest_stars.
 */
export default function EverythingsBiggestStars() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/everything_s_biggest_stars', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="biggest-stars"><p>Loading...</p></div>
  }

  const { users = [], limit = 100 } = data || {}

  return (
    <div className="biggest-stars">
      <h3>{limit} Most Starred Noders</h3>

      {users.length === 0 ? (
        <p className="biggest-stars__empty">
          No users with stars found
        </p>
      ) : (
        <ol>
          {users.map((user) => (
            <li key={user.node_id}>
              <a href={`/user/${encodeURIComponent(user.title)}?lastnode_id=`}>
                {user.title}
              </a>
              {' '}({user.stars} star{user.stars !== 1 ? 's' : ''})
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

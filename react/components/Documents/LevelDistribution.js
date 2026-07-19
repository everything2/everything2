import React, { useState, useEffect } from 'react'

/**
 * Level Distribution - Active users at each level
 * Styles in CSS: .level-distribution__*
 *
 * Fetch-driven (#4546): the Page is a pure gate; this fetches GET /api/level_distribution.
 */
export default function LevelDistribution() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/level_distribution', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="level-distribution"><p>Loading...</p></div>
  }

  const { levels = [] } = data || {}

  return (
    <div className="level-distribution">
      <p>
        The following shows the number of active E2 users at each level (based on users logged in over the last month).
      </p>

      {levels.length === 0 ? (
        <p className="level-distribution__empty">
          No active users found
        </p>
      ) : (
        <table className="level-distribution__table">
          <thead>
            <tr>
              <th className="level-distribution__th">
                Level
              </th>
              <th className="level-distribution__th">
                Title
              </th>
              <th className="level-distribution__th level-distribution__th--right">
                Number of Users
              </th>
            </tr>
          </thead>
          <tbody>
            {levels.map((levelData, index) => (
              <tr
                key={levelData.level}
                className={index % 2 === 0 ? 'level-distribution__row--even' : 'level-distribution__row--odd'}
              >
                <td className="level-distribution__td">
                  {levelData.level}
                </td>
                <td className="level-distribution__td">
                  {levelData.title}
                </td>
                <td className="level-distribution__td level-distribution__td--right">
                  {levelData.count}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

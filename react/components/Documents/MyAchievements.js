import React from 'react'

/**
 * MyAchievements - Display user's earned and available achievements
 * Styles in CSS: .my-achievements__*
 *
 * Shows:
 * - List of achievements the user has earned
 * - List of achievements still available to earn
 * - Progress statistics
 * - Debug mode for edev users (with ?debug=1)
 */
const MyAchievements = ({ data }) => {
  const {
    guest,
    achieved = [],
    unachieved = [],
    achieved_count,
    total_count,
    debug_mode,
    debug_data = {}
  } = data

  if (guest) {
    return (
      <div className="my-achievements">
        <p>If you logged in, you could see what achievements you've earned here.</p>
      </div>
    )
  }

  return (
    <div className="my-achievements">
      <p>
        You have reached <strong>{achieved_count}</strong> out of a total of{' '}
        <strong>{total_count}</strong> achievements:
      </p>

      {Boolean(achieved.length) && (
        <ul className="my-achievements__list">
          {achieved.map((achievement, index) => (
            <li key={achievement.id || index} dangerouslySetInnerHTML={{ __html: achievement.display }} />
          ))}
        </ul>
      )}

      <h3 className="my-achievements__heading">Achievements Left To Reach</h3>

      {unachieved.length > 0 ? (
        <ul className="my-achievements__list">
          {unachieved.map((achievement, index) => (
            <li key={achievement.id || index} dangerouslySetInnerHTML={{ __html: achievement.display }} />
          ))}
        </ul>
      ) : (
        <p className="my-achievements__no-achievements">
          <em>You've earned all available achievements!</em>
        </p>
      )}

      {Boolean(debug_mode) && (
        <div className="my-achievements__debug-section">
          <h3 className="my-achievements__heading">Debug: Achievements By Type</h3>
          <table className="my-achievements__debug-table">
            <thead>
              <tr>
                <th className="my-achievements__th">Type</th>
                <th className="my-achievements__th">Achieved</th>
                <th className="my-achievements__th">Total</th>
                <th className="my-achievements__th">Progress</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(debug_data).map(([type, stats]) => (
                <tr key={type}>
                  <td className="my-achievements__td">{type}</td>
                  <td className="my-achievements__td">{stats.achieved}</td>
                  <td className="my-achievements__td">{stats.total}</td>
                  <td className="my-achievements__td">
                    {stats.total > 0
                      ? `${((stats.achieved / stats.total) * 100).toFixed(1)}%`
                      : 'N/A'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default MyAchievements

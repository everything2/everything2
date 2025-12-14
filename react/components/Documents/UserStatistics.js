import React from 'react'

/**
 * UserStatistics - Display user activity statistics
 *
 * Shows login activity over various time periods.
 */
const UserStatistics = ({ data }) => {
  const {
    total_users = 0,
    users_ever_logged_in = 0,
    users_last_24h = 0,
    users_last_week = 0,
    users_last_2weeks = 0,
    users_last_4weeks = 0
  } = data

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
              <td style={{ textAlign: 'right', paddingRight: '10px' }}>
                <strong>{stat.value.toLocaleString()}</strong>
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

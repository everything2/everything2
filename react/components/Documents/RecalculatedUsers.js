import React from 'react'

/**
 * RecalculatedUsers - Display users who have run Recalculate XP
 * Styles in CSS: .recalculated-users__*
 */
const RecalculatedUsers = ({ data }) => {
  const { users, count } = data?.recalculatedUsers || { users: [], count: 0 }

  return (
    <div className="recalculated-users">
      <div className="recalculated-users__header">
        <h1 className="recalculated-users__title">Users who have run Recalculate XP</h1>
        <div className="recalculated-users__count">{count} user{count !== 1 ? 's' : ''} found</div>
      </div>

      {users.length === 0 ? (
        <div className="recalculated-users__empty-message">
          No users have run the Recalculate XP function yet.
        </div>
      ) : (
        <ol className="recalculated-users__list">
          {users.map((user) => (
            <li key={user.node_id} className="recalculated-users__list-item">
              <a
                href={`/user/${encodeURIComponent(user.title)}`}
                title={user.title}
                className="recalculated-users__user-link"
              >
                {user.title}
              </a>
              <span className="recalculated-users__stats">
                - Level: {user.level} - XP: {user.xp.toLocaleString()}
              </span>
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

export default RecalculatedUsers

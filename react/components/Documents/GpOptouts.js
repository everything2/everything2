import React from 'react'
import LinkNode from '../LinkNode'

/**
 * GP Optouts - Display users who have opted out of the GP system
 * Styles in CSS: .gp-optouts__*
 *
 * Admin tool showing users who have disabled Group Points in their settings.
 * Shows username, level, and current GP for each opted-out user.
 */
const GpOptouts = ({ data }) => {
  const { users = [], error } = data

  if (error) {
    return (
      <div className="gp-optouts">
        <div className="gp-optouts__error">{error}</div>
      </div>
    )
  }

  return (
    <div className="gp-optouts">
      <h3 className="gp-optouts__heading">Users who have opted out of the GP system</h3>

      {users.length === 0 ? (
        <p className="gp-optouts__empty-state">No users have opted out of the GP system.</p>
      ) : (
        <ol className="gp-optouts__list">
          {users.map((user) => (
            <li key={user.user_id} className="gp-optouts__list-item">
              <LinkNode nodeId={user.user_id} title={user.username} />
              {' - '}
              Level: {user.level}; GP: {user.gp}
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

export default GpOptouts

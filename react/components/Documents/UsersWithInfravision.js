import React from 'react'
import LinkNode from '../LinkNode'

/**
 * UsersWithInfravision - List users with infravision enabled
 * Styles in CSS: .users-with-infravision__*
 *
 * Admin tool showing all users who have the special infravision
 * setting enabled.
 */
const UsersWithInfravision = ({ data }) => {
  const { error, users = [], count = 0 } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="users-with-infravision">
      <p className="users-with-infravision__intro">
        {count} user{count !== 1 ? 's' : ''} currently {count !== 1 ? 'have' : 'has'} infravision enabled.
      </p>
      {users.length > 0 && (
        <table className="users-with-infravision__table">
          <thead>
            <tr>
              <th className="users-with-infravision__th users-with-infravision__th--num">#</th>
              <th className="users-with-infravision__th">User</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, index) => (
              <tr key={user.user_id} className={index % 2 === 1 ? 'users-with-infravision__row--odd' : ''}>
                <td className="users-with-infravision__td users-with-infravision__td--num">{index + 1}</td>
                <td className="users-with-infravision__td">
                  <LinkNode node_id={user.user_id} title={user.title} type="user" />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

export default UsersWithInfravision

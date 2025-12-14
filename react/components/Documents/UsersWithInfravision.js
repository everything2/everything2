import React from 'react'
import LinkNode from '../LinkNode'

/**
 * UsersWithInfravision - List users with infravision enabled
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
      <h3>Users with infravision</h3>
      <p>Total: {count} users</p>
      <ol style={{ marginLeft: '55px' }}>
        {users.map((user) => (
          <li key={user.user_id}>
            <LinkNode node_id={user.user_id} title={user.title} type="user" />
          </li>
        ))}
      </ol>
    </div>
  )
}

export default UsersWithInfravision

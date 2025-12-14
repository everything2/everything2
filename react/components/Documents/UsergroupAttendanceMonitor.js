import React from 'react'

/**
 * UsergroupAttendanceMonitor - Monitor inactive usergroup members
 *
 * Shows users in usergroups who haven't logged in for over 365 days.
 */
const UsergroupAttendanceMonitor = ({ data }) => {
  const { error, inactive_users = [], count = 0 } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="usergroup-attendance-monitor">
      <p>
        Users that haven't been here in 365 days. I propose that we auto remove
        someone who hasn't been to the site in 30 days unless they choose to
        ignore a certain usergroup's messages (with the exception of: gods and
        content editors). With usergroup ownership, it is now much easier for
        people to be able to manage those groups.
      </p>
      <p>For now, here is an active, automatic list.</p>

      <hr style={{ width: '30%', margin: '1.5em auto' }} />

      {count === 0 ? (
        <p><em>No inactive usergroup members found.</em></p>
      ) : (
        <ul>
          {inactive_users.map((user) => (
            <li key={user.user_id}>
              <a href={`/?node_id=${user.user_id}`}>{user.user_title}</a>
              {' '}
              <small>
                ({user.groups.map((grp, idx) => (
                  <span key={grp.group_id}>
                    {idx > 0 && ', '}
                    <a href={`/?node_id=${grp.group_id}`}>{grp.group_title}</a>
                    {Boolean(grp.is_ignored) && '-ignored'}
                  </span>
                ))})
              </small>
            </li>
          ))}
        </ul>
      )}

      <p style={{ marginTop: '1em' }}>
        <strong>Total inactive users:</strong> {count}
      </p>
    </div>
  )
}

export default UsergroupAttendanceMonitor

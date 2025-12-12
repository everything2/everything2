import React from 'react'
import LinkNode from '../LinkNode'
import TimeSince from '../TimeSince'

/**
 * FreshlyBloodied - Display newly registered users who have been locked
 *
 * Shows a paginated table of users who enrolled recently and were locked,
 * with information about who locked them.
 */
const FreshlyBloodied = ({ data }) => {
  const {
    total_users = 0,
    locked_count = 0,
    users = [],
    start = 0,
    page_size = 50,
    message,
    error
  } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  if (message) {
    return <div className="info-message">{message}</div>
  }

  const totalPages = Math.ceil(locked_count / page_size)
  const currentPage = Math.floor(start / page_size)

  // Generate page links
  const pageLinks = []
  for (let i = 0; i < totalPages; i++) {
    const pageStart = i * page_size
    const label = pageStart === 0 ? '1' : pageStart
    if (i === currentPage) {
      pageLinks.push(<strong key={i}>{label}</strong>)
    } else {
      pageLinks.push(
        <a key={i} href={`?start=${pageStart}`}>{label}</a>
      )
    }
    pageLinks.push(' ')
  }

  const hasPrev = start > 0
  const hasNext = start + page_size < locked_count

  return (
    <div className="freshly-bloodied">
      <p>
        In the past week, <strong>{total_users}</strong> users enrolled.
        Of those, <strong>{locked_count}</strong> were locked.
      </p>

      <div className="pagination" style={{ textAlign: 'center', margin: '1em 0' }}>
        {hasPrev && (
          <>
            <a href={`?start=${start - page_size}`}>&laquo; Later</a>
            {' '}
          </>
        )}
        {pageLinks}
        {hasNext && (
          <>
            <a href={`?start=${start + page_size}`}>Earlier &raquo;</a>
          </>
        )}
      </div>

      <table style={{ width: '100%', borderTop: '1px gray solid' }}>
        <thead>
          <tr>
            <th>Joined</th>
            <th>User</th>
            <th>Last logged in</th>
            <th>Node note</th>
            <th>Locked By</th>
            <th>Validated</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user, index) => (
            <tr key={user.user_id} className={index % 2 === 0 ? 'oddrow' : 'evenrow'}>
              <td>
                <TimeSince timestamp={user.createtime} />
              </td>
              <td>
                <LinkNode
                  node_id={user.user_id}
                  title={user.nick}
                  type="user"
                />
              </td>
              <td>
                {user.lasttime > 0 ? (
                  <TimeSince timestamp={user.lasttime} />
                ) : (
                  'never'
                )}
              </td>
              <td>{user.notetext}</td>
              <td>
                <LinkNode
                  node_id={user.locker_id}
                  title={user.locker_name}
                  type="user"
                />
              </td>
              <td>{user.validemail ? 'Yes' : 'No'}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div className="pagination" style={{ textAlign: 'center', margin: '1em 0' }}>
        {hasPrev && (
          <>
            <a href={`?start=${start - page_size}`}>&laquo; Later</a>
            {' '}
          </>
        )}
        {pageLinks}
        {hasNext && (
          <>
            <a href={`?start=${start + page_size}`}>Earlier &raquo;</a>
          </>
        )}
      </div>
    </div>
  )
}

export default FreshlyBloodied

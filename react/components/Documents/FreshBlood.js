import React from 'react'
import LinkNode from '../LinkNode'
import TimeSince from '../TimeSince'

/**
 * FreshBlood - Display newly registered users from the past week
 *
 * Shows a paginated table of users who enrolled recently,
 * whether they've logged in, and any node notes.
 */
const FreshBlood = ({ data }) => {
  const {
    total_users = 0,
    logged_in_count = 0,
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

  const totalPages = Math.ceil(total_users / page_size)
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
  const hasNext = start + page_size < total_users

  return (
    <div className="fresh-blood">
      <p>
        In the past week, <strong>{total_users}</strong> users enrolled.
        Of those, <strong>{logged_in_count}</strong> logged in.
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
                  title={user.title}
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

export default FreshBlood

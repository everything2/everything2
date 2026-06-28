import React from 'react'

/**
 * MarkAllDiscussionsAsRead - Mark all debates/discussions as read
 *
 * Allows CE members to mark CE debates as read,
 * and admins to mark admin debates as read.
 */
const MarkAllDiscussionsAsRead = ({ data, user }) => {
  const {
    ce_marked,
    admin_marked,
    messages = [],
    error,
    node_id
  } = data

  // Viewer role flags come from the global e2.user prop (#4390 dedup)
  const isAdmin = !!user?.admin

  // Build base URL with node_id to ensure form posts back to this page
  const baseUrl = node_id ? `?node_id=${node_id}` : '?'

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="mark-discussions-read">
      {messages.length > 0 && (
        <div className="mark-discussions__messages">
          {messages.map((msg, i) => (
            <p key={i} className="mark-discussions__success">{msg}</p>
          ))}
        </div>
      )}

      {!Boolean(ce_marked) && (
        <div className="mark-discussions__section">
          <p>
            Apply pressure to the hypertext if you want to mark all of
            your old CE debates as read (and the new ones too, everything!).
          </p>
          <p className="mark-discussions__link">
            <a href={`${baseUrl}&mark_ce_read=1`} className="mark-discussions__button">Mark CE Debates as Read</a>
          </p>
        </div>
      )}

      {Boolean(ce_marked) && (
        <p>
          It is done. All of your CE debates have been marked as read.
          Hopefully there's never a reason to do this again.
        </p>
      )}

      {isAdmin && !Boolean(admin_marked) && (
        <div className="mark-discussions__admin-section">
          <p>
            It appears you are like a god amongst men. You may do the same
            but to your admin debates.
          </p>
          <p className="mark-discussions__link">
            <a href={`${baseUrl}&mark_admin_read=1`} className="mark-discussions__button">Mark Admin Debates as Read</a>
          </p>
        </div>
      )}

      {isAdmin && Boolean(admin_marked) && (
        <p className="mark-discussions__done">
          It is done. All of your admin debates have been marked as read.
          Hopefully there's never a reason to do this again.
        </p>
      )}
    </div>
  )
}

export default MarkAllDiscussionsAsRead

import React from 'react'

/**
 * MarkAllDiscussionsAsRead - Mark all debates/discussions as read
 *
 * Allows CE members to mark CE debates as read,
 * and admins to mark admin debates as read.
 */
const MarkAllDiscussionsAsRead = ({ data }) => {
  const {
    is_admin,
    is_editor,
    ce_marked,
    admin_marked,
    messages = [],
    error,
    node_id
  } = data

  // Build base URL with node_id to ensure form posts back to this page
  const baseUrl = node_id ? `?node_id=${node_id}` : '?'

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="mark-discussions-read">
      {messages.length > 0 && (
        <div className="success-messages" style={{ marginBottom: '1em' }}>
          {messages.map((msg, i) => (
            <p key={i} style={{ color: 'green' }}>{msg}</p>
          ))}
        </div>
      )}

      {!Boolean(ce_marked) && (
        <div style={{ marginBottom: '2em' }}>
          <p>
            Apply pressure to the hypertext if you want to mark all of
            your old CE debates as read (and the new ones too, everything!).
          </p>
          <p style={{ textAlign: 'center' }}>
            <a href={`${baseUrl}&mark_ce_read=1`}>Mark CE Debates as Read</a>
          </p>
        </div>
      )}

      {Boolean(ce_marked) && (
        <p>
          It is done. All of your CE debates have been marked as read.
          Hopefully there's never a reason to do this again.
        </p>
      )}

      {Boolean(is_admin) && !Boolean(admin_marked) && (
        <div style={{ marginTop: '2em' }}>
          <p>
            It appears you are like a god amongst men. You may do the same
            but to your admin debates.
          </p>
          <p style={{ textAlign: 'center' }}>
            <a href={`${baseUrl}&mark_admin_read=1`}>Mark Admin Debates as Read</a>
          </p>
        </div>
      )}

      {Boolean(is_admin) && Boolean(admin_marked) && (
        <p style={{ marginTop: '2em' }}>
          It is done. All of your admin debates have been marked as read.
          Hopefully there's never a reason to do this again.
        </p>
      )}
    </div>
  )
}

export default MarkAllDiscussionsAsRead

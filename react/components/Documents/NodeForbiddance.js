import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeForbiddance - Admin tool to forbid/unforbid users from creating nodes.
 *
 * Forbid/unforbid POST to /api/nodeforbiddance/{forbid,unforbid} (#4408) rather
 * than mutating nodelock via a POST form / GET link inside the controller. On
 * success the page reloads so the forbidden-users list reflects the change.
 *
 * Styles in CSS: .node-forbiddance__*
 */
const NodeForbiddance = ({ data }) => {
  const { forbidden_users } = data

  const [forbidUser, setForbidUser] = useState('')
  const [forbidReason, setForbidReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  const post = async (route, body) => {
    setBusy(true)
    setError(null)
    try {
      const res = await fetch(`/api/nodeforbiddance/${route}`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(body),
      })
      const result = res.ok ? await res.json() : null
      if (result && result.success) {
        window.location.reload()
      } else {
        setError((result && result.error) || 'Action failed')
        setBusy(false)
      }
    } catch (err) {
      setError(err.message || 'Action failed')
      setBusy(false)
    }
  }

  const handleForbid = (e) => {
    e.preventDefault()
    if (!forbidUser.trim()) {
      setError('Enter a username to forbid')
      return
    }
    post('forbid', { user: forbidUser.trim(), reason: forbidReason })
  }

  const handleUnforbid = (userId) => post('unforbid', { user_id: userId })

  return (
    <div className="node-forbiddance">
      {error && <p className="node-forbiddance__error">{error}</p>}

      <form onSubmit={handleForbid} className="node-forbiddance__form">
        <div className="node-forbiddance__form-group">
          <label className="node-forbiddance__label">
            Forbid user:
            <input
              type="text"
              value={forbidUser}
              onChange={(e) => setForbidUser(e.target.value)}
              className="node-forbiddance__input"
              placeholder="Username"
              disabled={busy}
            />
          </label>
        </div>
        <div className="node-forbiddance__form-group">
          <label className="node-forbiddance__label">
            Reason:
            <input
              type="text"
              value={forbidReason}
              onChange={(e) => setForbidReason(e.target.value)}
              className="node-forbiddance__input"
              placeholder="Reason for forbiddance"
              disabled={busy}
            />
          </label>
        </div>
        <button type="submit" className="node-forbiddance__button" disabled={busy}>
          Forbid User
        </button>
      </form>

      <hr className="node-forbiddance__hr" />

      <h3 className="node-forbiddance__subtitle">Currently Forbidden Users</h3>

      {forbidden_users.length === 0 ? (
        <p><em>No users are currently forbidden.</em></p>
      ) : (
        <ul className="node-forbiddance__list">
          {forbidden_users.map((user) => (
            <li key={user.user_id} className="node-forbiddance__list-item">
              <LinkNode nodeId={user.user_id} title={user.user_title} />
              {' '}is forbidden by{' '}
              <LinkNode nodeId={user.forbidder_id} title={user.forbidder_title} />
              {' '}
              <small>
                ({user.reason ? (
                  <span dangerouslySetInnerHTML={{ __html: user.reason }} />
                ) : (
                  <em>No reason given</em>
                )})
              </small>
              {' '}
              <button
                type="button"
                onClick={() => handleUnforbid(user.user_id)}
                className="node-forbiddance__unforbid-btn"
                disabled={busy}
              >
                unforbid
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default NodeForbiddance

import React, { useState } from 'react'

/**
 * TheBorgClinic - Admin tool for managing user borg counts
 *
 * Users stay borged for 4 + (2 * borgcount) minutes. As of #4449 the borg-count
 * write goes to POST /api/borgclinic/setborg (admin-gated); the user lookup is a
 * read (navigation), so this page no longer mutates on render.
 */
const TheBorgClinic = ({ data }) => {
  const {
    error,
    node_id,
    clinic_user = '',
    user_found,
    user_id,
    user_title,
    borg_count = 0,
    show_editor,
  } = data

  const [username, setUsername] = useState(clinic_user)
  const [count, setCount] = useState(String(borg_count))
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState(null)

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // Look up a user -> navigate so the page renders their current borg count (a read).
  const handleLookup = (e) => {
    e.preventDefault()
    if (!username.trim()) return
    window.location.href = `/?node_id=${node_id}&clinic_user=${encodeURIComponent(username)}`
  }

  // Set the borg count through the admin API, then reload into the updated view.
  const handleSetBorg = async (e) => {
    e.preventDefault()
    setSaving(true)
    setSaveError(null)
    try {
      const res = await fetch('/api/borgclinic/setborg', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ user: user_title, count }),
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        window.location.href =
          `/?node_id=${node_id}&clinic_user=${encodeURIComponent(user_title)}`
      } else {
        setSaveError((json && json.error) || 'Failed to set borg count')
        setSaving(false)
      }
    } catch (err) {
      setSaveError(err.message || 'Failed to set borg count')
      setSaving(false)
    }
  }

  const showEditor = Boolean(user_found) && Boolean(show_editor)

  return (
    <div className="borg-clinic">
      <p>Circle circle, dot dot, now you've got your borg shot!</p>

      <form onSubmit={handleLookup}>
        <p>Who needs to be looked at?</p>
        <p>
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            size={30}
          />
        </p>
        <p className="borg-clinic__submit-row">
          <button type="submit" className="borg-clinic__submit-btn">
            Do it!
          </button>
        </p>
      </form>

      {showEditor && (
        <form onSubmit={handleSetBorg} className="borg-clinic__user-section">
          <p>
            <strong>User:</strong>{' '}
            <a href={`/?node_id=${user_id}`}>{user_title}</a>
          </p>

          <p>
            <label>
              <small>Borg count:</small><br />
              <input
                type="text"
                value={count}
                onChange={(e) => setCount(e.target.value)}
                size={10}
              />
            </label>
          </p>

          <div className="borg-clinic__hint">
            <p>Users stay borged for 4 minutes plus two minutes times this number. (4 + (2 × x))</p>
            <p><strong>Quick math (should it ever come to this):</strong></p>
            <ul>
              <li>28 is an hour</li>
              <li>714 is a day</li>
              <li>5038 is a week</li>
            </ul>
            <p>Negative numbers are "borg insurance", meaning that you pop out instantly.</p>
          </div>

          {saveError && <div className="borg-clinic__error">{saveError}</div>}

          <p className="borg-clinic__submit-row">
            <button type="submit" className="borg-clinic__submit-btn" disabled={saving}>
              {saving ? 'Setting…' : 'Do it!'}
            </button>
          </p>
        </form>
      )}
    </div>
  )
}

export default TheBorgClinic

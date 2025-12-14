import React, { useState } from 'react'

/**
 * TheBorgClinic - Admin tool for managing user borg counts
 *
 * Allows admins to view and modify user borg counts.
 * Users stay borged for 4 + (2 * borgcount) minutes.
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
    updated
  } = data

  const [username, setUsername] = useState(clinic_user)

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="borg-clinic">
      <p>Circle circle, dot dot, now you've got your borg shot!</p>

      <form method="POST">
        <input type="hidden" name="node_id" value={node_id} />

        <p>Who needs to be looked at?</p>
        <p>
          <input
            type="text"
            name="clinic_user"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            size={30}
          />
        </p>

        {Boolean(user_found) && Boolean(show_editor) && (
          <div style={{ marginTop: '1em', padding: '10px', backgroundColor: '#f8f9f9', border: '1px solid #ddd' }}>
            {Boolean(updated) && (
              <p style={{ color: 'green', fontWeight: 'bold' }}>Borg count updated!</p>
            )}

            <p>
              <strong>User:</strong>{' '}
              <a href={`/?node_id=${user_id}`}>{user_title}</a>
            </p>

            <p>
              <label>
                <small>Borg count:</small><br />
                <input
                  type="text"
                  name="clinic_borgcount"
                  defaultValue={borg_count}
                  size={10}
                />
              </label>
            </p>

            <div style={{ fontSize: '0.85em', color: '#666', marginTop: '0.5em' }}>
              <p>Users stay borged for 4 minutes plus two minutes times this number. (4 + (2 × x))</p>
              <p><strong>Quick math (should it ever come to this):</strong></p>
              <ul>
                <li>28 is an hour</li>
                <li>714 is a day</li>
                <li>5038 is a week</li>
              </ul>
              <p>Negative numbers are "borg insurance", meaning that you pop out instantly.</p>
            </div>

            <p style={{ marginTop: '1em' }}>
              <a href={`/?node_id=${node_id}`}>I'd like another patient</a>
            </p>
          </div>
        )}

        <p style={{ marginTop: '1em' }}>
          <button
            type="submit"
            style={{
              padding: '6px 15px',
              backgroundColor: '#38495e',
              color: '#fff',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
          >
            Do it!
          </button>
        </p>
      </form>
    </div>
  )
}

export default TheBorgClinic

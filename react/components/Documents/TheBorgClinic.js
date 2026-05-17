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
          <div className="borg-clinic__user-section">
            {Boolean(updated) && (
              <p className="borg-clinic__updated-message">Borg count updated!</p>
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

            <p className="borg-clinic__another-patient">
              <a href={`/?node_id=${node_id}`}>I'd like another patient</a>
            </p>
          </div>
        )}

        <p className="borg-clinic__submit-row">
          <button type="submit" className="borg-clinic__submit-btn">
            Do it!
          </button>
        </p>
      </form>
    </div>
  )
}

export default TheBorgClinic

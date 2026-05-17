import React, { useState } from 'react';

/**
 * E2 Bouncer - Chanop tool for bulk user room management
 * Styles in CSS: .e2-bouncer__*
 *
 * Also known as "Nerf Borg" - a softer way to manage user locations
 * by moving them to different chat rooms instead of borging them.
 */
const E2Bouncer = ({ data, e2 }) => {
  const {
    is_chanop = false,
    rooms = [],
    quip = '',
    prefill_user = ''
  } = data;

  const [usernames, setUsernames] = useState(prefill_user);
  const [selectedRoom, setSelectedRoom] = useState('outside');
  const [processing, setProcessing] = useState(false);
  const [result, setResult] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!usernames.trim()) {
      setResult({
        success: false,
        error: 'Please enter at least one username'
      });
      return;
    }

    // Parse usernames (one per line)
    const usernameList = usernames
      .split('\n')
      .map(u => u.trim())
      .filter(u => u.length > 0);

    if (usernameList.length === 0) {
      setResult({
        success: false,
        error: 'Please enter at least one username'
      });
      return;
    }

    setProcessing(true);
    setResult(null);

    try {
      const response = await fetch('/api/bouncer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          usernames: usernameList,
          room_title: selectedRoom
        })
      });

      const json = await response.json();
      setResult(json);

      // Clear usernames on success
      if (json.success && json.moved && json.moved.length > 0) {
        setUsernames('');
      }
    } catch (err) {
      setResult({
        success: false,
        error: 'Failed to move users: ' + err.message
      });
    } finally {
      setProcessing(false);
    }
  };

  // Permission denied
  if (!is_chanop) {
    return (
      <div className="e2-bouncer">
        <div className="e2-bouncer__error">
          <strong>Permission Denied.</strong>
          <p>E2 Bouncer is only available to Channel Operators (Chanops).</p>
        </div>
      </div>
    );
  }

  return (
    <div className="e2-bouncer">
      <div className="e2-bouncer__description">
        <p><em>...a.k.a Nerf Borg.</em></p>
        <p>
          Move users between chat rooms without borging them.
          A gentler way to manage where people are hanging out.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="e2-bouncer__form">
        <div className="e2-bouncer__form-row">
          <div className="e2-bouncer__label-column">
            <label className="e2-bouncer__label">Move user(s):</label>
            <p className="e2-bouncer__hint">
              Put each username on its own line, and don't hardlink them.
            </p>
          </div>
          <div className="e2-bouncer__input-column">
            <textarea
              className="e2-bouncer__textarea"
              value={usernames}
              onChange={(e) => setUsernames(e.target.value)}
              rows={12}
              placeholder="username1&#10;username2&#10;username3"
              disabled={processing}
            />
          </div>
        </div>

        <div className="e2-bouncer__form-row">
          <div className="e2-bouncer__label-column">
            <label className="e2-bouncer__label">To room:</label>
          </div>
          <div className="e2-bouncer__input-column">
            <select
              className="e2-bouncer__select"
              value={selectedRoom}
              onChange={(e) => setSelectedRoom(e.target.value)}
              disabled={processing}
            >
              <option value="outside">outside</option>
              {rooms.map(room => (
                <option key={room.node_id} value={room.title}>
                  {room.title}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="e2-bouncer__form-row">
          <div className="e2-bouncer__label-column"></div>
          <div className="e2-bouncer__input-column">
            <button
              type="submit"
              className={`e2-bouncer__button${processing ? ' e2-bouncer__button--disabled' : ''}`}
              disabled={processing}
            >
              {processing ? 'Moving...' : 'Move Users'}
            </button>
          </div>
        </div>
      </form>

      {result && (
        <div className="e2-bouncer__result">
          {result.success ? (
            <>
              {result.moved && result.moved.length > 0 && (
                <div className="e2-bouncer__success-box">
                  <h4 className="e2-bouncer__result-heading">
                    Moved to {result.room_title}:
                  </h4>
                  <ol className="e2-bouncer__user-list">
                    {result.moved.map((username, index) => (
                      <li key={index}>
                        <a href={`/title/${encodeURIComponent(username)}`} className="e2-bouncer__user-link">
                          {username}
                        </a>
                      </li>
                    ))}
                  </ol>
                </div>
              )}

              {result.not_found && result.not_found.length > 0 && (
                <div className="e2-bouncer__warning-box">
                  <h4 className="e2-bouncer__result-heading">Users not found:</h4>
                  <ul className="e2-bouncer__error-list">
                    {result.not_found.map((username, i) => (
                      <li key={i}><strong>"{username}"</strong> does not exist</li>
                    ))}
                  </ul>
                </div>
              )}

              {(!result.moved || result.moved.length === 0) && (
                <div className="e2-bouncer__warning-box">
                  <p>No users were moved.</p>
                </div>
              )}
            </>
          ) : (
            <div className="e2-bouncer__error-box">
              <strong>Error:</strong> {result.error}
            </div>
          )}
        </div>
      )}

      <hr className="e2-bouncer__divider" />

      <div className="e2-bouncer__room-list">
        <p className="e2-bouncer__quip">{quip}</p>
        <p>Visit room:</p>
        <ul>
          <li><a href="/title/Go%20Outside" className="e2-bouncer__room-link">outside</a></li>
          {rooms.map(room => (
            <li key={room.node_id}>
              <a href={`/title/${encodeURIComponent(room.title)}`} className="e2-bouncer__room-link">
                {room.title}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default E2Bouncer;

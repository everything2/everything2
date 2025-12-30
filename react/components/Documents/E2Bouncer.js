import React, { useState } from 'react';

/**
 * E2 Bouncer - Chanop tool for bulk user room management
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
      <div style={styles.container}>
        <div style={styles.error}>
          <strong>Permission Denied.</strong>
          <p>E2 Bouncer is only available to Channel Operators (Chanops).</p>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.description}>
        <p><em>...a.k.a Nerf Borg.</em></p>
        <p>
          Move users between chat rooms without borging them.
          A gentler way to manage where people are hanging out.
        </p>
      </div>

      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <div style={styles.labelColumn}>
            <label style={styles.label}>Move user(s):</label>
            <p style={styles.hint}>
              Put each username on its own line, and don't hardlink them.
            </p>
          </div>
          <div style={styles.inputColumn}>
            <textarea
              style={styles.textarea}
              value={usernames}
              onChange={(e) => setUsernames(e.target.value)}
              rows={12}
              placeholder="username1&#10;username2&#10;username3"
              disabled={processing}
            />
          </div>
        </div>

        <div style={styles.formRow}>
          <div style={styles.labelColumn}>
            <label style={styles.label}>To room:</label>
          </div>
          <div style={styles.inputColumn}>
            <select
              style={styles.select}
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

        <div style={styles.formRow}>
          <div style={styles.labelColumn}></div>
          <div style={styles.inputColumn}>
            <button
              type="submit"
              style={{
                ...styles.button,
                ...(processing ? styles.buttonDisabled : {})
              }}
              disabled={processing}
            >
              {processing ? 'Moving...' : 'Move Users'}
            </button>
          </div>
        </div>
      </form>

      {result && (
        <div style={styles.result}>
          {result.success ? (
            <>
              {result.moved && result.moved.length > 0 && (
                <div style={styles.successBox}>
                  <h4 style={styles.resultHeading}>
                    Moved to {result.room_title}:
                  </h4>
                  <ol style={styles.userList}>
                    {result.moved.map((username, index) => (
                      <li key={index}>
                        <a href={`/title/${encodeURIComponent(username)}`} style={styles.userLink}>
                          {username}
                        </a>
                      </li>
                    ))}
                  </ol>
                </div>
              )}

              {result.not_found && result.not_found.length > 0 && (
                <div style={styles.warningBox}>
                  <h4 style={styles.resultHeading}>Users not found:</h4>
                  <ul style={styles.errorList}>
                    {result.not_found.map((username, i) => (
                      <li key={i}><strong>"{username}"</strong> does not exist</li>
                    ))}
                  </ul>
                </div>
              )}

              {(!result.moved || result.moved.length === 0) && (
                <div style={styles.warningBox}>
                  <p>No users were moved.</p>
                </div>
              )}
            </>
          ) : (
            <div style={styles.errorBox}>
              <strong>Error:</strong> {result.error}
            </div>
          )}
        </div>
      )}

      <hr style={styles.divider} />

      <div style={styles.roomList}>
        <p style={styles.quip}>{quip}</p>
        <p>Visit room:</p>
        <ul>
          <li><a href="/title/Go%20Outside" style={styles.roomLink}>outside</a></li>
          {rooms.map(room => (
            <li key={room.node_id}>
              <a href={`/title/${encodeURIComponent(room.title)}`} style={styles.roomLink}>
                {room.title}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  description: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  form: {
    marginBottom: '20px'
  },
  formRow: {
    display: 'flex',
    marginBottom: '15px'
  },
  labelColumn: {
    width: '150px',
    paddingRight: '15px',
    textAlign: 'right'
  },
  inputColumn: {
    flex: 1
  },
  label: {
    fontWeight: 'bold',
    display: 'block',
    marginBottom: '5px'
  },
  hint: {
    fontSize: '13px',
    color: '#507898',
    fontStyle: 'italic',
    margin: '5px 0'
  },
  textarea: {
    width: '100%',
    padding: '10px',
    fontSize: '14px',
    fontFamily: 'inherit',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    resize: 'vertical',
    boxSizing: 'border-box'
  },
  select: {
    width: '100%',
    padding: '10px',
    fontSize: '14px',
    fontFamily: 'inherit',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    boxSizing: 'border-box',
    background: 'white'
  },
  button: {
    padding: '10px 20px',
    fontSize: '16px',
    fontWeight: 'bold',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer'
  },
  buttonDisabled: {
    background: '#999',
    cursor: 'not-allowed'
  },
  result: {
    marginTop: '20px'
  },
  successBox: {
    padding: '15px',
    background: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  warningBox: {
    padding: '15px',
    background: '#fff3e0',
    border: '1px solid #ff9800',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  errorBox: {
    padding: '15px',
    background: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px'
  },
  error: {
    padding: '20px',
    background: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    textAlign: 'center'
  },
  resultHeading: {
    margin: '0 0 10px 0',
    fontSize: '14px',
    color: '#38495e'
  },
  userList: {
    margin: 0,
    paddingLeft: '20px'
  },
  errorList: {
    margin: 0,
    paddingLeft: '20px',
    color: '#c00000'
  },
  userLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  divider: {
    margin: '30px 0',
    border: 'none',
    borderTop: '1px solid #dee2e6'
  },
  roomList: {
    marginTop: '20px'
  },
  quip: {
    textAlign: 'center',
    fontStyle: 'italic',
    color: '#507898',
    marginBottom: '15px'
  },
  roomLink: {
    color: '#4060b0',
    textDecoration: 'none'
  }
};

export default E2Bouncer;

import React, { useState } from 'react';

/**
 * CreateRoom - Allows users to create new chat rooms
 *
 * Requires a minimum level, admin status, or chanop privileges.
 * Uses the /api/chatroom/create_room endpoint.
 */
const CreateRoom = ({ data, e2 }) => {
  const {
    can_create = false,
    is_suspended = false,
    required_level = 0,
    user_level = 0
  } = data;

  const [roomName, setRoomName] = useState('');
  const [description, setDescription] = useState('');
  const [creating, setCreating] = useState(false);
  const [result, setResult] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!roomName.trim()) {
      setResult({
        success: false,
        error: 'Please enter a room name'
      });
      return;
    }

    if (roomName.trim().length > 80) {
      setResult({
        success: false,
        error: 'Room name must be 80 characters or less'
      });
      return;
    }

    setCreating(true);
    setResult(null);

    try {
      const response = await fetch('/api/chatroom/create_room', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          room_title: roomName.trim(),
          room_doctext: description.trim()
        })
      });

      const json = await response.json();
      setResult(json);

      // Clear form on success
      if (json.success) {
        setRoomName('');
        setDescription('');

        // Update global e2 state if otherUsersData is returned
        if (json.otherUsersData && e2?.updateOtherUsersData) {
          e2.updateOtherUsersData(json.otherUsersData);
        }
      }
    } catch (err) {
      setResult({
        success: false,
        error: 'Failed to create room: ' + err.message
      });
    } finally {
      setCreating(false);
    }
  };

  // Suspended from creating rooms
  if (is_suspended) {
    return (
      <div style={styles.container}>
        <div style={styles.warning}>
          <h2 style={styles.warningHeading}>Suspended</h2>
          <p>You've been suspended from creating new rooms!</p>
        </div>
      </div>
    );
  }

  // Permission denied - level too low
  if (!can_create) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p><em>Too young, my friend.</em></p>
          <p>
            You need to reach level {required_level} to create rooms.
            Your current level is {user_level}.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.description}>
        <p>
          Create a new chat room for the E2 community.
          Choose a descriptive name and optionally add a description
          to let people know what it's about.
        </p>
      </div>

      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <label style={styles.label}>Room name:</label>
          <input
            type="text"
            style={styles.textInput}
            value={roomName}
            onChange={(e) => setRoomName(e.target.value)}
            maxLength={80}
            placeholder="Enter room name..."
            disabled={creating}
          />
          <div style={styles.charCount}>
            {roomName.length}/80
          </div>
        </div>

        <div style={styles.formRow}>
          <label style={styles.label}>Description (optional):</label>
          <textarea
            style={styles.textarea}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={5}
            placeholder="A few words about this room..."
            disabled={creating}
          />
        </div>

        <div style={styles.formRow}>
          <button
            type="submit"
            style={{
              ...styles.button,
              ...(creating ? styles.buttonDisabled : {})
            }}
            disabled={creating}
          >
            {creating ? 'Creating...' : 'Create Room'}
          </button>
        </div>
      </form>

      {result && (
        <div style={styles.result}>
          {result.success ? (
            <div style={styles.successBox}>
              <h4 style={styles.resultHeading}>Room Created!</h4>
              <p>
                Your room <strong>{result.room_title}</strong> has been created
                and you've been moved there.
              </p>
              <p>
                <a
                  href={`/title/${encodeURIComponent(result.room_title)}`}
                  style={styles.roomLink}
                >
                  Visit {result.room_title}
                </a>
              </p>
            </div>
          ) : (
            <div style={styles.errorBox}>
              <strong>Error:</strong> {result.error}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '600px',
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
    marginBottom: '15px'
  },
  label: {
    fontWeight: 'bold',
    display: 'block',
    marginBottom: '8px'
  },
  textInput: {
    width: '100%',
    padding: '10px',
    fontSize: '16px',
    fontFamily: 'inherit',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    boxSizing: 'border-box'
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
  charCount: {
    fontSize: '12px',
    color: '#507898',
    textAlign: 'right',
    marginTop: '5px'
  },
  button: {
    padding: '12px 24px',
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
    borderRadius: '4px'
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
  warning: {
    padding: '20px',
    background: '#fff3e0',
    border: '1px solid #ff9800',
    borderRadius: '4px',
    textAlign: 'center'
  },
  warningHeading: {
    margin: '0 0 10px 0',
    color: '#e65100'
  },
  resultHeading: {
    margin: '0 0 10px 0',
    fontSize: '16px',
    color: '#2e7d32'
  },
  roomLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: 'bold'
  }
};

export default CreateRoom;

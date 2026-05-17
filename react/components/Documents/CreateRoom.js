import React, { useState } from 'react';

/**
 * CreateRoom - Allows users to create new chat rooms
 * Styles in CSS: .create-room__*
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
      <div className="create-room">
        <div className="create-room__warning">
          <h2 className="create-room__warning-heading">Suspended</h2>
          <p>You've been suspended from creating new rooms!</p>
        </div>
      </div>
    );
  }

  // Permission denied - level too low
  if (!can_create) {
    return (
      <div className="create-room">
        <div className="create-room__error">
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
    <div className="create-room">
      <div className="create-room__description">
        <p>
          Create a new chat room for the E2 community.
          Choose a descriptive name and optionally add a description
          to let people know what it's about.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="create-room__form">
        <div className="create-room__form-row">
          <label className="create-room__label">Room name:</label>
          <input
            type="text"
            className="create-room__text-input"
            value={roomName}
            onChange={(e) => setRoomName(e.target.value)}
            maxLength={80}
            placeholder="Enter room name..."
            disabled={creating}
          />
          <div className="create-room__char-count">
            {roomName.length}/80
          </div>
        </div>

        <div className="create-room__form-row">
          <label className="create-room__label">Description (optional):</label>
          <textarea
            className="create-room__textarea"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={5}
            placeholder="A few words about this room..."
            disabled={creating}
          />
        </div>

        <div className="create-room__form-row">
          <button
            type="submit"
            className={`create-room__button${creating ? ' create-room__button--disabled' : ''}`}
            disabled={creating}
          >
            {creating ? 'Creating...' : 'Create Room'}
          </button>
        </div>
      </form>

      {result && (
        <div className="create-room__result">
          {result.success ? (
            <div className="create-room__success-box">
              <h4 className="create-room__result-heading">Room Created!</h4>
              <p>
                Your room <strong>{result.room_title}</strong> has been created
                and you've been moved there.
              </p>
              <p>
                <a
                  href={`/title/${encodeURIComponent(result.room_title)}`}
                  className="create-room__room-link"
                >
                  Visit {result.room_title}
                </a>
              </p>
            </div>
          ) : (
            <div className="create-room__error-box">
              <strong>Error:</strong> {result.error}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default CreateRoom;

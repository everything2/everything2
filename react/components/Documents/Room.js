import React, { useState } from 'react';
import { renderE2Content } from '../Editor/E2HtmlSanitizer';

/**
 * Room - Chat room entry/display page
 * Styles in CSS: .room__*
 */
export default function Room({ data }) {
  const { room, is_admin, entered, go_outside_id } = data;
  const [roomLocked, setRoomLocked] = useState(room.roomlocked ? 1 : 0);

  // Admin lock/unlock -> POST /api/chatroom/lock_room (canEnterRoom enforces it).
  // Replaces the legacy ?roomlocked= page-reload link.
  const toggleLock = async () => {
    const next = roomLocked ? 0 : 1;
    try {
      const res = await fetch('/api/chatroom/lock_room', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ room_id: room.node_id, locked: next }),
      });
      if (res.ok) {
        const d = await res.json();
        setRoomLocked(d.roomlocked ? 1 : 0);
      }
    } catch (e) {
      // leave state unchanged on failure
    }
  };

  // Get sanitized HTML for doctext
  const getRenderedDoctext = () => {
    if (!room.doctext) return '';
    const { html } = renderE2Content(room.doctext);
    return html;
  };

  return (
    <div className="room">
      {/* Admin lock/unlock toggle */}
      {is_admin === 1 && (
        <div className="room__admin-controls">
          <button
            type="button"
            onClick={toggleLock}
            className="room__lock-link"
          >
            {roomLocked ? 'unlock' : 'lock'}
          </button>
        </div>
      )}

      {/* Entry status message */}
      <p className="room__status-message">
        {entered ? (
          <>You walk into {room.title}</>
        ) : (
          <>You cannot go into {room.title}, I&apos;m sorry.</>
        )}
      </p>

      {/* Room description */}
      {room.doctext && (
        <div
          className="room__description"
          dangerouslySetInnerHTML={{ __html: getRenderedDoctext() }}
        />
      )}

      {/* Go outside link */}
      {go_outside_id > 0 && (
        <p className="room__go-outside">
          (<a href={`/?node_id=${go_outside_id}`}>go outside</a>)
        </p>
      )}
    </div>
  );
}

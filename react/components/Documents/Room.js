import React from 'react';
import { renderE2Content } from '../Editor/E2HtmlSanitizer';

/**
 * Room - Chat room entry/display page
 * Styles in CSS: .room__*
 */
export default function Room({ data }) {
  const { room, is_admin, entered, go_outside_id } = data;

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
          <a
            href={`/?node_id=${room.node_id}&roomlocked=${room.roomlocked ? 0 : 1}`}
            className="room__lock-link"
          >
            {room.roomlocked ? 'unlock' : 'lock'}
          </a>
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

import React from 'react';
import { renderE2Content } from '../Editor/E2HtmlSanitizer';

export default function Room({ data }) {
  const { room, is_admin, entered, go_outside_id } = data;

  // Get sanitized HTML for doctext
  const getRenderedDoctext = () => {
    if (!room.doctext) return '';
    const { html } = renderE2Content(room.doctext);
    return html;
  };

  return (
    <div style={styles.container}>
      {/* Admin lock/unlock toggle */}
      {is_admin === 1 && (
        <div style={styles.adminControls}>
          <a
            href={`/?node_id=${room.node_id}&roomlocked=${room.roomlocked ? 0 : 1}`}
            style={styles.lockLink}
          >
            {room.roomlocked ? 'unlock' : 'lock'}
          </a>
        </div>
      )}

      {/* Entry status message */}
      <p style={styles.statusMessage}>
        {entered ? (
          <>You walk into {room.title}</>
        ) : (
          <>You cannot go into {room.title}, I&apos;m sorry.</>
        )}
      </p>

      {/* Room description */}
      {room.doctext && (
        <div
          style={styles.description}
          dangerouslySetInnerHTML={{ __html: getRenderedDoctext() }}
        />
      )}

      {/* Go outside link */}
      {go_outside_id > 0 && (
        <p style={styles.goOutside}>
          (<a href={`/?node_id=${go_outside_id}`}>go outside</a>)
        </p>
      )}
    </div>
  );
}

const styles = {
  container: {
    padding: '20px',
    maxWidth: '800px',
    margin: '0 auto',
  },
  adminControls: {
    marginBottom: '10px',
  },
  lockLink: {
    fontSize: '12px',
    fontStyle: 'italic',
    color: '#507898',
  },
  statusMessage: {
    fontSize: '16px',
    marginBottom: '20px',
  },
  description: {
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  goOutside: {
    textAlign: 'right',
    marginTop: '20px',
  },
};

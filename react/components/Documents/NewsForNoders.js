import React, { useState } from 'react';

/**
 * News for Noders - Displays announcements from the News usergroup
 *
 * Shows weblog entries with title, author, date, and content.
 * Supports pagination for viewing older/newer entries.
 * Admins can remove entries via a confirmation modal.
 */
const NewsForNoders = ({ data, e2 }) => {
  const {
    entries: initialEntries = [],
    weblog_id = 0,
    can_remove = false,
    has_older = false,
    has_newer = false,
    next_older = 0,
    next_newer = 0,
    error = null
  } = data;

  const [entries, setEntries] = useState(initialEntries);
  const [confirmModal, setConfirmModal] = useState(null);
  const [removing, setRemoving] = useState(false);

  const currentNodeId = e2?.node_id || data.node_id;

  const handleRemoveClick = (entry) => {
    setConfirmModal(entry);
  };

  const handleConfirmRemove = async () => {
    if (!confirmModal || removing) return;

    setRemoving(true);
    try {
      const response = await fetch(`/api/weblog/${weblog_id}/${confirmModal.node_id}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      const result = await response.json();

      if (result.success) {
        // Remove the entry from the local state
        setEntries(entries.filter(e => e.node_id !== confirmModal.node_id));
        setConfirmModal(null);
      } else {
        alert('Failed to remove entry: ' + (result.error || 'Unknown error'));
      }
    } catch (err) {
      alert('Failed to remove entry: ' + err.message);
    } finally {
      setRemoving(false);
    }
  };

  const handleCancelRemove = () => {
    setConfirmModal(null);
  };

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <strong>Error:</strong> {error}
        </div>
      </div>
    );
  }

  if (entries.length === 0) {
    return (
      <div style={styles.container}>
        <p style={styles.empty}>No news entries found.</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.weblog}>
        {entries.map((entry, index) => (
          <div key={entry.node_id || index} style={styles.item}>
            <div style={styles.header}>
              <div style={styles.headerTop}>
                <a
                  href={`/node/document/${encodeURIComponent(entry.title)}`}
                  style={styles.title}
                >
                  {entry.title}
                </a>
                {Boolean(can_remove) && (
                  <button
                    onClick={() => handleRemoveClick(entry)}
                    style={styles.removeButton}
                    title="Remove from weblog"
                    onMouseOver={e => {
                      e.target.style.background = '#fff0f0';
                      e.target.style.borderColor = '#dc3545';
                      e.target.style.color = '#dc3545';
                    }}
                    onMouseOut={e => {
                      e.target.style.background = '#f8f9f9';
                      e.target.style.borderColor = '#dee2e6';
                      e.target.style.color = '#888888';
                    }}
                  >
                    remove
                  </button>
                )}
              </div>
              <cite style={styles.byline}>
                by{' '}
                <a
                  href={`/user/${encodeURIComponent(entry.author)}`}
                  style={styles.authorLink}
                >
                  {entry.author}
                </a>
              </cite>
              <span style={styles.date}>
                {formatDate(entry.linkedtime)}
              </span>
            </div>
            <div
              style={styles.content}
              dangerouslySetInnerHTML={{ __html: entry.content }}
            />
          </div>
        ))}
      </div>

      <div style={styles.footer}>
        {Boolean(has_newer || has_older) && (
          <div style={styles.moreLink}>
            {Boolean(has_newer) && (
              <a
                href={`/node/${currentNodeId}?nextweblog=${next_newer}`}
                style={styles.navLink}
              >
                &larr; newer
              </a>
            )}
            {Boolean(has_newer && has_older) && <span style={styles.separator}> | </span>}
            {Boolean(has_older) && (
              <a
                href={`/node/${currentNodeId}?nextweblog=${next_older}`}
                style={styles.navLink}
              >
                older &rarr;
              </a>
            )}
          </div>
        )}
        <p style={styles.faqLink}>
          <a href="/title/Everything+FAQ" style={styles.link}>
            Everything FAQ
          </a>
        </p>
      </div>

      {/* Confirmation Modal */}
      {confirmModal && (
        <div style={styles.modalOverlay} onClick={handleCancelRemove}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Remove Entry</h3>
            <p style={styles.modalText}>
              Are you sure you want to remove &ldquo;{confirmModal.title}&rdquo; from this weblog?
            </p>
            <p style={styles.modalNote}>
              This will not delete the document, just remove it from the weblog.
            </p>
            <div style={styles.modalButtons}>
              <button
                onClick={handleCancelRemove}
                style={styles.cancelButton}
                disabled={removing}
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmRemove}
                style={styles.confirmButton}
                disabled={removing}
              >
                {removing ? 'Removing...' : 'Remove'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

/**
 * Format a MySQL datetime string for display
 */
function formatDate(dateStr) {
  if (!dateStr) return '';

  try {
    // MySQL datetime format: "2025-12-06 00:22:26"
    const date = new Date(dateStr.replace(' ', 'T') + 'Z');
    if (isNaN(date.getTime())) return dateStr;

    const options = {
      weekday: 'short',
      month: 'short',
      day: '2-digit',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    };

    return date.toLocaleString('en-US', options).replace(',', '');
  } catch (e) {
    return dateStr;
  }
}

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '10px 20px'
  },
  weblog: {
    marginBottom: '20px'
  },
  item: {
    marginBottom: '24px',
    paddingBottom: '16px'
  },
  header: {
    marginBottom: '10px',
    padding: '8px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px'
  },
  headerTop: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: '10px'
  },
  title: {
    display: 'block',
    fontWeight: 'bold',
    color: '#4060b0',
    textDecoration: 'none',
    marginBottom: '4px',
    flex: 1
  },
  removeButton: {
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    color: '#888888',
    fontSize: '11px',
    cursor: 'pointer',
    padding: '3px 8px',
    textDecoration: 'none',
    transition: 'all 0.15s ease',
    flexShrink: 0
  },
  byline: {
    display: 'block',
    color: '#507898',
    fontStyle: 'normal'
  },
  authorLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  date: {
    display: 'block',
    color: '#888888',
    marginTop: '4px'
  },
  content: {
    padding: '0 8px'
  },
  moreLink: {
    textAlign: 'center',
    padding: '15px 0',
    borderTop: '1px solid #dee2e6',
    marginTop: '10px'
  },
  navLink: {
    color: '#4060b0',
    textDecoration: 'none',
    padding: '5px 10px'
  },
  separator: {
    color: '#888888'
  },
  footer: {
    textAlign: 'center',
    marginTop: '30px',
    paddingTop: '20px',
    borderTop: '1px solid #dee2e6'
  },
  faqLink: {
    margin: 0
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  error: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px'
  },
  empty: {
    textAlign: 'center',
    color: '#888888',
    fontStyle: 'italic',
    padding: '40px 0'
  },
  // Modal styles
  modalOverlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000
  },
  modal: {
    backgroundColor: '#ffffff',
    borderRadius: '8px',
    padding: '24px',
    maxWidth: '400px',
    width: '90%',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)'
  },
  modalTitle: {
    margin: '0 0 16px 0',
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e'
  },
  modalText: {
    margin: '0 0 8px 0',
    fontSize: '14px',
    color: '#111111'
  },
  modalNote: {
    margin: '0 0 20px 0',
    fontSize: '12px',
    color: '#888888',
    fontStyle: 'italic'
  },
  modalButtons: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '10px'
  },
  cancelButton: {
    padding: '8px 16px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    backgroundColor: '#ffffff',
    color: '#38495e',
    cursor: 'pointer',
    fontSize: '14px'
  },
  confirmButton: {
    padding: '8px 16px',
    border: 'none',
    borderRadius: '4px',
    backgroundColor: '#dc3545',
    color: '#ffffff',
    cursor: 'pointer',
    fontSize: '14px'
  }
};

export default NewsForNoders;

import React, { useState } from 'react';

/**
 * News for Noders - Displays announcements from the News usergroup
 * Styles in CSS: .news-for-noders__*
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
      <div className="news-for-noders">
        <div className="news-for-noders__error">
          <strong>Error:</strong> {error}
        </div>
      </div>
    );
  }

  if (entries.length === 0) {
    return (
      <div className="news-for-noders">
        <p className="news-for-noders__empty">No news entries found.</p>
      </div>
    );
  }

  return (
    <div className="news-for-noders">
      <div className="news-for-noders__weblog">
        {entries.map((entry, index) => (
          <div key={entry.node_id || index} className="news-for-noders__entry">
            <div className="news-for-noders__entry-header">
              <div className="news-for-noders__entry-top">
                <a
                  href={`/node/document/${encodeURIComponent(entry.title)}`}
                  className="news-for-noders__entry-title"
                >
                  {entry.title}
                </a>
                {Boolean(can_remove) && (
                  <button
                    onClick={() => handleRemoveClick(entry)}
                    className="news-for-noders__remove-button"
                    title="Remove from weblog"
                  >
                    remove
                  </button>
                )}
              </div>
              <cite className="news-for-noders__byline">
                by{' '}
                <a
                  href={`/user/${encodeURIComponent(entry.author)}`}
                  className="news-for-noders__author-link"
                >
                  {entry.author}
                </a>
              </cite>
              <span className="news-for-noders__date">
                {formatDate(entry.linkedtime)}
              </span>
            </div>
            <div
              className="news-for-noders__content"
              dangerouslySetInnerHTML={{ __html: entry.content }}
            />
          </div>
        ))}
      </div>

      <div className="news-for-noders__footer">
        {Boolean(has_newer || has_older) && (
          <div className="news-for-noders__nav">
            {Boolean(has_newer) && (
              <a
                href={`/node/${currentNodeId}?nextweblog=${next_newer}`}
                className="news-for-noders__nav-link"
              >
                &larr; newer
              </a>
            )}
            {Boolean(has_newer && has_older) && <span className="news-for-noders__separator"> | </span>}
            {Boolean(has_older) && (
              <a
                href={`/node/${currentNodeId}?nextweblog=${next_older}`}
                className="news-for-noders__nav-link"
              >
                older &rarr;
              </a>
            )}
          </div>
        )}
        <p className="news-for-noders__faq">
          <a href="/title/Everything+FAQ" className="news-for-noders__link">
            Everything FAQ
          </a>
        </p>
      </div>

      {/* Confirmation Modal */}
      {confirmModal && (
        <div className="news-for-noders__modal-overlay" onClick={handleCancelRemove}>
          <div className="news-for-noders__modal" onClick={e => e.stopPropagation()}>
            <h3 className="news-for-noders__modal-title">Remove Entry</h3>
            <p className="news-for-noders__modal-text">
              Are you sure you want to remove &ldquo;{confirmModal.title}&rdquo; from this weblog?
            </p>
            <p className="news-for-noders__modal-note">
              This will not delete the document, just remove it from the weblog.
            </p>
            <div className="news-for-noders__modal-buttons">
              <button
                onClick={handleCancelRemove}
                className="news-for-noders__modal-cancel"
                disabled={removing}
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmRemove}
                className="news-for-noders__modal-confirm"
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

export default NewsForNoders;

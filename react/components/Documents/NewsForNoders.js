import React, { useState, useEffect, useCallback } from 'react';
import { formatDateTime } from '../../utils/dateFormat';

/**
 * News for Noders - Displays announcements from the News usergroup.
 * Styles in CSS: .news-for-noders__*
 *
 * Fully client-resolved (#4543): the Page is a pure gate. Fetches GET /api/news_for_noders on mount,
 * reading nextweblog off the URL; the older/newer nav refetches IN PLACE (no reload) via
 * history.pushState. Admin/owner removal still DELETEs /api/weblog/:weblog_id/:node_id.
 */
const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search);
  return { nextweblog: qs.get('nextweblog') || '' };
};

const NewsForNoders = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [entries, setEntries] = useState([]);
  const [confirmModal, setConfirmModal] = useState(null);
  const [removing, setRemoving] = useState(false);

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams();
    if (params.nextweblog) api.set('nextweblog', String(params.nextweblog));

    if (push) {
      const url = new URL(window.location.href);
      if (params.nextweblog) url.searchParams.set('nextweblog', String(params.nextweblog));
      else url.searchParams.delete('nextweblog');
      window.history.pushState({}, '', url.pathname + url.search);
    }

    setLoading(true);
    return fetch(`/api/news_for_noders?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setEntries(j.entries || []); setLoading(false); })
      .catch(() => setLoading(false));
  }, []);

  useEffect(() => {
    load(paramsFromUrl());
    const onPop = () => load(paramsFromUrl());
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, [load]);

  const { weblog_id = 0, can_remove = false, has_older = false, has_newer = false, next_older = 0, next_newer = 0, state } = data || {};

  const handleConfirmRemove = async () => {
    if (!confirmModal || removing) return;
    setRemoving(true);
    try {
      const response = await fetch(`/api/weblog/${weblog_id}/${confirmModal.node_id}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' }
      });
      const result = await response.json();
      if (result.success) {
        setEntries(entries.filter((e) => e.node_id !== confirmModal.node_id));
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

  const handleCancelRemove = () => setConfirmModal(null);

  if (loading && !data) {
    return <div className="news-for-noders"><p>Loading...</p></div>;
  }

  if (state === 'no_news_group') {
    return (
      <div className="news-for-noders">
        <div className="news-for-noders__error"><strong>Error:</strong> News usergroup not found</div>
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
                <a href={`/node/document/${encodeURIComponent(entry.title)}`} className="news-for-noders__entry-title">
                  {entry.title}
                </a>
                {Boolean(can_remove) && (
                  <button onClick={() => setConfirmModal(entry)} className="news-for-noders__remove-button" title="Remove from weblog">
                    remove
                  </button>
                )}
              </div>
              <cite className="news-for-noders__byline">
                by{' '}
                <a href={`/user/${encodeURIComponent(entry.author)}`} className="news-for-noders__author-link">
                  {entry.author}
                </a>
              </cite>
              <span className="news-for-noders__date">{formatDate(entry.linkedtime)}</span>
            </div>
            <div className="news-for-noders__content" dangerouslySetInnerHTML={{ __html: entry.content }} />
          </div>
        ))}
      </div>

      <div className="news-for-noders__footer">
        {Boolean(has_newer || has_older) && (
          <div className="news-for-noders__nav">
            {Boolean(has_newer) && (
              <a href={`?nextweblog=${next_newer}`} onClick={(e) => { e.preventDefault(); load({ nextweblog: next_newer }, { push: true }); }} className="news-for-noders__nav-link">
                &larr; newer
              </a>
            )}
            {Boolean(has_newer && has_older) && <span className="news-for-noders__separator"> | </span>}
            {Boolean(has_older) && (
              <a href={`?nextweblog=${next_older}`} onClick={(e) => { e.preventDefault(); load({ nextweblog: next_older }, { push: true }); }} className="news-for-noders__nav-link">
                older &rarr;
              </a>
            )}
          </div>
        )}
        <p className="news-for-noders__faq">
          <a href="/title/Everything+FAQ" className="news-for-noders__link">Everything FAQ</a>
        </p>
      </div>

      {/* Confirmation Modal */}
      {confirmModal && (
        <div className="news-for-noders__modal-overlay" onClick={handleCancelRemove}>
          <div className="news-for-noders__modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="news-for-noders__modal-title">Remove Entry</h3>
            <p className="news-for-noders__modal-text">
              Are you sure you want to remove &ldquo;{confirmModal.title}&rdquo; from this weblog?
            </p>
            <p className="news-for-noders__modal-note">
              This will not delete the document, just remove it from the weblog.
            </p>
            <div className="news-for-noders__modal-buttons">
              <button onClick={handleCancelRemove} className="news-for-noders__modal-cancel" disabled={removing}>Cancel</button>
              <button onClick={handleConfirmRemove} className="news-for-noders__modal-confirm" disabled={removing}>
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
 * Format a MySQL datetime string for display.
 * Verbose news-list layout: "Mon Dec 06 2025 00:22:26".
 */
function formatDate(dateStr) {
  return formatDateTime(dateStr, {
    weekday: 'short',
    month: 'short',
    day: '2-digit',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  })?.replace(',', '') ?? (dateStr ?? '');
}

export default NewsForNoders;

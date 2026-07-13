import React, { useState, useEffect, useCallback } from 'react';
import LinkNode from '../LinkNode';

/**
 * Editor Endorsements - Shows nodes endorsed (cooled) by editors.
 * Styles in CSS: .editor-endorsements__*
 *
 * Fully client-resolved (#4528): the Page is a pure gate. This fetches GET /api/editor_endorsements
 * (which lists the editors + the selected editor's endorsements) on mount, and the picker refetches
 * IN PLACE -- no full page reload. The URL is kept in sync via history.pushState so a selected
 * editor is shareable and back/forward work (popstate refetches).
 */
const editorFromUrl = () =>
  (new URLSearchParams(window.location.search).get('editor') || '').replace(/[^\d]/g, '');

const EditorEndorsements = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedEditorId, setSelectedEditorId] = useState(editorFromUrl);

  // Fetch the endorsements for an editor id (empty = just the picker) and update
  // state. When `push` is set, reflect the selection in the URL (pushState) so it's
  // shareable and back/forward work -- without reloading the page.
  const load = useCallback((editorId, { push } = {}) => {
    const params = new URLSearchParams();
    if (editorId) params.set('editor', editorId);

    if (push) {
      const url = new URL(window.location.href);
      if (editorId) url.searchParams.set('editor', editorId);
      else url.searchParams.delete('editor');
      window.history.pushState({}, '', url.pathname + url.search);
    }

    setLoading(true);
    return fetch(`/api/editor_endorsements?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false); })
      .catch(() => setLoading(false));
  }, []);

  useEffect(() => {
    load(editorFromUrl());
    const onPop = () => {
      const id = editorFromUrl();
      setSelectedEditorId(id);
      load(id);
    };
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, [load]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (selectedEditorId) {
      load(selectedEditorId, { push: true });
    }
  };

  // First paint only: keep the current view during later refetches to avoid a flash.
  if (loading && !data) {
    return <div className="editor-endorsements"><p>Loading...</p></div>;
  }

  const { editors = [], selected_editor, endorsements = [] } = data || {};

  return (
    <div className="editor-endorsements">
      {/* Editor Selection Form */}
      <div className="editor-endorsements__form-section">
        <form onSubmit={handleSubmit} className="editor-endorsements__form">
          <label className="editor-endorsements__label">
            Select your <strong>favorite</strong> editor to see what they've{' '}
            <LinkNode type="superdoc" title="Page of Cool" display="endorsed" />:
          </label>
          <div className="editor-endorsements__form-row">
            <select
              name="editor"
              value={selectedEditorId}
              onChange={(e) => setSelectedEditorId(e.target.value)}
              className="editor-endorsements__select"
            >
              <option value="">-- Choose an editor --</option>
              {editors.map((editor) => (
                <option key={editor.node_id} value={editor.node_id}>
                  {editor.title}
                </option>
              ))}
            </select>
            <button
              type="submit"
              disabled={!selectedEditorId}
              className={`editor-endorsements__button ${!selectedEditorId ? 'editor-endorsements__button--disabled' : ''}`}
            >
              Show Endorsements
            </button>
          </div>
        </form>
      </div>

      {/* Endorsements Results */}
      {selected_editor && (
        <div className="editor-endorsements__results">
          <h2 className="editor-endorsements__results-title">
            <LinkNode type="user" title={selected_editor.title} /> has endorsed{' '}
            {endorsements.length} node{endorsements.length !== 1 ? 's' : ''}
          </h2>

          {endorsements.length > 0 ? (
            <ul className="editor-endorsements__list">
              {endorsements.map((endorsement) => (
                <li key={endorsement.node_id} className="editor-endorsements__list-item">
                  <LinkNode type={endorsement.type} title={endorsement.title} />
                  {endorsement.type === 'e2node' && endorsement.writeup_count !== undefined && (
                    <span className="editor-endorsements__meta">
                      {' '}
                      - {endorsement.writeup_count} writeup
                      {endorsement.writeup_count === 0 || endorsement.writeup_count > 1 ? 's' : ''}
                    </span>
                  )}
                  {endorsement.type !== 'e2node' && (
                    <span className="editor-endorsements__meta"> - ({endorsement.type})</span>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <p className="editor-endorsements__empty">No endorsements found for this editor.</p>
          )}
        </div>
      )}
    </div>
  );
};

export default EditorEndorsements;

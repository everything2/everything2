import React, { useState } from 'react';
import LinkNode from '../LinkNode';

/**
 * Editor Endorsements - Shows nodes endorsed (cooled) by editors
 * Styles in CSS: .editor-endorsements__*
 *
 * Allows users to select an editor and view all the nodes they've
 * endorsed via the Page of Cool system. Editors include gods,
 * Content Editors, and exeds.
 */
const EditorEndorsements = ({ data, e2 }) => {
  const { editors = [], selected_editor, endorsements = [] } = data;
  const [selectedEditorId, setSelectedEditorId] = useState(
    selected_editor ? selected_editor.node_id.toString() : ''
  );

  const handleSubmit = (e) => {
    e.preventDefault();
    if (selectedEditorId) {
      window.location.href = `/title/Editor+Endorsements?editor=${selectedEditorId}`;
    }
  };

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

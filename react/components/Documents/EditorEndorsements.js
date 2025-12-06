import React, { useState } from 'react';
import LinkNode from '../LinkNode';

/**
 * Editor Endorsements - Shows nodes endorsed (cooled) by editors
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
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <h1 style={styles.title}>Editor Endorsements</h1>
        <p style={styles.subtitle}>
          See what nodes your favorite editors have endorsed
        </p>
      </div>

      {/* Editor Selection Form */}
      <div style={styles.formSection}>
        <form onSubmit={handleSubmit} style={styles.form}>
          <label style={styles.label}>
            Select your <strong>favorite</strong> editor to see what they've{' '}
            <LinkNode type="superdoc" title="Page of Cool" display="endorsed" />:
          </label>
          <div style={styles.formRow}>
            <select
              name="editor"
              value={selectedEditorId}
              onChange={(e) => setSelectedEditorId(e.target.value)}
              style={styles.select}
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
              style={{
                ...styles.button,
                ...(selectedEditorId ? {} : styles.buttonDisabled)
              }}
            >
              Show Endorsements
            </button>
          </div>
        </form>
      </div>

      {/* Endorsements Results */}
      {selected_editor && (
        <div style={styles.results}>
          <h2 style={styles.resultsTitle}>
            <LinkNode type="user" title={selected_editor.title} /> has endorsed{' '}
            {endorsements.length} node{endorsements.length !== 1 ? 's' : ''}
          </h2>

          {endorsements.length > 0 ? (
            <ul style={styles.list}>
              {endorsements.map((endorsement) => (
                <li key={endorsement.node_id} style={styles.listItem}>
                  <LinkNode type={endorsement.type} title={endorsement.title} />
                  {endorsement.type === 'e2node' && endorsement.writeup_count !== undefined && (
                    <span style={styles.meta}>
                      {' '}
                      - {endorsement.writeup_count} writeup
                      {endorsement.writeup_count === 0 || endorsement.writeup_count > 1 ? 's' : ''}
                    </span>
                  )}
                  {endorsement.type !== 'e2node' && (
                    <span style={styles.meta}> - ({endorsement.type})</span>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <p style={styles.empty}>No endorsements found for this editor.</p>
          )}
        </div>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px'
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
    paddingBottom: '20px',
    borderBottom: '3px solid #38495e'
  },
  title: {
    fontSize: '32px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '8px'
  },
  subtitle: {
    fontSize: '16px',
    color: '#507898',
    margin: 0
  },
  formSection: {
    background: '#f8f9f9',
    border: '2px solid #38495e',
    borderRadius: '8px',
    padding: '24px',
    marginBottom: '32px'
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '16px'
  },
  label: {
    fontSize: '16px',
    color: '#111',
    lineHeight: '1.6'
  },
  formRow: {
    display: 'flex',
    gap: '12px',
    alignItems: 'center',
    flexWrap: 'wrap'
  },
  select: {
    flex: '1 1 300px',
    minWidth: '200px',
    padding: '10px 12px',
    fontSize: '15px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: 'white',
    color: '#111',
    cursor: 'pointer'
  },
  button: {
    padding: '10px 24px',
    fontSize: '15px',
    fontWeight: '600',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'background-color 0.2s'
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
    cursor: 'not-allowed'
  },
  results: {
    marginTop: '32px'
  },
  resultsTitle: {
    fontSize: '24px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '20px',
    paddingBottom: '12px',
    borderBottom: '2px solid #dee2e6'
  },
  list: {
    listStyle: 'none',
    padding: 0,
    margin: 0
  },
  listItem: {
    padding: '12px 16px',
    marginBottom: '8px',
    background: '#fff',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '15px',
    lineHeight: '1.6'
  },
  meta: {
    color: '#507898',
    fontSize: '14px'
  },
  empty: {
    textAlign: 'center',
    padding: '40px 20px',
    color: '#6c757d',
    fontSize: '15px',
    background: '#f8f9f9',
    borderRadius: '8px'
  }
};

export default EditorEndorsements;

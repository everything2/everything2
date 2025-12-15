import React, { useState } from 'react';

const INITIAL_DISPLAY_COUNT = 10;

const Findings = ({ data }) => {
  const { no_search_term, message, search_term, findings = [], lastnode_id, is_guest, has_excerpts } = data;

  const [searchValue, setSearchValue] = useState(search_term || '');
  const [soundex, setSoundex] = useState(false);
  const [matchAll, setMatchAll] = useState(false);
  const [showAll, setShowAll] = useState(false);

  // Determine which findings to display
  const displayedFindings = showAll ? findings : findings.slice(0, INITIAL_DISPLAY_COUNT);
  const hasMore = findings.length > INITIAL_DISPLAY_COUNT;

  if (no_search_term) {
    return (
      <div style={styles.container}>
        <p style={styles.message}>{message}</p>
        <p>
          <a href="/?node=Random%20Nodes">Visit Random Nodes</a>
        </p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <p style={styles.header}>
        Here's the stuff we found when you searched for "{search_term}"
      </p>

      <ul style={styles.findingsList}>
        {displayedFindings.map((finding) => (
          <li
            key={finding.node_id}
            className={finding.is_nodeshell ? 'nodeshell' : ''}
            style={finding.is_nodeshell ? styles.nodeshellItem : styles.normalItem}
          >
            <a href={`/?node_id=${finding.node_id}${is_guest ? '&lastnode_id=0' : `&lastnode_id=${lastnode_id}`}`}>
              {finding.title}
            </a>
            {finding.type !== 'e2node' && <span> ({finding.type})</span>}
            {finding.excerpt && (
              <p style={styles.excerpt}>{finding.excerpt}</p>
            )}
          </li>
        ))}
      </ul>

      {hasMore && !showAll && (
        <button
          onClick={() => setShowAll(true)}
          style={styles.showMoreButton}
        >
          Show {findings.length - INITIAL_DISPLAY_COUNT} more results
        </button>
      )}

      {findings.length === 0 && (
        <p style={styles.noResults}>No results found.</p>
      )}

      {/* Create new node form */}
      <div style={styles.createSection}>
        <p>Since we didn't find what you were looking for, you can search again, or create a new draft or e2node (page):</p>

        {/* Search again form */}
        <form method="get" action="/" style={styles.form}>
          <fieldset style={styles.fieldset}>
            <legend>Search again</legend>
            <input
              type="text"
              name="node"
              value={searchValue}
              onChange={(e) => setSearchValue(e.target.value)}
              size="50"
              maxLength="100"
              style={styles.textInput}
            />
            {' '}
            <input type="hidden" name="lastnode_id" value={lastnode_id} />
            <button type="submit" name="searchy" value="search" style={styles.button}>
              search
            </button>
            <br />
            <label style={styles.checkbox}>
              <input
                type="checkbox"
                name="soundex"
                value="1"
                checked={soundex}
                onChange={(e) => setSoundex(e.target.checked)}
              />
              {' '}Near Matches{' '}
            </label>
            <label style={styles.checkbox}>
              <input
                type="checkbox"
                name="match_all"
                value="1"
                checked={matchAll}
                onChange={(e) => setMatchAll(e.target.checked)}
              />
              {' '}Ignore Exact
            </label>
          </fieldset>
        </form>

        {/* Create new form */}
        <form method="get" action="/" style={styles.form}>
          <fieldset style={styles.fieldset}>
            <legend>Create new...</legend>
            <small>You can correct the spelling or capitalization here.</small>
            <br />
            <input
              type="text"
              name="node"
              defaultValue={search_term}
              size="50"
              maxLength="100"
              style={styles.textInput}
            />
            <input type="hidden" name="lastnode_id" value={lastnode_id} />
            <input type="hidden" name="op" value="new" />
            {' '}
            <button type="submit" name="type" value="draft" style={styles.button}>
              New draft
            </button>
            {' '}
            <button type="submit" name="type" value="e2node" style={styles.button}>
              New node
            </button>
          </fieldset>
        </form>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px'
  },
  message: {
    fontSize: '16px',
    color: '#507898',
    textAlign: 'center',
    padding: '40px 20px'
  },
  header: {
    fontSize: '16px',
    color: '#111111',
    marginBottom: '20px'
  },
  findingsList: {
    listStyleType: 'disc',
    paddingLeft: '20px',
    marginBottom: '30px',
    fontSize: '16px',
    lineHeight: '1.8'
  },
  normalItem: {
    color: '#111111'
  },
  nodeshellItem: {
    color: '#999999',
    fontStyle: 'italic'
  },
  excerpt: {
    fontSize: '14px',
    color: '#555555',
    margin: '4px 0 12px 0',
    lineHeight: '1.5',
    fontStyle: 'normal'
  },
  showMoreButton: {
    display: 'block',
    margin: '20px auto',
    padding: '10px 20px',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px'
  },
  noResults: {
    fontSize: '16px',
    color: '#507898',
    textAlign: 'center',
    padding: '20px'
  },
  createSection: {
    marginTop: '30px',
    borderTop: '1px solid #dee2e6',
    paddingTop: '20px'
  },
  form: {
    marginTop: '15px',
    marginBottom: '15px'
  },
  fieldset: {
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '15px',
    background: '#f8f9f9'
  },
  textInput: {
    padding: '6px 10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    marginTop: '10px',
    marginBottom: '10px'
  },
  button: {
    padding: '6px 12px',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px'
  },
  checkbox: {
    marginRight: '15px',
    fontSize: '14px'
  }
};

export default Findings;

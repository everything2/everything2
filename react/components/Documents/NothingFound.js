import React, { useState } from 'react';
import AdminCreateNodeLink from '../AdminCreateNodeLink';

const NothingFound = ({ data, user }) => {
  const {
    was_nuke,
    search_term,
    is_url,
    external_link,
    is_guest,
    is_editor,
    show_tin_opener,
    tinopener_active,
    tin_opener_message,
    existing_e2node,
    lastnode_id,
    best_entries = []
  } = data;

  const [searchValue, setSearchValue] = useState(search_term || '');
  const [createValue, setCreateValue] = useState(search_term ? search_term.replace(/^\s*https?:\/\//, '') : '');
  const [soundex, setSoundex] = useState(false);
  const [matchAll, setMatchAll] = useState(false);

  // Handle successful nuke
  if (was_nuke) {
    return (
      <div style={styles.container}>
        <p>Oh good, there's nothing there!</p>
        <p>(It looks like you nuked it.)</p>
      </div>
    );
  }

  // Handle no search term
  if (!search_term) {
    return (
      <div style={styles.container}>
        <p>Hmm... that's odd. There's nothing there!</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <p>Sorry, but nothing matching "{search_term}" was found.</p>

      {is_url && external_link && (
        <p style={styles.urlNote}>
          (this appears to be an external link:{' '}
          <a href={external_link} target="_blank" rel="noopener noreferrer">
            {external_link}
          </a>)
        </p>
      )}

      {show_tin_opener && !tinopener_active && (
        <p style={styles.smallNote}>
          <small>
            You could{' '}
            <a href={`${window.location.pathname}${window.location.search}&tinopener=1`}>
              use the godly tin-opener
            </a>{' '}
            to show a censored version of any draft that may be here, but only do that if you really need to.
          </small>
        </p>
      )}

      {show_tin_opener && tinopener_active && tin_opener_message && (
        <p style={styles.smallNote}>
          <small>({tin_opener_message})</small>
        </p>
      )}

      {/* Guest user message */}
      {is_guest ? (
        <>
          <p style={styles.guestMessage}>
            If you <a href="/?node=login">Log in</a> you could create a "{createValue}" node.
            If you don't already have an account, you can{' '}
            <a href="/?node=Sign%20Up">register here</a>.
          </p>

          {/* Best entries for guests */}
          {best_entries.length > 0 && (
            <div style={styles.bestEntriesSection}>
              <h3 style={styles.bestEntriesTitle}>
                We couldn't find what you're looking for, but here are some of our best entries from the past few months:
              </h3>
              <ul style={styles.bestEntriesList}>
                {best_entries.map((entry) => (
                  <li key={entry.writeup_id} style={styles.bestEntryItem}>
                    <a href={`/node/${entry.node_id}?lastnode_id=0`} style={styles.bestEntryLink}>
                      {entry.title}
                    </a>
                    {entry.author && (
                      <span style={styles.bestEntryAuthor}>
                        {' '}by{' '}
                        <a href={`/user/${encodeURIComponent(entry.author.title)}`}>
                          {entry.author.title}
                        </a>
                      </span>
                    )}
                    {entry.excerpt && (
                      <p style={styles.bestEntryExcerpt}>{entry.excerpt}</p>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </>
      ) : existing_e2node ? (
        <p>
          <a href={`/?node_id=${existing_e2node.node_id}`}>{existing_e2node.title}</a> already exists.
        </p>
      ) : (
        <>
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
                value={createValue}
                onChange={(e) => setCreateValue(e.target.value)}
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

          <AdminCreateNodeLink user={user} searchTerm={createValue} />

          {is_editor && (
            <p style={styles.editorNote}>
              If you wish to exercise your Editorial Power to create a document[nodetype], create a draft,
              click on the 'Advanced option(s)' button, and then use the nice shiny 'Publish as document'
              button provided for this purpose.
            </p>
          )}
        </>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  urlNote: {
    fontSize: '14px',
    color: '#507898',
    marginTop: '10px'
  },
  smallNote: {
    fontSize: '14px',
    color: '#507898'
  },
  guestMessage: {
    marginTop: '20px'
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
  },
  editorNote: {
    marginTop: '15px',
    fontSize: '14px',
    color: '#507898'
  },
  bestEntriesSection: {
    marginTop: '30px',
    paddingTop: '20px',
    borderTop: '1px solid #dee2e6'
  },
  bestEntriesTitle: {
    fontSize: '16px',
    fontWeight: 'normal',
    color: '#507898',
    marginBottom: '15px'
  },
  bestEntriesList: {
    listStyleType: 'none',
    padding: 0,
    margin: 0
  },
  bestEntryItem: {
    marginBottom: '16px',
    paddingBottom: '16px',
    borderBottom: '1px solid #eee'
  },
  bestEntryLink: {
    fontSize: '16px',
    fontWeight: '500',
    color: '#4060b0',
    textDecoration: 'none'
  },
  bestEntryAuthor: {
    fontSize: '14px',
    color: '#666'
  },
  bestEntryExcerpt: {
    fontSize: '14px',
    color: '#555',
    marginTop: '6px',
    marginBottom: 0,
    lineHeight: '1.5'
  }
};

export default NothingFound;

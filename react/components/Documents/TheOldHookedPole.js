import React from 'react'
import LinkNode from '../LinkNode'

/**
 * TheOldHookedPole - Editor tool for mass user account management.
 * Checks users for safety before deletion/locking.
 */
const TheOldHookedPole = ({ data }) => {
  const {
    is_editor,
    message,
    results,
    saved_users,
    show_form,
    node_id,
    prefill,
    polehash_nonce,
    polehash_seed
  } = data

  if (!is_editor) {
    return (
      <div style={styles.container}>
        <p>{message}</p>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      {results && results.length > 0 && (
        <div style={styles.resultsSection}>
          <h3 style={styles.subtitle}>The Doomed Performers</h3>
          <ul style={styles.resultsList}>
            {results.map((result, idx) => (
              <li key={idx} style={styles.resultItem}>
                {result.action === 'deleted' ? (
                  <span style={styles.deleted}>
                    Deleted {result.input} ({result.node_id}).
                  </span>
                ) : (
                  <>
                    {result.node_id ? (
                      <LinkNode nodeId={result.node_id} title={result.title || result.input} />
                    ) : (
                      <span>{result.input}</span>
                    )}
                    {result.reasons.length > 0 && (
                      <ul style={styles.reasonsList}>
                        {result.reasons.map((reason, ridx) => (
                          <li key={ridx} dangerouslySetInnerHTML={{ __html: reason }} />
                        ))}
                      </ul>
                    )}
                  </>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}

      {show_form && (
        <>
          <h3 style={styles.subtitle}>&ldquo;Off the stage with &apos;em!&rdquo;</h3>
          <p>
            A mass user deletion tool which provides basic checks for deletion.
          </p>
          <p>Copy and paste list of names of users to destroy.</p>

          <div style={styles.checksList}>
            <p>This does the following things:</p>
            <ul>
              <li>Checks to see if the user has ever logged in</li>
              <li>Checks if the user has any live writeups</li>
              <li>Checks if the user has any live e2nodes</li>
              <li>Deletes the user if it is safe</li>
              <li>Locks a user if deletion isn&apos;t safe</li>
            </ul>
          </div>

          <form method="post" style={styles.form}>
            <input type="hidden" name="node_id" value={node_id} />
            <input type="hidden" name="polehash_nonce" value={polehash_nonce} />
            <input type="hidden" name="polehash_seed" value={polehash_seed} />

            {saved_users && saved_users.length > 0 && (
              <fieldset style={styles.fieldset}>
                <legend>The users who were spared</legend>
                <textarea
                  name="ignored-saved"
                  defaultValue={saved_users.join('\n')}
                  style={styles.textarea}
                  readOnly
                />
              </fieldset>
            )}

            <fieldset style={styles.fieldset}>
              <legend>Inadequate Performers</legend>
              <textarea
                name="usernames"
                rows="10"
                cols="30"
                style={styles.textarea}
                placeholder="Enter usernames, one per line"
                defaultValue={prefill || ''}
              />
              <br /><br />
              <button type="submit" style={styles.button}>
                Get The Hook!
              </button>
            </fieldset>
          </form>
        </>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  subtitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '10px'
  },
  resultsSection: {
    marginBottom: '20px'
  },
  resultsList: {
    margin: '10px 0',
    paddingLeft: '20px'
  },
  resultItem: {
    marginBottom: '10px'
  },
  deleted: {
    color: '#c62828'
  },
  reasonsList: {
    marginTop: '5px',
    paddingLeft: '20px',
    fontSize: '12px'
  },
  checksList: {
    marginBottom: '20px'
  },
  form: {
    marginTop: '20px'
  },
  fieldset: {
    border: '1px solid #d3d3d3',
    padding: '15px',
    marginBottom: '15px',
    borderRadius: '4px'
  },
  textarea: {
    width: '100%',
    maxWidth: '400px',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontFamily: 'monospace'
  },
  button: {
    padding: '8px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  }
}

export default TheOldHookedPole

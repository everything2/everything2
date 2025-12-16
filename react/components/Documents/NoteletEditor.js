import React, { useState } from 'react'

/**
 * Notelet Editor - Manage user notelet content
 *
 * Provides notelet castrator and editor functionality.
 * Castrator comments out all JS, editor allows content editing with 2000 char limit.
 */
const NoteletEditor = ({ data, e2 }) => {
  const {
    notelet_raw: initialNoteletRaw = '',
    notelet_screened = '',
    char_count = 0,
    max_length = 2000,
    user_level = 0,
    notelet_enabled = false,
    keep_comments: initialKeepComments = false,
    success_message = '',
    error = ''
  } = data

  // Strip script tags on initial load to allow users to remove legacy scripts
  const stripScriptTags = (text) => {
    return text
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<script[^>]*>/gi, '')
      .replace(/<\/script>/gi, '')  // Also catch stray closing tags
  }

  const [noteletRaw, setNoteletRaw] = useState(stripScriptTags(initialNoteletRaw))
  const [keepComments, setKeepComments] = useState(initialKeepComments)
  const [showPreview, setShowPreview] = useState(true)

  // Show warning if script tags were stripped
  const hadScriptTags = initialNoteletRaw !== stripScriptTags(initialNoteletRaw)

  const currentLength = noteletRaw.length
  const screenedLength = notelet_screened.length

  return (
    <div style={styles.container}>
      {/* Notelet Castrator Section */}
      <div style={styles.section}>
        <h3 style={styles.heading}>Notelet Castrator</h3>

        <p>
          This is the Notelet Castrator. Its purpose is to neuter your Notelet by
          adding // to the front of every line, commenting out all Javascript.
          Use this tool when your Nodelet is causing problems and there is no other way to fix them.
        </p>

        <form method="post" style={styles.form}>
          <input type="hidden" name="node_id" value={e2?.node_id || ''} />
          <input type="hidden" name="YesReallyCastrate" value="1" />

          <p>Your notelet contains {char_count} characters.</p>

          <button type="submit" style={styles.dangerButton}>
            Castrate Notelet
          </button>
        </form>
      </div>

      <hr style={styles.separator} />

      {/* Notelet Editor Section */}
      <div style={styles.section}>
        <h3 style={styles.heading}>Notelet Editor</h3>

        <p>
          This <strong>Notelet Editor</strong> lets you edit your Notelet. No, not your nodelet, your notelet (your notelet nodelet).
          {!notelet_enabled && (
            <span style={styles.warning}>
              {' '}(Note: you currently don't have your Notelet on, so changing things here is rather pointless.
              You can turn on the Notelet nodelet by visiting your user settings.)
            </span>
          )}
          {' '}What is the notelet? It lets you put notes (or anything, really) into a nodelet.
        </p>

        {hadScriptTags && (
          <div style={styles.warning_box}>
            <strong>Note:</strong> Script tags have been automatically removed from your notelet.
            Script tags are no longer supported as they interfere with the site. Click Submit to save the cleaned version.
          </div>
        )}

        {success_message && (
          <div style={styles.success}>{success_message}</div>
        )}

        {error && (
          <div style={styles.error}>{error}</div>
        )}

        {/* Notes */}
        <div style={styles.notes}>
          <p><strong>About Notelets</strong>:</p>
          <p>
            Your notelet is a personal space for freeform notes, quick links, and reminders that appears
            in your nodelet sidebar. You can use basic HTML formatting and E2 softlinks like [node title].
          </p>
          <p>
            The raw text you enter here is limited to 32768 characters.
            As a reward for gaining levels, more of your raw text is displayed.
            You are level {user_level}, so your maximum displayed length is <strong>{max_length}</strong> characters.
          </p>
        </div>

        {/* Preview */}
        <div style={styles.previewSection}>
          <p><strong>Preview</strong>:</p>

          {!notelet_screened ? (
            <p style={styles.emptyPreview}>
              <em>No text entered for the Notelet nodelet.</em>
            </p>
          ) : showPreview ? (
            <>
              <p style={styles.previewNote}>
                (If you missed a closing tag somewhere, and the bottom part of this page is all messed up,
                follow this <strong><a href="#" onClick={(e) => { e.preventDefault(); setShowPreview(false); }}>Oops!</a></strong> link to hide the preview.)
              </p>
              <p>
                Your filtered length is currently {screenedLength} character{screenedLength === 1 ? '' : 's'}.
              </p>
              <div style={styles.previewBox}>
                <div dangerouslySetInnerHTML={{ __html: notelet_screened }} />
              </div>
            </>
          ) : (
            <p style={styles.emptyPreview}>
              <em>Preview hidden. <a href="#" onClick={(e) => { e.preventDefault(); setShowPreview(true); }}>Show preview</a></em>
            </p>
          )}
        </div>

        {/* Edit Form */}
        <div style={styles.editSection}>
          <p><strong>Edit</strong>:</p>
          <p>Your raw text is {currentLength} character{currentLength === 1 ? '' : 's'}.</p>

          <form method="post" style={styles.form}>
            <input type="hidden" name="node_id" value={e2?.node_id || ''} />
            <input type="hidden" name="sexisgood" value="1" />

            <div style={styles.checkboxGroup}>
              <label>
                <input
                  type="checkbox"
                  checked={!keepComments}
                  onChange={(e) => setKeepComments(!e.target.checked)}
                />
                {' '}Remove HTML comments
              </label>
              {/* Hidden field to set nodeletKeepComments based on checkbox state */}
              <input
                type="hidden"
                name="nodeletKeepComments"
                value={keepComments ? '1' : '0'}
              />
              <span style={styles.checkboxNote}>
                {' '}(HTML comments like <code>&lt;!-- text --&gt;</code> will be stripped from the displayed output.
                Your source text is never modified.)
              </span>
            </div>

            <textarea
              name="notelet_source"
              rows="25"
              cols="65"
              value={noteletRaw}
              onChange={(e) => {
                const newValue = e.target.value;
                const MAX_RAW = 32768;
                if (newValue.length <= MAX_RAW) {
                  setNoteletRaw(newValue);
                } else {
                  alert(`You can only have up to ${MAX_RAW} characters in this notelet. You currently have ${newValue.length}. Anything typed past this point will be irretrievably removed.`);
                }
              }}
              style={styles.textarea}
              maxLength={32768}
            />

            <div style={styles.charCounter}>
              {currentLength} / 32768 characters (first {max_length} will be used)
              {currentLength >= 32768 && (
                <span style={styles.limitWarning}> (limit reached)</span>
              )}
            </div>

            <button type="submit" name="makethechange" value="1" style={styles.submitButton}>
              Submit
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px'
  },
  section: {
    marginBottom: '30px'
  },
  heading: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '15px'
  },
  separator: {
    border: 'none',
    borderTop: '1px solid #ccc',
    margin: '30px 0'
  },
  form: {
    marginTop: '15px'
  },
  dangerButton: {
    padding: '8px 16px',
    border: '1px solid #dc3545',
    borderRadius: '4px',
    backgroundColor: '#dc3545',
    color: '#fff',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '600'
  },
  submitButton: {
    padding: '8px 16px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: '#4060b0',
    color: '#fff',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '600',
    marginTop: '10px'
  },
  warning: {
    color: '#856404',
    fontStyle: 'italic'
  },
  success: {
    padding: '12px',
    backgroundColor: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    color: '#2e7d32',
    marginBottom: '15px'
  },
  error: {
    padding: '12px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginBottom: '15px'
  },
  warning_box: {
    padding: '12px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    color: '#856404',
    marginBottom: '15px'
  },
  notes: {
    backgroundColor: '#f8f9f9',
    padding: '15px',
    borderRadius: '4px',
    marginBottom: '20px',
    border: '1px solid #dee2e6'
  },
  previewSection: {
    marginBottom: '25px'
  },
  previewNote: {
    fontSize: '12px',
    color: '#666'
  },
  previewBox: {
    border: '1px solid #000',
    padding: '15px',
    backgroundColor: '#fff',
    borderRadius: '4px',
    marginTop: '10px'
  },
  emptyPreview: {
    fontStyle: 'italic',
    color: '#6c757d'
  },
  editSection: {
    marginTop: '25px'
  },
  checkboxGroup: {
    marginBottom: '10px'
  },
  checkboxNote: {
    fontSize: '12px',
    color: '#666'
  },
  textarea: {
    width: '100%',
    maxWidth: '800px',
    padding: '10px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '13px',
    fontFamily: 'monospace',
    lineHeight: '1.5',
    resize: 'vertical'
  },
  charCounter: {
    fontSize: '12px',
    color: '#666',
    marginTop: '5px',
    marginBottom: '10px'
  },
  limitWarning: {
    color: '#dc3545',
    fontWeight: 'bold'
  }
}

export default NoteletEditor

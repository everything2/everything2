import React, { useState } from 'react'

/**
 * Notelet Editor - Manage user notelet content
 * Styles in CSS: .notelet-editor__*
 *
 * Castrator comments out all JS; the editor saves the raw source (per-level display cap).
 * Both actions POST to /api/notelet (#4479, Refs #4298) — the page itself is pure-render.
 */
const NoteletEditor = ({ data, e2 }) => {
  const {
    notelet_raw: initialNoteletRaw = '',
    notelet_screened: initialScreened = '',
    char_count: initialCharCount = 0,
    max_length = 2000,
    user_level = 0,
    notelet_enabled = false,
    keep_comments: initialKeepComments = false,
    success_message = '',
    error = ''
  } = data

  // Strip script tags on initial load to allow users to remove legacy scripts
  const stripScriptTags = (text) => {
    return (text || '')
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<script[^>]*>/gi, '')
      .replace(/<\/script>/gi, '')  // Also catch stray closing tags
  }

  const [noteletRaw, setNoteletRaw] = useState(stripScriptTags(initialNoteletRaw))
  const [keepComments, setKeepComments] = useState(initialKeepComments)
  const [screened, setScreened] = useState(initialScreened)
  const [charCount, setCharCount] = useState(initialCharCount)
  const [showPreview, setShowPreview] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [successMessage, setSuccessMessage] = useState(success_message)
  const [errorMsg, setErrorMsg] = useState(error)

  // Show warning if script tags were stripped
  const hadScriptTags = initialNoteletRaw !== stripScriptTags(initialNoteletRaw)

  const currentLength = noteletRaw.length
  const screenedLength = screened.length

  const applyResult = (result) => {
    setNoteletRaw(stripScriptTags(result.notelet_raw || ''))
    setScreened(result.notelet_screened || '')
    setCharCount(result.char_count || 0)
    setKeepComments(!!result.keep_comments)
    setSuccessMessage(result.message || '')
    setErrorMsg(result.error || '')
  }

  // /api/notelet returns 200 with {success:0,error} on a rejected write and 200 with the fresh
  // payload on success (universal consumption rule: !ok || success===0 => failure).
  const post = async (action, body) => {
    setSubmitting(true)
    setSuccessMessage('')
    setErrorMsg('')
    try {
      const res = await fetch(`/api/notelet/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: body ? JSON.stringify(body) : undefined
      })
      const result = await res.json()
      if (!res.ok || result.success === 0) {
        setErrorMsg(result.error || 'Something went wrong saving your notelet.')
      } else {
        applyResult(result)
      }
    } catch (err) {
      setErrorMsg('Network error: ' + err.message)
    } finally {
      setSubmitting(false)
    }
  }

  const handleCastrate = () => post('castrate')
  const handleSave = (e) => {
    e.preventDefault()
    post('save', { notelet_source: noteletRaw, keep_comments: keepComments })
  }

  return (
    <div className="notelet-editor">
      {/* Notelet Castrator Section */}
      <div className="notelet-editor__section">
        <h3 className="notelet-editor__heading">Notelet Castrator</h3>

        <p>
          This is the Notelet Castrator. Its purpose is to neuter your Notelet by
          adding // to the front of every line, commenting out all Javascript.
          Use this tool when your Nodelet is causing problems and there is no other way to fix them.
        </p>

        <p>Your notelet contains {charCount} characters.</p>

        <button
          type="button"
          onClick={handleCastrate}
          disabled={submitting}
          className="notelet-editor__danger-button"
        >
          Castrate Notelet
        </button>
      </div>

      <hr className="notelet-editor__separator" />

      {/* Notelet Editor Section */}
      <div className="notelet-editor__section">
        <h3 className="notelet-editor__heading">Notelet Editor</h3>

        <p>
          This <strong>Notelet Editor</strong> lets you edit your Notelet. No, not your nodelet, your notelet (your notelet nodelet).
          {!notelet_enabled && (
            <span className="notelet-editor__warning-text">
              {' '}(Note: you currently don't have your Notelet on, so changing things here is rather pointless.
              You can turn on the Notelet nodelet by visiting your user settings.)
            </span>
          )}
          {' '}What is the notelet? It lets you put notes (or anything, really) into a nodelet.
        </p>

        {hadScriptTags && (
          <div className="notelet-editor__warning-box">
            <strong>Note:</strong> Script tags have been automatically removed from your notelet.
            Script tags are no longer supported as they interfere with the site. Click Submit to save the cleaned version.
          </div>
        )}

        {successMessage && (
          <div className="notelet-editor__success">{successMessage}</div>
        )}

        {errorMsg && (
          <div className="notelet-editor__error">{errorMsg}</div>
        )}

        {/* Notes */}
        <div className="notelet-editor__notes">
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
        <div className="notelet-editor__preview-section">
          <p><strong>Preview</strong>:</p>

          {!screened ? (
            <p className="notelet-editor__empty-preview">
              <em>No text entered for the Notelet nodelet.</em>
            </p>
          ) : showPreview ? (
            <>
              <p className="notelet-editor__preview-note">
                (If you missed a closing tag somewhere, and the bottom part of this page is all messed up,
                follow this <strong><a href="#" onClick={(e) => { e.preventDefault(); setShowPreview(false); }}>Oops!</a></strong> link to hide the preview.)
              </p>
              <p>
                Your filtered length is currently {screenedLength} character{screenedLength === 1 ? '' : 's'}.
              </p>
              <div className="notelet-editor__preview-box">
                <div dangerouslySetInnerHTML={{ __html: screened }} />
              </div>
            </>
          ) : (
            <p className="notelet-editor__empty-preview">
              <em>Preview hidden. <a href="#" onClick={(e) => { e.preventDefault(); setShowPreview(true); }}>Show preview</a></em>
            </p>
          )}
        </div>

        {/* Edit Form */}
        <div className="notelet-editor__edit-section">
          <p><strong>Edit</strong>:</p>
          <p>Your raw text is {currentLength} character{currentLength === 1 ? '' : 's'}.</p>

          <form onSubmit={handleSave} className="notelet-editor__form">
            <div className="notelet-editor__checkbox-group">
              <label>
                <input
                  type="checkbox"
                  checked={!keepComments}
                  onChange={(e) => setKeepComments(!e.target.checked)}
                />
                {' '}Remove HTML comments
              </label>
              <span className="notelet-editor__checkbox-note">
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
              className="notelet-editor__textarea"
              maxLength={32768}
            />

            <div className="notelet-editor__char-counter">
              {currentLength} / 32768 characters (first {max_length} will be used)
              {currentLength >= 32768 && (
                <span className="notelet-editor__limit-warning"> (limit reached)</span>
              )}
            </div>

            <button type="submit" disabled={submitting} className="notelet-editor__submit-button">
              {submitting ? 'Saving…' : 'Submit'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}

export default NoteletEditor

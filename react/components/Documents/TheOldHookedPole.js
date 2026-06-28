import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * TheOldHookedPole - Editor tool for mass user account management.
 * Styles in CSS: .hooked-pole__*
 *
 * Submits the username list to POST /api/admin/users/cleanup and renders the
 * per-user outcome (deleted / locked / skipped) returned by the API. Only gods
 * can actually delete a user node; for everyone else a "safe to delete" account
 * is locked instead, and the API reports that honestly -- the UI surfaces the
 * exact state per user rather than assuming a deletion happened.
 */
const ACTION_LABEL = {
  deleted: 'Deleted',
  locked: 'Locked',
  skipped: 'Skipped'
}

const TheOldHookedPole = ({ data, user = {}, e2 }) => {
  const { message, prefill } = data
  const is_editor = user.editor
  const node_id = e2?.node?.node_id ?? (typeof window !== 'undefined' ? window.e2?.node?.node_id : undefined)

  const [usernames, setUsernames] = useState(prefill || '')
  const [smite, setSmite] = useState(false)
  const [results, setResults] = useState(null)
  const [savedUsers, setSavedUsers] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  if (!is_editor) {
    return (
      <div className="hooked-pole">
        <p>{message}</p>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)

    try {
      const response = await fetch('/api/admin/users/cleanup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ usernames, smite: smite ? 1 : 0 })
      })
      const payload = await response.json()

      if (payload.success) {
        setResults(payload.results || [])
        setSavedUsers(payload.saved_users || [])
      } else {
        setError(payload.message || payload.error || 'Request failed')
      }
    } catch (err) {
      setError('Failed to process the list: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="hooked-pole">
      {error && (
        <p className="hooked-pole__error" role="alert">{error}</p>
      )}

      {results && results.length > 0 && (
        <div className="hooked-pole__results-section">
          <h3 className="hooked-pole__subtitle">The Doomed Performers</h3>
          <ul className="hooked-pole__results-list">
            {results.map((result, idx) => (
              <li
                key={idx}
                className={`hooked-pole__result-item hooked-pole__result-item--${result.action}`}
              >
                <span className={`hooked-pole__status hooked-pole__status--${result.action}`}>
                  {ACTION_LABEL[result.action] || result.action}
                </span>{' '}
                {result.action === 'deleted' ? (
                  <span className="hooked-pole__deleted">
                    {result.input} ({result.node_id}).
                  </span>
                ) : (
                  <>
                    {result.node_id ? (
                      <LinkNode nodeId={result.node_id} title={result.title || result.input} />
                    ) : (
                      <span>{result.input}</span>
                    )}
                    {result.reasons && result.reasons.length > 0 && (
                      <ul className="hooked-pole__reasons-list">
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

      <h3 className="hooked-pole__subtitle">&ldquo;Off the stage with &apos;em!&rdquo;</h3>
      <p>A mass user deletion tool which provides basic checks for deletion.</p>
      <p>Copy and paste list of names of users to destroy.</p>

      <div className="hooked-pole__checks-list">
        <p>This does the following things:</p>
        <ul>
          <li>Checks to see if the user has ever logged in</li>
          <li>Checks if the user has any live writeups</li>
          <li>Checks if the user has any live e2nodes</li>
          <li>Deletes the user if it is safe (and you are allowed to delete users)</li>
          <li>Locks the user if deletion isn&apos;t safe or isn&apos;t permitted</li>
        </ul>
      </div>

      <form onSubmit={handleSubmit} className="hooked-pole__form">
        <input type="hidden" name="node_id" value={node_id ?? ''} />
        {savedUsers && savedUsers.length > 0 && (
          <fieldset className="hooked-pole__fieldset">
            <legend>The users who were spared</legend>
            <textarea
              name="ignored-saved"
              value={savedUsers.join('\n')}
              className="hooked-pole__textarea"
              readOnly
            />
          </fieldset>
        )}

        <fieldset className="hooked-pole__fieldset">
          <legend>Inadequate Performers</legend>
          <textarea
            name="usernames"
            rows="10"
            cols="30"
            className="hooked-pole__textarea"
            placeholder="Enter usernames, one per line"
            value={usernames}
            onChange={(e) => setUsernames(e.target.value)}
          />
          <br />
          <label className="hooked-pole__smite">
            <input
              type="checkbox"
              checked={smite}
              onChange={(e) => setSmite(e.target.checked)}
            />{' '}
            Smite spammers (blank homenode, blacklist a shared recently-locked IP)
          </label>
          <br /><br />
          <button type="submit" className="hooked-pole__button" disabled={loading}>
            {loading ? 'Working…' : 'Get The Hook!'}
          </button>
        </fieldset>
      </form>
    </div>
  )
}

export default TheOldHookedPole

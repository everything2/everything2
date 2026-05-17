import React from 'react'
import LinkNode from '../LinkNode'

/**
 * TheOldHookedPole - Editor tool for mass user account management.
 * Styles in CSS: .hooked-pole__*
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
      <div className="hooked-pole">
        <p>{message}</p>
      </div>
    )
  }

  return (
    <div className="hooked-pole">
      {results && results.length > 0 && (
        <div className="hooked-pole__results-section">
          <h3 className="hooked-pole__subtitle">The Doomed Performers</h3>
          <ul className="hooked-pole__results-list">
            {results.map((result, idx) => (
              <li key={idx} className="hooked-pole__result-item">
                {result.action === 'deleted' ? (
                  <span className="hooked-pole__deleted">
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

      {show_form && (
        <>
          <h3 className="hooked-pole__subtitle">&ldquo;Off the stage with &apos;em!&rdquo;</h3>
          <p>
            A mass user deletion tool which provides basic checks for deletion.
          </p>
          <p>Copy and paste list of names of users to destroy.</p>

          <div className="hooked-pole__checks-list">
            <p>This does the following things:</p>
            <ul>
              <li>Checks to see if the user has ever logged in</li>
              <li>Checks if the user has any live writeups</li>
              <li>Checks if the user has any live e2nodes</li>
              <li>Deletes the user if it is safe</li>
              <li>Locks a user if deletion isn&apos;t safe</li>
            </ul>
          </div>

          <form method="post" className="hooked-pole__form">
            <input type="hidden" name="node_id" value={node_id} />
            <input type="hidden" name="polehash_nonce" value={polehash_nonce} />
            <input type="hidden" name="polehash_seed" value={polehash_seed} />

            {saved_users && saved_users.length > 0 && (
              <fieldset className="hooked-pole__fieldset">
                <legend>The users who were spared</legend>
                <textarea
                  name="ignored-saved"
                  defaultValue={saved_users.join('\n')}
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
                defaultValue={prefill || ''}
              />
              <br /><br />
              <button type="submit" className="hooked-pole__button">
                Get The Hook!
              </button>
            </fieldset>
          </form>
        </>
      )}
    </div>
  )
}

export default TheOldHookedPole

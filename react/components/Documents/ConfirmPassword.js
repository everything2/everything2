import React, { useState, useCallback } from 'react'

/**
 * ConfirmPassword - Login/password confirmation form
 * Styles in CSS: .confirm-password__*
 */
const ConfirmPassword = ({ data }) => {
  const confirmData = data || {}
  const {
    state,
    message,
    error,
    prompt,
    username,
    action,
    token,
    expiry,
    currentSalt,
    renewLink,
    renewLabel,
    signupLink,
    profileUrl,
  } = confirmData

  const [password, setPassword] = useState('')
  const [stayLoggedIn, setStayLoggedIn] = useState(false)
  const [loading, setLoading] = useState(false)

  const handleSubmit = useCallback((e) => {
    // Allow form to submit normally since login is handled by the server
    if (!password.trim()) {
      e.preventDefault()
      return
    }
    setLoading(true)
  }, [password])

  // Missing parameters
  if (state === 'missing_params') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__message">
          <p>{message}</p>
        </div>
      </div>
    )
  }

  // Invalid action
  if (state === 'invalid_action') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__error">
          <p>{error}</p>
        </div>
      </div>
    )
  }

  // Link expired
  if (state === 'expired') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__error">
          <p>{message}{' '}
          {renewLink && (
            <>But you can <a href={renewLink} className="confirm-password__link">{renewLabel}</a>.</>
          )}
          </p>
        </div>
      </div>
    )
  }

  // User not found
  if (state === 'no_user') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__error">
          <p>{message}{' '}
          {signupLink && (
            <>But you can <a href={signupLink} className="confirm-password__link">create a new one</a>.</>
          )}
          </p>
        </div>
      </div>
    )
  }

  // Locked account
  if (state === 'locked') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__error">
          <p>{error}</p>
        </div>
      </div>
    )
  }

  // Success - password reset
  if (state === 'success_reset') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__success">
          <p>{message}</p>
        </div>
      </div>
    )
  }

  // Success - account activated
  if (state === 'success_activate') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__success">
          <p>{message}</p>
          <p>
            Perhaps you'd like to edit{' '}
            <a href={profileUrl} className="confirm-password__link">your profile</a>,
            or check out the logged-in users'{' '}
            <a href="/" className="confirm-password__link">front page</a>,
            or maybe just read{' '}
            <a href="/?op=randomnode" className="confirm-password__link">something at random</a>.
          </p>
        </div>
      </div>
    )
  }

  // Login required
  if (state === 'login_required') {
    return (
      <div className="confirm-password">
        <form method="POST" action="/index.pl" onSubmit={handleSubmit}>
          <fieldset className="confirm-password__fieldset">
            <legend className="confirm-password__legend">Log in</legend>

            <p className="confirm-password__prompt">{prompt}:</p>

            <div className="confirm-password__form-group">
              <label className="confirm-password__label">
                <span className="confirm-password__label-text">Username:</span>
                <input
                  type="text"
                  name="user"
                  value={username}
                  readOnly
                  className="confirm-password__input confirm-password__input--readonly"
                />
              </label>
              <label className="confirm-password__label">
                <span className="confirm-password__label-text">Password:</span>
                <input
                  type="password"
                  name="passwd"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="confirm-password__input"
                  autoFocus
                />
              </label>
            </div>

            <div className="confirm-password__checkbox-group">
              <label>
                <input
                  type="checkbox"
                  name="expires"
                  value="+10y"
                  checked={stayLoggedIn}
                  onChange={(e) => setStayLoggedIn(e.target.checked)}
                />
                {' '}stay logged in
              </label>
            </div>

            <div className="confirm-password__button-container">
              <button
                type="submit"
                name="sockItToMe"
                disabled={loading || !password.trim()}
                className={`confirm-password__button${loading || !password.trim() ? ' confirm-password__button--disabled' : ''}`}
              >
                {loading ? 'Logging in...' : action}
              </button>
            </div>
          </fieldset>

          <input type="hidden" name="token" value={token} />
          <input type="hidden" name="action" value={action} />
          <input type="hidden" name="expiry" value={expiry} />
          <input type="hidden" name="oldsalt" value={currentSalt} />
          <input type="hidden" name="op" value="login" />
        </form>
      </div>
    )
  }

  // Default/unknown state
  return (
    <div className="confirm-password">
      <div className="confirm-password__message">
        <p>Loading...</p>
      </div>
    </div>
  )
}

export default ConfirmPassword

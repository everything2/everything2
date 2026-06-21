import React, { useState, useCallback } from 'react'
import { goToRandomNode } from '../../utils/randomNode'

/**
 * ConfirmPassword - account activation / password-reset confirmation.
 *
 * The page loads with a server-rendered state (login_required for a valid link,
 * or missing_params/expired/no_user/locked). Submitting the login form POSTs to
 * /api/users/confirm (which validates the token, sets the password, logs in, and
 * on activation sends the welcome PM) and we render the returned state. #4335
 *
 * Styles in CSS: .confirm-password__*
 */
const ConfirmPassword = ({ data }) => {
  const confirmData = data || {}
  const {
    username,
    action,
    token,
    expiry,
    prompt,
    renewLink,
    renewLabel,
    signupLink,
  } = confirmData

  const [password, setPassword] = useState('')
  const [stayLoggedIn, setStayLoggedIn] = useState(false)
  const [loading, setLoading] = useState(false)

  // The displayed view starts from the server-rendered state and is replaced by
  // the /api/users/confirm response after the user submits.
  const [view, setView] = useState({
    state: confirmData.state,
    message: confirmData.message,
    error: confirmData.error,
    profileUrl: confirmData.profileUrl,
  })

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    if (!password.trim()) return
    setLoading(true)
    try {
      const res = await fetch('/api/users/confirm', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          username,
          passwd: password,
          token,
          action,
          expiry,
          ...(stayLoggedIn ? { expires: '+10y' } : {}),
        }),
      })
      const d = res.ok ? await res.json() : null
      if (d && (d.state === 'success_activate' || d.state === 'success_reset')) {
        // The user is now logged in, but the surrounding page chrome was rendered
        // server-side as a guest. Navigate so it reloads into the logged-in page
        // (their new profile for activation, the front page for a reset).
        window.location.href = d.profileUrl || '/'
        return
      }
      if (d && d.state) {
        setView({ state: d.state, message: d.message, error: d.error, profileUrl: d.profileUrl })
      } else {
        setView({ state: 'login_required', error: 'Something went wrong. Please try again.' })
      }
    } catch (err) {
      setView({ state: 'login_required', error: 'Something went wrong. Please try again.' })
    } finally {
      setLoading(false)
    }
  }, [password, username, token, action, expiry, stayLoggedIn])

  const { state, message, error, profileUrl } = view

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
            <a href="#" onClick={(e) => { e.preventDefault(); goToRandomNode() }} className="confirm-password__link">something at random</a>.
          </p>
        </div>
      </div>
    )
  }

  // Login required (initial valid link, or a failed/invalid submission)
  if (state === 'login_required') {
    return (
      <div className="confirm-password">
        <form onSubmit={handleSubmit}>
          <fieldset className="confirm-password__fieldset">
            <legend className="confirm-password__legend">Log in</legend>

            {error
              ? <p className="confirm-password__error">{error}</p>
              : <p className="confirm-password__prompt">{prompt}:</p>}

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
                  checked={stayLoggedIn}
                  onChange={(e) => setStayLoggedIn(e.target.checked)}
                />
                {' '}stay logged in
              </label>
            </div>

            <div className="confirm-password__button-container">
              <button
                type="submit"
                disabled={loading || !password.trim()}
                className={`confirm-password__button${loading || !password.trim() ? ' confirm-password__button--disabled' : ''}`}
              >
                {loading ? 'Logging in...' : action}
              </button>
            </div>
          </fieldset>
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

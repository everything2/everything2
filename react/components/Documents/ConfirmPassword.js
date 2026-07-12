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
// Per-state display copy lives here, keyed on state (#4511): both the server-rendered Page and the
// /api/users/confirm response now ship only { state } (+ backend-derived links), never the copy.
const STATE_COPY = {
  missing_params: "To use this page, please click on or copy and paste the link from the email we sent you. If we didn't send you an email, you don't need this page.",
  invalid_action: 'Invalid action.',
  expired: 'This link has expired.',
  no_user: 'The account you are trying to activate does not exist.',
  locked: "We're sorry, but we don't accept new users from the IP address you used to create this account. Please get in touch with us if you think this is a mistake.",
  success_reset: 'Password updated. You are logged in.',
  success_activate: 'Your account has been activated and you have been logged in.',
  login_required: {
    prompt: (action) => `Please log in with your username and password to ${action} your account`,
    error: 'Password or link invalid. Please try again.',
  },
}
const RENEW_LABEL = 'get a new one'
const GENERIC_ERROR = 'Something went wrong. Please try again.'

const ConfirmPassword = ({ data }) => {
  const confirmData = data || {}
  const {
    username,
    action,
    token,
    expiry,
    renewLink,
    signupLink,
  } = confirmData

  const [password, setPassword] = useState('')
  const [stayLoggedIn, setStayLoggedIn] = useState(false)
  const [loading, setLoading] = useState(false)
  // Error shown inside the login form after a failed submit (the initial view shows the prompt).
  const [submitError, setSubmitError] = useState(null)

  // The displayed view starts from the server-rendered state and is replaced by
  // the /api/users/confirm response after the user submits.
  const [view, setView] = useState({ state: confirmData.state, profileUrl: confirmData.profileUrl })

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    if (!password.trim()) return
    setLoading(true)
    setSubmitError(null)
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
      if (d && d.state === 'login_required') {
        setSubmitError(STATE_COPY.login_required.error) // stay on the form, show the failure
      } else if (d && d.state) {
        setView({ state: d.state, profileUrl: d.profileUrl }) // token expired/user gone mid-flow
      } else {
        setSubmitError(GENERIC_ERROR)
      }
    } catch (err) {
      setSubmitError(GENERIC_ERROR)
    } finally {
      setLoading(false)
    }
  }, [password, username, token, action, expiry, stayLoggedIn])

  const { state, profileUrl } = view

  // Missing parameters
  if (state === 'missing_params') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__message">
          <p>{STATE_COPY.missing_params}</p>
        </div>
      </div>
    )
  }

  // Invalid action
  if (state === 'invalid_action') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__error">
          <p>{STATE_COPY.invalid_action}</p>
        </div>
      </div>
    )
  }

  // Link expired
  if (state === 'expired') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__error">
          <p>{STATE_COPY.expired}{' '}
          {renewLink && (
            <>But you can <a href={renewLink} className="confirm-password__link">{RENEW_LABEL}</a>.</>
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
          <p>{STATE_COPY.no_user}{' '}
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
          <p>{STATE_COPY.locked}</p>
        </div>
      </div>
    )
  }

  // Success - password reset
  if (state === 'success_reset') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__success">
          <p>{STATE_COPY.success_reset}</p>
        </div>
      </div>
    )
  }

  // Success - account activated
  if (state === 'success_activate') {
    return (
      <div className="confirm-password">
        <div className="confirm-password__success">
          <p>{STATE_COPY.success_activate}</p>
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

            {submitError
              ? <p className="confirm-password__error">{submitError}</p>
              : <p className="confirm-password__prompt">{STATE_COPY.login_required.prompt(action)}:</p>}

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

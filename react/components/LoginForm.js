import React, { useState } from 'react'
import LinkNode from './LinkNode'

/**
 * LoginForm - Reusable user login form
 *
 * Features:
 * - Username/password authentication via API
 * - Loading state during submission
 * - Error display with user-friendly messages
 * - Forgot password link
 * - Multiple layout modes: compact (modal), nodelet (sidebar), full (page)
 *
 * @param {function} onSuccess - Called after successful login (before page reload)
 * @param {function} onError - Called with error message on failure
 * @param {boolean} compact - Use compact layout for modal embedding
 * @param {boolean} nodelet - Use nodelet layout for sidebar (smaller fonts, remember me)
 * @param {boolean} showForgotPassword - Show forgot password link (default: true)
 * @param {boolean} showSignUpLink - Show sign up link (nodelet mode, default: true)
 * @param {boolean} autoFocus - Auto-focus the username field (default: true)
 * @param {string} loginMessage - Optional error/info message to display
 */

const LoginForm = ({
  onSuccess,
  onError,
  compact = false,
  nodelet = false,
  showForgotPassword = true,
  showSignUpLink = true,
  autoFocus = true,
  loginMessage = ''
}) => {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setIsSubmitting(true)

    try {
      const response = await fetch('/api/sessions/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({
          username,
          passwd: password
        })
      })

      if (response.ok) {
        // Login successful
        if (onSuccess) {
          onSuccess({ username })
        }
        // Reload page to apply session
        // Strip any op= parameter to avoid re-triggering opcodes like logout
        const url = new URL(window.location.href)
        if (url.searchParams.has('op')) {
          url.searchParams.delete('op')
          window.location.href = url.toString()
        } else {
          window.location.reload()
        }
      } else if (response.status === 403) {
        const errorMsg = 'Invalid username or password'
        setError(errorMsg)
        if (onError) onError(errorMsg)
      } else {
        const errorMsg = 'Login failed. Please try again.'
        setError(errorMsg)
        if (onError) onError(errorMsg)
      }
    } catch (err) {
      const errorMsg = 'Connection error. Please try again.'
      setError(errorMsg)
      if (onError) onError(errorMsg)
    } finally {
      setIsSubmitting(false)
    }
  }

  if (compact) {
    return (
      <form onSubmit={handleSubmit} className="login-form-compact">
        {error && <div className="login-error">{error}</div>}

        <input
          type="text"
          placeholder="Username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
          autoComplete="username"
          autoFocus={autoFocus}
          className="login-input"
        />

        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          autoComplete="current-password"
          className="login-input"
        />

        <button
          type="submit"
          disabled={isSubmitting}
          className="login-btn"
        >
          {isSubmitting ? 'Logging in...' : 'Log In'}
        </button>

        {showForgotPassword && (
          <a href="/title/Reset%20Password" className="login-forgot-link">
            Forgot password?
          </a>
        )}
      </form>
    )
  }

  // Nodelet layout (sidebar, smaller fonts, remember me)
  if (nodelet) {
    return (
      <>
        <form onSubmit={handleSubmit} className="login-form-nodelet">
          {(error || loginMessage) && (
            <div className="login-error">
              {error || loginMessage}
            </div>
          )}

          <div className="login-field">
            <label htmlFor="signin_user" className="login-label">
              Login
            </label>
            <input
              type="text"
              id="signin_user"
              name="user"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              maxLength="20"
              tabIndex="1"
              autoComplete="username"
              autoFocus={autoFocus}
              required
              className="login-input"
            />
          </div>

          <div className="login-field">
            <label htmlFor="signin_passwd" className="login-label">
              Password
            </label>
            <input
              type="password"
              id="signin_passwd"
              name="passwd"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              maxLength="240"
              tabIndex="2"
              autoComplete="current-password"
              required
              className="login-input"
            />
          </div>

          <div className="login-field">
            <label htmlFor="signin_expires" className="login-checkbox-label">
              <input
                type="checkbox"
                id="signin_expires"
                name="expires"
                tabIndex="3"
              />
              <span>Remember me</span>
            </label>
          </div>

          <button
            type="submit"
            disabled={isSubmitting}
            tabIndex="4"
            className="login-btn"
          >
            {isSubmitting ? 'Logging in...' : 'Login'}
          </button>
        </form>

        <div className="login-form-nodelet-links">
          {showForgotPassword && (
            <div><LinkNode title="Reset password" type="superdoc" display="Lost password?" /></div>
          )}
          {showSignUpLink && (
            <div><LinkNode title="Sign Up" type="superdoc" display="Create an account" /></div>
          )}
          <div className="login-help-text">
            Need help? <a href="mailto:accounthelp@everything2.com" className="login-help-link">accounthelp@everything2.com</a>
          </div>
        </div>
      </>
    )
  }

  // Full form layout (for standalone usage)
  return (
    <form onSubmit={handleSubmit} className="login-form-full">
      {error && (
        <p className="login-error">
          {error}
        </p>
      )}

      <div className="login-field">
        <label className="login-field-row">
          <span className="login-field-label">Username:</span>
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            autoFocus={autoFocus}
            className="login-input"
            required
          />
        </label>
      </div>

      <div className="login-field">
        <label className="login-field-row">
          <span className="login-field-label">Password:</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            className="login-input"
            required
          />
        </label>
      </div>

      <div className="login-actions">
        <button
          type="submit"
          disabled={isSubmitting}
          className="login-btn"
        >
          {isSubmitting ? 'Logging in...' : 'Log In'}
        </button>

        {showForgotPassword && (
          <a
            href="/title/Reset%20Password"
            className="login-forgot-link"
          >
            Forgot password?
          </a>
        )}
      </div>
    </form>
  )
}

export default LoginForm

import React, { useState, useCallback } from 'react'

/**
 * ResetPassword - Password reset form
 * Styles in CSS: .reset-password__*
 */
const ResetPassword = ({ data }) => {
  const [who, setWho] = useState('')
  const [password, setPassword] = useState('')
  const [passwordConfirm, setPasswordConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)

    // Client-side validation
    if (!who.trim()) {
      setError('Please enter your username or email address')
      setLoading(false)
      return
    }

    if (!password) {
      setError('Please enter a new password')
      setLoading(false)
      return
    }

    if (password !== passwordConfirm) {
      setError("Passwords don't match")
      setLoading(false)
      return
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      setLoading(false)
      return
    }

    try {
      const response = await fetch('/api/password/reset-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          who: who.trim(),
          password,
          passwordConfirm,
        }),
      })

      const result = await response.json()

      if (result.success) {
        setSuccess(result.message)
      } else {
        setError(result.error || 'Something went wrong')
      }
    } catch (err) {
      setError('Failed to connect to the server')
    } finally {
      setLoading(false)
    }
  }, [who, password, passwordConfirm])

  if (success) {
    return (
      <div className="reset-password">
        <div className="reset-password__success">
          <strong>{success}</strong>
          <p className="reset-password__success-note">
            Check your email for the confirmation link.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="reset-password">
      <form onSubmit={handleSubmit}>
        <fieldset className="reset-password__fieldset">
          <legend className="reset-password__legend">Choose new password</legend>

          <p className="reset-password__description">
            Forgotten your password? Fill in your user name or email address here and choose
            a new password, and we will send you an email containing a link to reset it.
          </p>

          {error && <div className="reset-password__error">{error}</div>}

          <div className="reset-password__form-group">
            <label className="reset-password__label" htmlFor="who">
              Username or email address:
            </label>
            <input
              type="text"
              id="who"
              value={who}
              onChange={(e) => setWho(e.target.value)}
              className="reset-password__input"
              maxLength={240}
              disabled={loading}
              autoComplete="username"
            />
          </div>

          <div className="reset-password__form-group">
            <label className="reset-password__label" htmlFor="password">
              New password:
            </label>
            <input
              type="password"
              id="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="reset-password__input"
              maxLength={240}
              disabled={loading}
              autoComplete="new-password"
            />
          </div>

          <div className="reset-password__form-group">
            <label className="reset-password__label" htmlFor="passwordConfirm">
              Repeat new password:
            </label>
            <input
              type="password"
              id="passwordConfirm"
              value={passwordConfirm}
              onChange={(e) => setPasswordConfirm(e.target.value)}
              className="reset-password__input"
              maxLength={240}
              disabled={loading}
              autoComplete="new-password"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className={`reset-password__button${loading ? ' reset-password__button--disabled' : ''}`}
          >
            {loading ? 'Sending...' : 'Submit'}
          </button>
        </fieldset>
      </form>
    </div>
  )
}

export default ResetPassword

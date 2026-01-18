import React, { useState, useEffect, useCallback } from 'react'

/**
 * SignUpForm - Reusable user registration form
 *
 * Features:
 * - Username availability checking via API
 * - Real-time password/email confirmation matching with checkmarks
 * - reCAPTCHA v3 integration (production only)
 * - API-based form submission (no page reload)
 * - Inline error display with specific messages
 * - Compact mode for modals vs full mode for standalone page
 *
 * @param {boolean} useRecaptcha - Whether to require reCAPTCHA validation
 * @param {string} recaptchaKey - reCAPTCHA v3 public key
 * @param {function} onSuccess - Called with { username, linkValid } on successful signup
 * @param {boolean} compact - Use compact layout for modal embedding
 * @param {boolean} showConfirmEmail - Whether to show email confirmation field (default: false for compact)
 */

// Validation status icons
const CheckIcon = () => (
  <span className="signup-form__icon-container">
    <span className="signup-form__icon--check" title="Match">&#10003;</span>
  </span>
)

const XIcon = () => (
  <span className="signup-form__icon-container">
    <span className="signup-form__icon--x" title="Does not match">&#10007;</span>
  </span>
)

const SpinnerIcon = () => (
  <span className="signup-form__icon-container">
    <span className="signup-form__spinner">
      <span className="signup-form__spinner-circle" />
    </span>
  </span>
)

const IconPlaceholder = () => (
  <span className="signup-form__icon-container"></span>
)

const SignUpForm = ({
  useRecaptcha = false,
  recaptchaKey = '',
  onSuccess,
  compact = false,
  showConfirmEmail = true,
  initialUsername = '',
  initialEmail = ''
}) => {
  // Form state
  const [username, setUsername] = useState(initialUsername)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [email, setEmail] = useState(initialEmail)
  const [confirmEmail, setConfirmEmail] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [recaptchaReady, setRecaptchaReady] = useState(!useRecaptcha)

  // Username availability state
  const [usernameStatus, setUsernameStatus] = useState('idle') // idle, checking, available, taken, invalid
  const [usernameCheckTimeout, setUsernameCheckTimeout] = useState(null)

  // Error state
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')

  // Load reCAPTCHA Enterprise script
  useEffect(() => {
    if (!useRecaptcha || !recaptchaKey) {
      setRecaptchaReady(true)
      return
    }

    const markReady = () => {
      const recaptcha = window.grecaptcha?.enterprise || window.grecaptcha
      if (recaptcha) {
        recaptcha.ready(() => {
          setRecaptchaReady(true)
        })
      }
    }

    if (window.grecaptcha) {
      markReady()
      return
    }

    const script = document.createElement('script')
    script.src = `https://www.google.com/recaptcha/enterprise.js?render=${recaptchaKey}`
    script.async = true
    script.onload = markReady
    script.onerror = () => {
      console.error('Failed to load reCAPTCHA script')
      setRecaptchaReady(true) // Allow submission, server will reject
    }

    document.head.appendChild(script)
  }, [useRecaptcha, recaptchaKey])

  // Check username availability with debounce
  const checkUsernameAvailability = useCallback(async (name) => {
    if (!name || name.length < 1) {
      setUsernameStatus('idle')
      return
    }

    // Check format first
    const invalidNamePattern = /^\W+$|[\[\]<>&{}|\/\\]| .*_|_.* |\s\s|^\s|\s$/
    if (invalidNamePattern.test(name)) {
      setUsernameStatus('invalid')
      return
    }

    setUsernameStatus('checking')

    try {
      const response = await fetch(`/api/user/available/${encodeURIComponent(name)}`)
      const result = await response.json()

      if (result.available) {
        setUsernameStatus('available')
      } else if (result.reason === 'invalid_format') {
        setUsernameStatus('invalid')
      } else {
        setUsernameStatus('taken')
      }
    } catch (err) {
      console.error('Username check failed:', err)
      setUsernameStatus('idle')
    }
  }, [])

  // Handle username change with debounce
  const handleUsernameChange = (e) => {
    const newUsername = e.target.value
    setUsername(newUsername)

    if (usernameCheckTimeout) {
      clearTimeout(usernameCheckTimeout)
    }

    const timeout = setTimeout(() => {
      checkUsernameAvailability(newUsername)
    }, 500)
    setUsernameCheckTimeout(timeout)
  }

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (usernameCheckTimeout) {
        clearTimeout(usernameCheckTimeout)
      }
    }
  }, [usernameCheckTimeout])

  // Check initial username on mount
  useEffect(() => {
    if (initialUsername) {
      checkUsernameAvailability(initialUsername)
    }
  }, [initialUsername, checkUsernameAvailability])

  // Computed validation states
  const passwordsMatch = password && confirmPassword && password === confirmPassword
  const passwordsMismatch = password && confirmPassword && password !== confirmPassword
  const emailsMatch = showConfirmEmail ? (email && confirmEmail && email === confirmEmail) : !!email
  const emailsMismatch = showConfirmEmail && email && confirmEmail && email !== confirmEmail

  // Check if form is valid
  const isFormValid = () => {
    if (!recaptchaReady) return false
    if (!username || usernameStatus !== 'available') return false
    if (!password || !passwordsMatch) return false
    if (!email) return false
    if (showConfirmEmail && !emailsMatch) return false
    return true
  }

  // Client-side validation
  const validateForm = () => {
    const newErrors = {}

    const invalidNamePattern = /^\W+$|[\[\]<>&{}|\/\\]| .*_|_.* |\s\s|^\s|\s$/
    if (!username) {
      newErrors.username = 'Username is required'
    } else if (invalidNamePattern.test(username)) {
      newErrors.username = 'Username contains invalid characters'
    } else if (usernameStatus === 'taken') {
      newErrors.username = 'Username is already taken'
    } else if (usernameStatus !== 'available') {
      newErrors.username = 'Please wait for username check to complete'
    }

    if (!password) {
      newErrors.password = 'Password is required'
    }
    if (!confirmPassword) {
      newErrors.confirmPassword = 'Please confirm your password'
    } else if (password !== confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match'
    }

    const emailPattern = /.+@[\w\d.-]+\.[\w]+$/
    if (!email) {
      newErrors.email = 'Email is required'
    } else if (!emailPattern.test(email)) {
      newErrors.email = 'Email does not appear to be valid'
    }

    if (showConfirmEmail) {
      if (!confirmEmail) {
        newErrors.confirmEmail = 'Please confirm your email'
      } else if (email !== confirmEmail) {
        newErrors.confirmEmail = 'Email addresses do not match'
      }
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  // Map server error codes to user-friendly messages
  const getErrorMessage = (error, message) => {
    const errorMessages = {
      invalid_username: 'Username contains invalid characters',
      username_taken: 'That username is already taken. Please choose another.',
      invalid_password: 'Password is required',
      invalid_email: 'Please enter a valid email address',
      email_spam: 'Sign up rejected. Please contact support.',
      email_locked: 'Sign up rejected. Please contact support.',
      ip_blacklisted: 'Sign up rejected. Please contact support.',
      infected: 'Sign up rejected. Please contact support.',
      recaptcha_missing: 'Verification failed. Please refresh and try again.',
      recaptcha_failed: 'Could not verify you are human. Please try again.',
      recaptcha_score: 'Sign up rejected due to spam detection.',
      creation_failed: 'Account creation failed. Please try again.',
      invalid_json: 'Request error. Please refresh and try again.'
    }
    return errorMessages[error] || message || 'An error occurred. Please try again.'
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setServerError('')

    if (!validateForm()) {
      return
    }

    setIsSubmitting(true)

    try {
      // Get fresh reCAPTCHA token if enabled
      let recaptchaToken = ''
      if (useRecaptcha && recaptchaKey) {
        const recaptcha = window.grecaptcha?.enterprise || window.grecaptcha
        if (!recaptcha) {
          setIsSubmitting(false)
          setServerError('reCAPTCHA is still loading. Please try again.')
          return
        }

        recaptchaToken = await new Promise((resolve, reject) => {
          recaptcha.ready(() => {
            recaptcha.execute(recaptchaKey, { action: 'signup' })
              .then(resolve)
              .catch(reject)
          })
        })
      }

      // Submit to API
      const response = await fetch('/api/signup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          username,
          password,
          email,
          recaptcha_token: recaptchaToken
        })
      })

      const result = await response.json()

      if (result.success) {
        if (onSuccess) {
          onSuccess({
            username: result.username,
            linkValid: result.linkvalid || 10,
            email
          })
        }
      } else {
        // Handle specific errors
        if (result.error === 'username_taken') {
          setUsernameStatus('taken')
          setErrors({ username: getErrorMessage(result.error, result.message) })
        } else if (result.error === 'invalid_username') {
          setUsernameStatus('invalid')
          setErrors({ username: getErrorMessage(result.error, result.message) })
        } else if (result.error === 'invalid_email') {
          setErrors({ email: getErrorMessage(result.error, result.message) })
        } else {
          setServerError(getErrorMessage(result.error, result.message))
        }
      }
    } catch (err) {
      console.error('Signup failed:', err)
      setServerError('Network error. Please check your connection and try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  // Username status indicator
  const renderUsernameStatus = () => {
    switch (usernameStatus) {
      case 'checking':
        return <SpinnerIcon />
      case 'available':
        return <CheckIcon />
      case 'taken':
      case 'invalid':
        return <XIcon />
      default:
        return <IconPlaceholder />
    }
  }

  // Helper to compute input class names
  const getInputClass = (hasError, hasSuccess) => {
    let className = 'signup-form__input'
    if (hasError) className += ' signup-form__input--error'
    else if (hasSuccess) className += ' signup-form__input--success'
    return className
  }

  if (compact) {
    return (
      <form onSubmit={handleSubmit} className="signup-form signup-form--compact">
        {serverError && <div className="signup-form__error-box">{serverError}</div>}

        <div className="signup-form__input-wrapper">
          <input
            type="text"
            placeholder="Username"
            value={username}
            onChange={handleUsernameChange}
            maxLength={20}
            autoComplete="username"
            required
            className={getInputClass(
              errors.username || usernameStatus === 'taken' || usernameStatus === 'invalid',
              usernameStatus === 'available'
            )}
          />
          {renderUsernameStatus()}
        </div>
        {(usernameStatus === 'taken' || usernameStatus === 'invalid' || errors.username) && (
          <div className="signup-form__field-error">
            {usernameStatus === 'taken' ? 'Username is already taken' :
             usernameStatus === 'invalid' ? 'Username contains invalid characters' :
             errors.username}
          </div>
        )}

        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          maxLength={240}
          autoComplete="email"
          required
          className={getInputClass(errors.email, false)}
        />
        {errors.email && <div className="signup-form__field-error">{errors.email}</div>}

        <div className="signup-form__input-wrapper">
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            required
            className={getInputClass(errors.password, false)}
          />
          {passwordsMatch ? <CheckIcon /> : <IconPlaceholder />}
        </div>
        {errors.password && <div className="signup-form__field-error">{errors.password}</div>}

        <div className="signup-form__input-wrapper">
          <input
            type="password"
            placeholder="Confirm Password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            required
            className={getInputClass(passwordsMismatch, passwordsMatch)}
          />
          {passwordsMatch ? <CheckIcon /> : passwordsMismatch ? <XIcon /> : <IconPlaceholder />}
        </div>
        {errors.confirmPassword && <div className="signup-form__field-error">{errors.confirmPassword}</div>}

        <button
          type="submit"
          disabled={isSubmitting || !isFormValid()}
          className="signup-form__btn"
        >
          {isSubmitting ? 'Creating account...' : 'Create Account'}
        </button>
      </form>
    )
  }

  // Full form layout (used by SignUp.js page - pass through isMobile for responsive)
  // This shouldn't typically be used since SignUp.js has its own layout
  return (
    <form onSubmit={handleSubmit} className="signup-form">
      {serverError && (
        <p className="signup-form__server-error">
          {serverError}
        </p>
      )}

      {/* Username */}
      <div className="signup-form__field">
        <label className="signup-form__label">
          <span className="signup-form__label-text">Username:</span>
          <input
            type="text"
            value={username}
            onChange={handleUsernameChange}
            maxLength={20}
            autoComplete="username"
            className={`signup-form__input--full ${
              (errors.username || usernameStatus === 'taken' || usernameStatus === 'invalid')
                ? 'signup-form__input--error'
                : usernameStatus === 'available'
                  ? 'signup-form__input--success'
                  : ''
            }`}
            required
          />
          {renderUsernameStatus()}
        </label>
      </div>

      {/* Email */}
      <div className="signup-form__field">
        <label className="signup-form__label">
          <span className="signup-form__label-text">Email:</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            maxLength={240}
            autoComplete="email"
            className={`signup-form__input--full ${errors.email ? 'signup-form__input--error' : ''}`}
            required
          />
        </label>
      </div>

      {/* Password */}
      <div className="signup-form__field">
        <label className="signup-form__label">
          <span className="signup-form__label-text">Password:</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            className={`signup-form__input--full ${errors.password ? 'signup-form__input--error' : ''}`}
            required
          />
          {passwordsMatch ? <CheckIcon /> : <IconPlaceholder />}
        </label>
      </div>

      {/* Confirm Password */}
      <div className="signup-form__field">
        <label className="signup-form__label">
          <span className="signup-form__label-text">Confirm Password:</span>
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            className={`signup-form__input--full ${
              passwordsMismatch
                ? 'signup-form__input--error'
                : passwordsMatch
                  ? 'signup-form__input--success'
                  : ''
            }`}
            required
          />
          {passwordsMatch ? <CheckIcon /> : passwordsMismatch ? <XIcon /> : <IconPlaceholder />}
        </label>
      </div>

      <button
        type="submit"
        disabled={isSubmitting || !isFormValid()}
        className="signup-form__submit"
      >
        {isSubmitting ? 'Creating account...' : 'Create new account'}
      </button>
    </form>
  )
}

export default SignUpForm

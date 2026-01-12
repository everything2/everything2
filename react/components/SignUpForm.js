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

// Fixed-width icon container to prevent layout shift
const iconContainerStyle = {
  display: 'inline-block',
  width: '24px',
  marginLeft: '8px',
  textAlign: 'center',
  verticalAlign: 'middle'
}

// Validation status icons
const CheckIcon = () => (
  <span style={iconContainerStyle}>
    <span style={{ color: '#228b22', fontSize: '1.1em' }} title="Match">&#10003;</span>
  </span>
)

const XIcon = () => (
  <span style={iconContainerStyle}>
    <span style={{ color: '#8b0000', fontSize: '1.1em' }} title="Does not match">&#10007;</span>
  </span>
)

const SpinnerIcon = () => (
  <span style={iconContainerStyle}>
    <span style={{ display: 'inline-block', animation: 'spin 1s linear infinite' }}>
      <span style={{ display: 'inline-block', width: '14px', height: '14px', border: '2px solid #d3d3d3', borderTopColor: '#4060b0', borderRadius: '50%' }} />
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </span>
  </span>
)

const IconPlaceholder = () => (
  <span style={iconContainerStyle}></span>
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

  // Compact styles for modal embedding
  const compactStyles = {
    form: {
      display: 'flex',
      flexDirection: 'column',
      gap: '12px'
    },
    inputWrapper: {
      display: 'flex',
      alignItems: 'center',
      gap: '4px'
    },
    input: {
      flex: 1,
      padding: '12px',
      border: '1px solid #e0e0e0',
      borderRadius: '6px',
      fontSize: '16px',
      outline: 'none',
      boxSizing: 'border-box'
    },
    inputError: {
      border: '1px solid #8b0000'
    },
    inputSuccess: {
      border: '1px solid #228b22'
    },
    error: {
      backgroundColor: '#ffebee',
      color: '#c62828',
      padding: '10px 12px',
      borderRadius: '4px',
      marginBottom: '8px',
      fontSize: '14px'
    },
    fieldError: {
      color: '#8b0000',
      fontSize: '12px',
      marginTop: '-8px',
      marginBottom: '4px'
    },
    button: {
      backgroundColor: '#4060b0',
      color: 'white',
      border: 'none',
      padding: '14px',
      borderRadius: '6px',
      fontSize: '16px',
      fontWeight: 500,
      cursor: 'pointer',
      marginTop: '4px'
    },
    buttonDisabled: {
      backgroundColor: '#a0b0c0',
      cursor: 'not-allowed'
    }
  }

  if (compact) {
    return (
      <form onSubmit={handleSubmit} style={compactStyles.form}>
        {serverError && <div style={compactStyles.error}>{serverError}</div>}

        <div style={compactStyles.inputWrapper}>
          <input
            type="text"
            placeholder="Username"
            value={username}
            onChange={handleUsernameChange}
            maxLength={20}
            autoComplete="username"
            required
            style={{
              ...compactStyles.input,
              ...(errors.username || usernameStatus === 'taken' || usernameStatus === 'invalid'
                ? compactStyles.inputError
                : usernameStatus === 'available'
                  ? compactStyles.inputSuccess
                  : {})
            }}
          />
          {renderUsernameStatus()}
        </div>
        {(usernameStatus === 'taken' || usernameStatus === 'invalid' || errors.username) && (
          <div style={compactStyles.fieldError}>
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
          style={{
            ...compactStyles.input,
            ...(errors.email ? compactStyles.inputError : {})
          }}
        />
        {errors.email && <div style={compactStyles.fieldError}>{errors.email}</div>}

        <div style={compactStyles.inputWrapper}>
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            required
            style={{
              ...compactStyles.input,
              ...(errors.password ? compactStyles.inputError : {})
            }}
          />
          {passwordsMatch ? <CheckIcon /> : <IconPlaceholder />}
        </div>
        {errors.password && <div style={compactStyles.fieldError}>{errors.password}</div>}

        <div style={compactStyles.inputWrapper}>
          <input
            type="password"
            placeholder="Confirm Password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            required
            style={{
              ...compactStyles.input,
              ...(passwordsMismatch
                ? compactStyles.inputError
                : passwordsMatch
                  ? compactStyles.inputSuccess
                  : {})
            }}
          />
          {passwordsMatch ? <CheckIcon /> : passwordsMismatch ? <XIcon /> : <IconPlaceholder />}
        </div>
        {errors.confirmPassword && <div style={compactStyles.fieldError}>{errors.confirmPassword}</div>}

        <button
          type="submit"
          disabled={isSubmitting || !isFormValid()}
          style={{
            ...compactStyles.button,
            ...((isSubmitting || !isFormValid()) ? compactStyles.buttonDisabled : {})
          }}
        >
          {isSubmitting ? 'Creating account...' : 'Create Account'}
        </button>
      </form>
    )
  }

  // Full form layout (used by SignUp.js page - pass through isMobile for responsive)
  // This shouldn't typically be used since SignUp.js has its own layout
  return (
    <form onSubmit={handleSubmit}>
      {serverError && (
        <p style={{
          color: '#8b0000',
          marginBottom: '1em',
          padding: '10px',
          backgroundColor: '#fff0f0',
          border: '1px solid #ffcccc',
          borderRadius: '4px'
        }}>
          {serverError}
        </p>
      )}

      {/* Username */}
      <div style={{ marginBottom: '0.75em' }}>
        <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '150px' }}>Username:</span>
          <input
            type="text"
            value={username}
            onChange={handleUsernameChange}
            maxLength={20}
            autoComplete="username"
            style={{
              padding: '6px 10px',
              border: (errors.username || usernameStatus === 'taken' || usernameStatus === 'invalid')
                ? '1px solid #8b0000'
                : usernameStatus === 'available'
                  ? '1px solid #228b22'
                  : '1px solid #d3d3d3',
              borderRadius: '4px',
              maxWidth: '220px'
            }}
            required
          />
          {renderUsernameStatus()}
        </label>
      </div>

      {/* Email */}
      <div style={{ marginBottom: '0.75em' }}>
        <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '150px' }}>Email:</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            maxLength={240}
            autoComplete="email"
            style={{
              padding: '6px 10px',
              border: errors.email ? '1px solid #8b0000' : '1px solid #d3d3d3',
              borderRadius: '4px',
              maxWidth: '220px'
            }}
            required
          />
        </label>
      </div>

      {/* Password */}
      <div style={{ marginBottom: '0.75em' }}>
        <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '150px' }}>Password:</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            style={{
              padding: '6px 10px',
              border: errors.password ? '1px solid #8b0000' : '1px solid #d3d3d3',
              borderRadius: '4px',
              maxWidth: '220px'
            }}
            required
          />
          {passwordsMatch ? <CheckIcon /> : <IconPlaceholder />}
        </label>
      </div>

      {/* Confirm Password */}
      <div style={{ marginBottom: '0.75em' }}>
        <label style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '150px' }}>Confirm Password:</span>
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            maxLength={240}
            autoComplete="new-password"
            style={{
              padding: '6px 10px',
              border: passwordsMismatch
                ? '1px solid #8b0000'
                : passwordsMatch
                  ? '1px solid #228b22'
                  : '1px solid #d3d3d3',
              borderRadius: '4px',
              maxWidth: '220px'
            }}
            required
          />
          {passwordsMatch ? <CheckIcon /> : passwordsMismatch ? <XIcon /> : <IconPlaceholder />}
        </label>
      </div>

      <button
        type="submit"
        disabled={isSubmitting || !isFormValid()}
        style={{
          padding: '10px 20px',
          backgroundColor: (isSubmitting || !isFormValid()) ? '#ccc' : '#4060b0',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: (isSubmitting || !isFormValid()) ? 'not-allowed' : 'pointer',
          fontSize: '1em',
          fontWeight: 'bold'
        }}
      >
        {isSubmitting ? 'Creating account...' : 'Create new account'}
      </button>
    </form>
  )
}

export default SignUpForm

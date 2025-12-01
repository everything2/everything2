import React, { useState, useEffect, useCallback } from 'react'

/**
 * SignUp - User registration form
 *
 * Features:
 * - Username availability checking via API
 * - Real-time password/email confirmation matching with checkmarks
 * - reCAPTCHA v3 integration (production only)
 * - API-based form submission (no page reload)
 * - Inline error display with specific messages
 *
 * Security:
 * - All validation/anti-spam logic stays server-side in signup API
 * - reCAPTCHA token generated fresh at submission time
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

// Empty placeholder to reserve space when no icon shown
const IconPlaceholder = () => (
  <span style={iconContainerStyle}></span>
)

const SignUp = ({ data, user, e2 }) => {
  const {
    username: initialUsername = '',
    email: initialEmail = '',
    use_recaptcha = false,
    recaptcha_v3_public_key = ''
  } = data

  // Form state
  const [username, setUsername] = useState(initialUsername)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [email, setEmail] = useState(initialEmail)
  const [confirmEmail, setConfirmEmail] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [recaptchaReady, setRecaptchaReady] = useState(!use_recaptcha)

  // Result state
  const [success, setSuccess] = useState(data.success || false)
  const [createdUsername, setCreatedUsername] = useState(data.username || '')
  const [linkValid, setLinkValid] = useState(data.linkvalid || 10)

  // Username availability state
  const [usernameStatus, setUsernameStatus] = useState('idle') // idle, checking, available, taken, invalid
  const [usernameCheckTimeout, setUsernameCheckTimeout] = useState(null)

  // Error state
  const [errors, setErrors] = useState({})
  const [serverError, setServerError] = useState('')

  // Load reCAPTCHA Enterprise script
  useEffect(() => {
    if (!use_recaptcha || !recaptcha_v3_public_key) {
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
    script.src = `https://www.google.com/recaptcha/enterprise.js?render=${recaptcha_v3_public_key}`
    script.async = true
    script.onload = markReady
    script.onerror = () => {
      console.error('Failed to load reCAPTCHA script')
      setRecaptchaReady(true) // Allow submission, server will reject
    }

    document.head.appendChild(script)
  }, [use_recaptcha, recaptcha_v3_public_key])

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
  const emailsMatch = email && confirmEmail && email === confirmEmail
  const emailsMismatch = email && confirmEmail && email !== confirmEmail

  // Check if form is valid
  const isFormValid = () => {
    return (
      recaptchaReady &&
      username &&
      usernameStatus === 'available' &&
      password &&
      passwordsMatch &&
      email &&
      emailsMatch
    )
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
    if (!confirmEmail) {
      newErrors.confirmEmail = 'Please confirm your email'
    } else if (email !== confirmEmail) {
      newErrors.confirmEmail = 'Email addresses do not match'
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
      if (use_recaptcha && recaptcha_v3_public_key) {
        const recaptcha = window.grecaptcha?.enterprise || window.grecaptcha
        if (!recaptcha) {
          setIsSubmitting(false)
          setServerError('reCAPTCHA is still loading. Please try again.')
          return
        }

        recaptchaToken = await new Promise((resolve, reject) => {
          recaptcha.ready(() => {
            recaptcha.execute(recaptcha_v3_public_key, { action: 'signup' })
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
        setSuccess(true)
        setCreatedUsername(result.username)
        setLinkValid(result.linkvalid || 10)
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

  // Success state
  if (success) {
    return (
      <div style={{ maxWidth: '40em', margin: '2em auto', padding: '0 1em' }}>
        <h3 style={{ color: '#38495e' }}>Welcome to Everything2, {createdUsername}</h3>
        <p>
          Your new user account has been created, and an email has been sent to the address you provided.
          You cannot use your account until you have followed the link in the email to activate it.
          This link will expire in {linkValid} days.
        </p>
        <p>
          The email contains some useful information, so please read it carefully, print it out on
          high-quality paper, and hang it on your wall in a tasteful frame.
        </p>
      </div>
    )
  }

  // Form state
  return (
    <div style={{ maxWidth: '40em', margin: '2em auto', padding: '0 1em' }}>
      <form onSubmit={handleSubmit}>
        <fieldset style={{
          border: '1px solid #d3d3d3',
          borderRadius: '4px',
          padding: '1.5em',
          margin: '1em 0'
        }}>
          <legend style={{
            padding: '0 0.5em',
            fontWeight: 'bold',
            color: '#38495e',
            fontSize: '1.2em'
          }}>
            Sign Up
          </legend>

          <p style={{ marginBottom: '1em', color: '#333' }}>
            Please fill in all fields
          </p>

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

          <div style={{ textAlign: 'right' }}>
            {/* Username */}
            <label style={{ display: 'block', marginBottom: '0.75em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Username:
              </span>
              <input
                type="text"
                value={username}
                onChange={handleUsernameChange}
                maxLength={20}
                size={30}
                autoComplete="username"
                style={{
                  padding: '4px 8px',
                  border: (errors.username || usernameStatus === 'taken' || usernameStatus === 'invalid')
                    ? '1px solid #8b0000'
                    : usernameStatus === 'available'
                      ? '1px solid #228b22'
                      : '1px solid #d3d3d3',
                  borderRadius: '3px'
                }}
                required
              />
              {renderUsernameStatus()}
            </label>
            {usernameStatus === 'taken' && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                Username is already taken
              </div>
            )}
            {usernameStatus === 'invalid' && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                Username contains invalid characters
              </div>
            )}
            {errors.username && usernameStatus !== 'taken' && usernameStatus !== 'invalid' && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                {errors.username}
              </div>
            )}

            {/* Password */}
            <label style={{ display: 'block', marginBottom: '0.75em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Password:
              </span>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                maxLength={240}
                size={30}
                autoComplete="new-password"
                style={{
                  padding: '4px 8px',
                  border: errors.password ? '1px solid #8b0000' : '1px solid #d3d3d3',
                  borderRadius: '3px'
                }}
                required
              />
              {passwordsMatch ? <CheckIcon /> : <IconPlaceholder />}
            </label>
            {errors.password && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                {errors.password}
              </div>
            )}

            {/* Confirm Password */}
            <label style={{ display: 'block', marginBottom: '0.75em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Confirm password:
              </span>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                maxLength={240}
                size={30}
                autoComplete="new-password"
                style={{
                  padding: '4px 8px',
                  border: passwordsMismatch
                    ? '1px solid #8b0000'
                    : passwordsMatch
                      ? '1px solid #228b22'
                      : '1px solid #d3d3d3',
                  borderRadius: '3px'
                }}
                required
              />
              {passwordsMatch ? <CheckIcon /> : passwordsMismatch ? <XIcon /> : <IconPlaceholder />}
            </label>
            {errors.confirmPassword && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                {errors.confirmPassword}
              </div>
            )}

            {/* Email */}
            <label style={{ display: 'block', marginBottom: '0.75em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Email address:
              </span>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                maxLength={240}
                size={30}
                autoComplete="email"
                style={{
                  padding: '4px 8px',
                  border: errors.email ? '1px solid #8b0000' : '1px solid #d3d3d3',
                  borderRadius: '3px'
                }}
                required
              />
              {emailsMatch ? <CheckIcon /> : <IconPlaceholder />}
            </label>
            {errors.email && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                {errors.email}
              </div>
            )}

            {/* Confirm Email */}
            <label style={{ display: 'block', marginBottom: '1em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Confirm email:
              </span>
              <input
                type="email"
                value={confirmEmail}
                onChange={(e) => setConfirmEmail(e.target.value)}
                maxLength={240}
                size={30}
                autoComplete="email"
                style={{
                  padding: '4px 8px',
                  border: emailsMismatch
                    ? '1px solid #8b0000'
                    : emailsMatch
                      ? '1px solid #228b22'
                      : '1px solid #d3d3d3',
                  borderRadius: '3px'
                }}
                required
              />
              {emailsMatch ? <CheckIcon /> : emailsMismatch ? <XIcon /> : <IconPlaceholder />}
            </label>
            {errors.confirmEmail && (
              <div style={{ color: '#8b0000', fontSize: '0.9em', marginBottom: '0.5em', textAlign: 'left', paddingLeft: '155px' }}>
                {errors.confirmEmail}
              </div>
            )}

            <button
              type="submit"
              disabled={isSubmitting || !isFormValid()}
              style={{
                padding: '8px 16px',
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
          </div>
        </fieldset>
      </form>

      {/* Policies */}
      <div style={{ fontSize: '0.95em', lineHeight: '1.6' }}>
        <h4 style={{ color: '#38495e', marginTop: '2em' }}>Email Privacy Policy</h4>
        <p>
          We will only use your email to send you an account activation email and for any other
          email services that you specifically request. It will not be disclosed to anyone else.
        </p>

        <h4 style={{ color: '#38495e', marginTop: '2em' }}>Spam Policy</h4>
        <p>We neither perpetrate nor tolerate spam.</p>
        <p>
          New accounts advertizing any product, service or web site (including "personal" sites
          and blogs) in their posts or in their profile are subject to immediate deletion. Their
          details may be submitted to public blacklists for the use of other web sites.
        </p>

        <h4 style={{ color: '#38495e', marginTop: '2em' }}>Underage users</h4>
        <p>
          Everything2 may include member-created content designed for an adult audience. Viewing
          this content does not require an account. For logged-in account holders, Everything2
          may display text conversations conducted by adults and intended for an adult audience.
          On-site communications are not censored or restricted by default. Users under the age
          of 18 are advised that they should expect to be interacting primarily with adults and
          that the site may not be considered appropriate by their parents, guardians, or other
          powers-that-be. Everything2 is not intended for use by children under the age of 13 and
          does not include any features or content designed to appeal to children of that age.
        </p>
      </div>
    </div>
  )
}

export default SignUp

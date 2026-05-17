import React, { useState, useEffect, useCallback } from 'react'
import { useIsMobile } from '../../hooks/useMediaQuery'

/**
 * SignUp - User registration form
 *
 * Features:
 * - Username availability checking via API
 * - Real-time password/email confirmation matching with checkmarks
 * - reCAPTCHA v3 integration (production only)
 * - API-based form submission (no page reload)
 * - Inline error display with specific messages
 * - Responsive layout (stacked on mobile, side-by-side on desktop)
 *
 * Security:
 * - All validation/anti-spam logic stays server-side in signup API
 * - reCAPTCHA token generated fresh at submission time
 */

// Validation status icons
const CheckIcon = () => (
  <span className="signup__icon-container">
    <span className="signup__icon--check" title="Match">&#10003;</span>
  </span>
)

const XIcon = () => (
  <span className="signup__icon-container">
    <span className="signup__icon--x" title="Does not match">&#10007;</span>
  </span>
)

const SpinnerIcon = () => (
  <span className="signup__icon-container">
    <span className="signup__spinner-wrapper">
      <span className="signup__spinner" />
    </span>
  </span>
)

// Empty placeholder to reserve space when no icon shown
const IconPlaceholder = () => (
  <span className="signup__icon-container"></span>
)

const SignUp = ({ data, user, e2 }) => {
  const isMobile = useIsMobile()
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

  // Helper to build input class names
  const getInputClassName = (hasError, hasSuccess) => {
    const classes = ['signup__input']
    if (isMobile) classes.push('signup__input--mobile')
    if (hasError) classes.push('signup__input--error')
    if (hasSuccess) classes.push('signup__input--success')
    return classes.join(' ')
  }

  // Success state
  if (success) {
    return (
      <div className="signup">
        <h3 className="signup__success-title">Welcome to Everything2, {createdUsername}</h3>
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
    <div className="signup">
      <form onSubmit={handleSubmit}>
        <fieldset className="signup__fieldset">
          <legend className="signup__legend">Sign Up</legend>

          <p className="signup__instructions">Please fill in all fields</p>

          {serverError && (
            <p className="signup__server-error">{serverError}</p>
          )}

          <div className={isMobile ? 'signup__fields signup__fields--mobile' : 'signup__fields'}>
            {/* Username */}
            <div className="signup__row">
              <label className={isMobile ? 'signup__label signup__label--mobile' : 'signup__label'}>
                <span className={isMobile ? 'signup__label-text signup__label-text--mobile' : 'signup__label-text'}>
                  Username:
                </span>
                <span className={isMobile ? 'signup__input-wrapper signup__input-wrapper--mobile' : 'signup__input-wrapper'}>
                  <input
                    type="text"
                    value={username}
                    onChange={handleUsernameChange}
                    maxLength={20}
                    autoComplete="username"
                    className={getInputClassName(
                      errors.username || usernameStatus === 'taken' || usernameStatus === 'invalid',
                      usernameStatus === 'available'
                    )}
                    required
                  />
                  {renderUsernameStatus()}
                </span>
              </label>
            </div>
            {usernameStatus === 'taken' && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                Username is already taken
              </div>
            )}
            {usernameStatus === 'invalid' && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                Username contains invalid characters
              </div>
            )}
            {errors.username && usernameStatus !== 'taken' && usernameStatus !== 'invalid' && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                {errors.username}
              </div>
            )}

            {/* Password */}
            <div className="signup__row">
              <label className={isMobile ? 'signup__label signup__label--mobile' : 'signup__label'}>
                <span className={isMobile ? 'signup__label-text signup__label-text--mobile' : 'signup__label-text'}>
                  Password:
                </span>
                <span className={isMobile ? 'signup__input-wrapper signup__input-wrapper--mobile' : 'signup__input-wrapper'}>
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    maxLength={240}
                    autoComplete="new-password"
                    className={getInputClassName(errors.password, false)}
                    required
                  />
                  {passwordsMatch ? <CheckIcon /> : <IconPlaceholder />}
                </span>
              </label>
            </div>
            {errors.password && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                {errors.password}
              </div>
            )}

            {/* Confirm Password */}
            <div className="signup__row">
              <label className={isMobile ? 'signup__label signup__label--mobile' : 'signup__label'}>
                <span className={isMobile ? 'signup__label-text signup__label-text--mobile' : 'signup__label-text'}>
                  Confirm password:
                </span>
                <span className={isMobile ? 'signup__input-wrapper signup__input-wrapper--mobile' : 'signup__input-wrapper'}>
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    maxLength={240}
                    autoComplete="new-password"
                    className={getInputClassName(passwordsMismatch, passwordsMatch)}
                    required
                  />
                  {passwordsMatch ? <CheckIcon /> : passwordsMismatch ? <XIcon /> : <IconPlaceholder />}
                </span>
              </label>
            </div>
            {errors.confirmPassword && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                {errors.confirmPassword}
              </div>
            )}

            {/* Email */}
            <div className="signup__row">
              <label className={isMobile ? 'signup__label signup__label--mobile' : 'signup__label'}>
                <span className={isMobile ? 'signup__label-text signup__label-text--mobile' : 'signup__label-text'}>
                  Email address:
                </span>
                <span className={isMobile ? 'signup__input-wrapper signup__input-wrapper--mobile' : 'signup__input-wrapper'}>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    maxLength={240}
                    autoComplete="email"
                    className={getInputClassName(errors.email, false)}
                    required
                  />
                  {emailsMatch ? <CheckIcon /> : <IconPlaceholder />}
                </span>
              </label>
            </div>
            {errors.email && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                {errors.email}
              </div>
            )}

            {/* Confirm Email */}
            <div className="signup__row signup__row--last">
              <label className={isMobile ? 'signup__label signup__label--mobile' : 'signup__label'}>
                <span className={isMobile ? 'signup__label-text signup__label-text--mobile' : 'signup__label-text'}>
                  Confirm email:
                </span>
                <span className={isMobile ? 'signup__input-wrapper signup__input-wrapper--mobile' : 'signup__input-wrapper'}>
                  <input
                    type="email"
                    value={confirmEmail}
                    onChange={(e) => setConfirmEmail(e.target.value)}
                    maxLength={240}
                    autoComplete="email"
                    className={getInputClassName(emailsMismatch, emailsMatch)}
                    required
                  />
                  {emailsMatch ? <CheckIcon /> : emailsMismatch ? <XIcon /> : <IconPlaceholder />}
                </span>
              </label>
            </div>
            {errors.confirmEmail && (
              <div className={isMobile ? 'signup__field-error signup__field-error--mobile' : 'signup__field-error'}>
                {errors.confirmEmail}
              </div>
            )}

            <button
              type="submit"
              disabled={isSubmitting || !isFormValid()}
              className={isMobile ? 'signup__submit signup__submit--mobile' : 'signup__submit'}
            >
              {isSubmitting ? 'Creating account...' : 'Create new account'}
            </button>
          </div>
        </fieldset>
      </form>

      {/* Policies */}
      <div className="signup__policies">
        <h4 className="signup__policy-title">Email Privacy Policy</h4>
        <p>
          We will only use your email to send you an account activation email and for any other
          email services that you specifically request. It will not be disclosed to anyone else.
        </p>

        <h4 className="signup__policy-title">Spam Policy</h4>
        <p>We neither perpetrate nor tolerate spam.</p>
        <p>
          New accounts advertizing any product, service or web site (including "personal" sites
          and blogs) in their posts or in their profile are subject to immediate deletion. Their
          details may be submitted to public blacklists for the use of other web sites.
        </p>

        <h4 className="signup__policy-title">Underage users</h4>
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

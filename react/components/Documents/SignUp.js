import React, { useState, useEffect, useCallback } from 'react'

/**
 * SignUp - User registration form
 *
 * Features:
 * - Username availability checking via API
 * - Real-time password/email confirmation matching with checkmarks
 * - reCAPTCHA v3 integration (production only)
 * - Form signature (CSRF protection)
 * - Success state with activation instructions
 *
 * Security:
 * - All validation/anti-spam logic stays server-side in sign_up.pm
 * - Field hashing for password/email confirmation
 * - reCAPTCHA token submitted with form
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
    prompt: initialPrompt = 'Please fill in all fields',
    username: initialUsername = '',
    email: initialEmail = '',
    formtime,
    formsignature,
    email_confirm_field,
    pass_confirm_field,
    use_recaptcha = false,
    recaptcha_v3_public_key = '',
    success = false,
    linkvalid = 0
  } = data

  // Form state
  const [username, setUsername] = useState(initialUsername)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [email, setEmail] = useState(initialEmail)
  const [confirmEmail, setConfirmEmail] = useState('')
  const [recaptchaToken, setRecaptchaToken] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [recaptchaReady, setRecaptchaReady] = useState(!use_recaptcha) // Ready immediately if not using reCAPTCHA

  // Username availability state
  const [usernameStatus, setUsernameStatus] = useState('idle') // idle, checking, available, taken, invalid
  const [usernameCheckTimeout, setUsernameCheckTimeout] = useState(null)

  // Client-side validation state
  const [errors, setErrors] = useState({})

  // Load reCAPTCHA Enterprise script and mark ready when loaded
  useEffect(() => {
    if (!use_recaptcha || !recaptcha_v3_public_key) {
      setRecaptchaReady(true)
      return
    }

    const markReady = () => {
      // reCAPTCHA Enterprise uses grecaptcha.enterprise
      const recaptcha = window.grecaptcha?.enterprise || window.grecaptcha
      if (recaptcha) {
        recaptcha.ready(() => {
          console.log('reCAPTCHA is ready')
          setRecaptchaReady(true)
        })
      }
    }

    // Check if script already loaded
    if (window.grecaptcha) {
      markReady()
      return
    }

    // Load the Enterprise script
    const script = document.createElement('script')
    script.src = `https://www.google.com/recaptcha/enterprise.js?render=${recaptcha_v3_public_key}`
    script.async = true

    // Mark ready after script loads
    script.onload = () => {
      markReady()
    }

    script.onerror = () => {
      console.error('Failed to load reCAPTCHA Enterprise script')
      // Still allow form submission - server will reject if token missing
      setRecaptchaReady(true)
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
      const data = await response.json()

      if (data.available) {
        setUsernameStatus('available')
      } else if (data.reason === 'invalid_format') {
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

    // Clear existing timeout
    if (usernameCheckTimeout) {
      clearTimeout(usernameCheckTimeout)
    }

    // Set new timeout for API call (500ms debounce)
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

  // Check initial username availability on mount (for pre-populated form after error)
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

  // Check if form is valid for submission
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

    // Username validation
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

    // Password validation
    if (!password) {
      newErrors.password = 'Password is required'
    }
    if (!confirmPassword) {
      newErrors.confirmPassword = 'Please confirm your password'
    } else if (password !== confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match'
    }

    // Email validation
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

  const handleSubmit = async (e) => {
    // Always prevent default - we'll submit programmatically after getting fresh token
    e.preventDefault()

    // Validate client-side first
    if (!validateForm()) {
      return
    }

    setIsSubmitting(true)

    // If reCAPTCHA is enabled, get a fresh token right before submission
    // Tokens expire after ~2 minutes, so we must generate fresh ones
    if (use_recaptcha && recaptcha_v3_public_key) {
      try {
        const recaptcha = window.grecaptcha?.enterprise || window.grecaptcha
        if (recaptcha) {
          const freshToken = await new Promise((resolve, reject) => {
            recaptcha.ready(() => {
              recaptcha.execute(recaptcha_v3_public_key, { action: 'signup' })
                .then(resolve)
                .catch(reject)
            })
          })
          console.log('Fresh reCAPTCHA token generated, length:', freshToken.length)
          setRecaptchaToken(freshToken)

          // Update the hidden field directly since state update is async
          const form = document.getElementById('signupform')
          const tokenInput = form.querySelector('input[name="recaptcha_token"]')
          if (tokenInput) {
            tokenInput.value = freshToken
          }
        }
      } catch (err) {
        console.error('Failed to generate fresh reCAPTCHA token:', err)
        setIsSubmitting(false)
        setErrors({ submit: 'Failed to verify you are human. Please try again.' })
        return
      }
    }

    // Now submit the form
    document.getElementById('signupform').submit()
  }

  // Username status indicator
  const renderUsernameStatus = () => {
    switch (usernameStatus) {
      case 'checking':
        return <SpinnerIcon />
      case 'available':
        return <CheckIcon />
      case 'taken':
        return <XIcon />
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
        <h3 style={{ color: '#38495e' }}>Welcome to Everything2, {username}</h3>
        <p>
          Your new user account has been created, and an email has been sent to the address you provided.
          You cannot use your account until you have followed the link in the email to activate it.
          This link will expire in {linkvalid} days.
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
      <form id="signupform" method="POST" onSubmit={handleSubmit}>
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

          {initialPrompt && (
            <p style={{
              color: initialPrompt.includes('rejected') || initialPrompt.includes('error') ? '#8b0000' : '#333',
              marginBottom: '1em'
            }}>
              {initialPrompt}
            </p>
          )}

          {errors.submit && (
            <p style={{ color: '#8b0000', marginBottom: '1em' }}>{errors.submit}</p>
          )}

          <div style={{ textAlign: 'right' }}>
            {/* Username */}
            <label style={{ display: 'block', marginBottom: '0.75em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Username:
              </span>
              <input
                type="text"
                name="username"
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
                name="pass"
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

            {/* Confirm Password - field name is server-generated hash */}
            <label style={{ display: 'block', marginBottom: '0.75em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Confirm password:
              </span>
              <input
                type="password"
                name={pass_confirm_field}
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
                name="email"
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

            {/* Confirm Email - field name is server-generated hash */}
            <label style={{ display: 'block', marginBottom: '1em' }}>
              <span style={{ display: 'inline-block', width: '150px', textAlign: 'left' }}>
                Confirm email:
              </span>
              <input
                type="email"
                name={email_confirm_field}
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

            {/* Node ID - required for POST routing */}
            <input type="hidden" name="node_id" value={e2?.node_id} />

            {/* Form time and signature (CSRF protection) - server-provided values */}
            <input type="hidden" name="formtime" value={formtime} />
            <input type="hidden" name="formsignature" value={formsignature} />

            {/* reCAPTCHA token */}
            {Boolean(use_recaptcha) && (
              <input type="hidden" name="recaptcha_token" value={recaptchaToken} />
            )}

            <input
              type="submit"
              name="beseech"
              value="Create new account"
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
            />
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

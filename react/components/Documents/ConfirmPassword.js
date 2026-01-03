import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '400px',
    margin: '50px auto',
    padding: '20px',
  },
  fieldset: {
    border: '1px solid #ccc',
    borderRadius: '8px',
    padding: '20px',
  },
  legend: {
    fontWeight: 'bold',
    fontSize: '1.2rem',
    padding: '0 10px',
  },
  prompt: {
    marginBottom: '20px',
    lineHeight: '1.5',
  },
  formGroup: {
    marginBottom: '15px',
    textAlign: 'right',
  },
  label: {
    display: 'block',
    marginBottom: '10px',
  },
  labelText: {
    display: 'inline-block',
    width: '80px',
    textAlign: 'left',
  },
  input: {
    padding: '8px',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    width: '200px',
  },
  inputReadonly: {
    padding: '8px',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    width: '200px',
    backgroundColor: '#f8f9fa',
  },
  checkboxGroup: {
    marginBottom: '15px',
    textAlign: 'center',
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
  },
  buttonDisabled: {
    backgroundColor: '#999',
    cursor: 'not-allowed',
  },
  message: {
    padding: '20px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    textAlign: 'center',
    lineHeight: '1.6',
  },
  success: {
    padding: '20px',
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '8px',
    lineHeight: '1.6',
  },
  error: {
    padding: '20px',
    backgroundColor: '#f8d7da',
    border: '1px solid #f5c6cb',
    borderRadius: '8px',
    lineHeight: '1.6',
  },
  link: {
    color: '#007bff',
    textDecoration: 'none',
  },
}

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
      <div style={styles.container}>
        <div style={styles.message}>
          <p>{message}</p>
        </div>
      </div>
    )
  }

  // Invalid action
  if (state === 'invalid_action') {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{error}</p>
        </div>
      </div>
    )
  }

  // Link expired
  if (state === 'expired') {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{message}{' '}
          {renewLink && (
            <>But you can <a href={renewLink} style={styles.link}>{renewLabel}</a>.</>
          )}
          </p>
        </div>
      </div>
    )
  }

  // User not found
  if (state === 'no_user') {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{message}{' '}
          {signupLink && (
            <>But you can <a href={signupLink} style={styles.link}>create a new one</a>.</>
          )}
          </p>
        </div>
      </div>
    )
  }

  // Locked account
  if (state === 'locked') {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{error}</p>
        </div>
      </div>
    )
  }

  // Success - password reset
  if (state === 'success_reset') {
    return (
      <div style={styles.container}>
        <div style={styles.success}>
          <p>{message}</p>
        </div>
      </div>
    )
  }

  // Success - account activated
  if (state === 'success_activate') {
    return (
      <div style={styles.container}>
        <div style={styles.success}>
          <p>{message}</p>
          <p>
            Perhaps you'd like to edit{' '}
            <a href={profileUrl} style={styles.link}>your profile</a>,
            or check out the logged-in users'{' '}
            <a href="/" style={styles.link}>front page</a>,
            or maybe just read{' '}
            <a href="/?op=randomnode" style={styles.link}>something at random</a>.
          </p>
        </div>
      </div>
    )
  }

  // Login required
  if (state === 'login_required') {
    return (
      <div style={styles.container}>
        <form method="POST" action="/index.pl" onSubmit={handleSubmit}>
          <fieldset style={styles.fieldset}>
            <legend style={styles.legend}>Log in</legend>

            <p style={styles.prompt}>{prompt}:</p>

            <div style={styles.formGroup}>
              <label style={styles.label}>
                <span style={styles.labelText}>Username:</span>
                <input
                  type="text"
                  name="user"
                  value={username}
                  readOnly
                  style={styles.inputReadonly}
                />
              </label>
              <label style={styles.label}>
                <span style={styles.labelText}>Password:</span>
                <input
                  type="password"
                  name="passwd"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={styles.input}
                  autoFocus
                />
              </label>
            </div>

            <div style={styles.checkboxGroup}>
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

            <div style={{ textAlign: 'center' }}>
              <button
                type="submit"
                name="sockItToMe"
                disabled={loading || !password.trim()}
                style={{
                  ...styles.button,
                  ...(loading || !password.trim() ? styles.buttonDisabled : {}),
                }}
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
    <div style={styles.container}>
      <div style={styles.message}>
        <p>Loading...</p>
      </div>
    </div>
  )
}

export default ConfirmPassword

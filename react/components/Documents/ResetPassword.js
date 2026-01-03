import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '400px',
    margin: '3em auto 0',
    padding: '20px',
  },
  fieldset: {
    border: '1px solid #ccc',
    borderRadius: '8px',
    padding: '20px',
  },
  legend: {
    fontSize: '1.2rem',
    fontWeight: 'bold',
    padding: '0 10px',
  },
  description: {
    marginBottom: '20px',
    lineHeight: '1.5',
    color: '#666',
  },
  formGroup: {
    marginBottom: '15px',
  },
  label: {
    display: 'block',
    marginBottom: '5px',
    fontWeight: 'bold',
    fontSize: '14px',
  },
  input: {
    width: '100%',
    padding: '10px',
    fontSize: '16px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    boxSizing: 'border-box',
  },
  button: {
    width: '100%',
    padding: '12px',
    backgroundColor: '#5a9fd4',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
    marginTop: '10px',
  },
  buttonDisabled: {
    backgroundColor: '#999',
    cursor: 'not-allowed',
  },
  error: {
    padding: '10px',
    backgroundColor: '#f8d7da',
    color: '#721c24',
    borderRadius: '4px',
    marginBottom: '15px',
  },
  success: {
    padding: '20px',
    backgroundColor: '#d4edda',
    color: '#155724',
    borderRadius: '4px',
    textAlign: 'center',
    lineHeight: '1.5',
  },
}

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
      <div style={styles.container}>
        <div style={styles.success}>
          <strong>{success}</strong>
          <p style={{ marginTop: '10px', marginBottom: 0 }}>
            Check your email for the confirmation link.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <form onSubmit={handleSubmit}>
        <fieldset style={styles.fieldset}>
          <legend style={styles.legend}>Choose new password</legend>

          <p style={styles.description}>
            Forgotten your password? Fill in your user name or email address here and choose
            a new password, and we will send you an email containing a link to reset it.
          </p>

          {error && <div style={styles.error}>{error}</div>}

          <div style={styles.formGroup}>
            <label style={styles.label} htmlFor="who">
              Username or email address:
            </label>
            <input
              type="text"
              id="who"
              value={who}
              onChange={(e) => setWho(e.target.value)}
              style={styles.input}
              maxLength={240}
              disabled={loading}
              autoComplete="username"
            />
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label} htmlFor="password">
              New password:
            </label>
            <input
              type="password"
              id="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={styles.input}
              maxLength={240}
              disabled={loading}
              autoComplete="new-password"
            />
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label} htmlFor="passwordConfirm">
              Repeat new password:
            </label>
            <input
              type="password"
              id="passwordConfirm"
              value={passwordConfirm}
              onChange={(e) => setPasswordConfirm(e.target.value)}
              style={styles.input}
              maxLength={240}
              disabled={loading}
              autoComplete="new-password"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            style={{
              ...styles.button,
              ...(loading ? styles.buttonDisabled : {})
            }}
          >
            {loading ? 'Sending...' : 'Submit'}
          </button>
        </fieldset>
      </form>
    </div>
  )
}

export default ResetPassword

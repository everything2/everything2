import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '700px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  intro: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  form: {
    padding: '20px',
    backgroundColor: '#fff',
    border: '1px solid #ddd',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  formGroup: {
    marginBottom: '20px',
  },
  label: {
    display: 'block',
    fontWeight: 'bold',
    marginBottom: '8px',
  },
  select: {
    padding: '8px 12px',
    fontSize: '16px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    width: '100%',
    maxWidth: '300px',
  },
  radioGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  radioLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    cursor: 'pointer',
  },
  input: {
    padding: '8px 12px',
    fontSize: '16px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    width: '100%',
    maxWidth: '300px',
  },
  adminNote: {
    fontSize: '12px',
    color: '#666',
    fontStyle: 'italic',
  },
  button: {
    padding: '12px 24px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  buttonDisabled: {
    backgroundColor: '#999',
    cursor: 'not-allowed',
  },
  error: {
    padding: '15px',
    backgroundColor: '#f8d7da',
    color: '#721c24',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  success: {
    padding: '20px',
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  downloadLink: {
    display: 'block',
    marginTop: '10px',
    wordBreak: 'break-all',
    color: '#007bff',
  },
  warning: {
    marginTop: '15px',
    padding: '10px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    fontSize: '14px',
  },
  notice: {
    marginTop: '15px',
    padding: '10px',
    backgroundColor: '#cce5ff',
    border: '1px solid #b8daff',
    borderRadius: '4px',
    fontSize: '14px',
  },
  devNotice: {
    padding: '20px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '8px',
    textAlign: 'center',
  },
}

const NodeBackup = ({ data }) => {
  const backupData = data || {}
  const { isAdmin, isDevelopment } = backupData

  const [contentType, setContentType] = useState('both')
  const [format, setFormat] = useState('both')
  const [forNoder, setForNoder] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [result, setResult] = useState(null)

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    setResult(null)

    try {
      const body = {
        contentType,
        format,
      }
      if (forNoder.trim() && isAdmin) {
        body.forNoder = forNoder.trim()
      }

      const response = await fetch('/api/nodebackup/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(body),
      })

      const data = await response.json()

      if (data.success) {
        setResult(data)
      } else {
        setError(data.error || 'Failed to create backup')
      }
    } catch (err) {
      setError('Failed to connect to server')
    } finally {
      setLoading(false)
    }
  }, [contentType, format, forNoder, isAdmin])

  if (isDevelopment) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Node Backup</h1>
        </div>
        <div style={styles.devNotice}>
          <p><strong>Node backup is not available in the development environment.</strong></p>
          <p>This feature requires AWS S3 access for storing backups, which is only configured in production.</p>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Node Backup</h1>
      </div>

      <div style={styles.intro}>
        <p>Welcome to the node backup utility. Here you can download all of your writeups
        and/or drafts in a handy zipfile.</p>
      </div>

      {error && <div style={styles.error}>{error}</div>}

      {result ? (
        <div style={styles.success}>
          <p><strong>Your backup is ready!</strong></p>
          <p>You can download it here:</p>
          <a href={result.downloadUrl} style={styles.downloadLink}>
            {result.downloadUrl}
          </a>
          <div style={styles.notice}>
            <p>This link is public in the sense that anyone with the URL can download it,
            and will last for 7 days, after which it will be automatically deleted.</p>
            <p><strong>This is the only time you will see this link, so download it now.</strong></p>
          </div>
          {result.warning && (
            <div style={styles.warning}>{result.warning}</div>
          )}
          <p style={{ marginTop: '15px' }}>
            <button
              onClick={() => setResult(null)}
              style={styles.button}
            >
              Create Another Backup
            </button>
          </p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} style={styles.form}>
          <div style={styles.formGroup}>
            <label style={styles.label}>Back up:</label>
            <select
              value={contentType}
              onChange={(e) => setContentType(e.target.value)}
              style={styles.select}
              disabled={loading}
            >
              <option value="both">Writeups and Drafts</option>
              <option value="writeups">Writeups only</option>
              <option value="drafts">Drafts only</option>
            </select>
          </div>

          <div style={styles.formGroup}>
            <label style={styles.label}>Format:</label>
            <div style={styles.radioGroup}>
              <label style={styles.radioLabel}>
                <input
                  type="radio"
                  name="format"
                  value="raw"
                  checked={format === 'raw'}
                  onChange={(e) => setFormat(e.target.value)}
                  disabled={loading}
                />
                ...as you typed them (plain text)
              </label>
              <label style={styles.radioLabel}>
                <input
                  type="radio"
                  name="format"
                  value="html"
                  checked={format === 'html'}
                  onChange={(e) => setFormat(e.target.value)}
                  disabled={loading}
                />
                ...as E2 renders them (HTML)
              </label>
              <label style={styles.radioLabel}>
                <input
                  type="radio"
                  name="format"
                  value="both"
                  checked={format === 'both'}
                  onChange={(e) => setFormat(e.target.value)}
                  disabled={loading}
                />
                ...in both formats
              </label>
            </div>
          </div>

          {isAdmin && (
            <div style={styles.formGroup}>
              <label style={styles.label}>
                For noder: <span style={styles.adminNote}>(admin only)</span>
              </label>
              <input
                type="text"
                value={forNoder}
                onChange={(e) => setForNoder(e.target.value)}
                placeholder="Leave blank for your own backup"
                style={styles.input}
                disabled={loading}
              />
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            style={{
              ...styles.button,
              ...(loading ? styles.buttonDisabled : {}),
            }}
          >
            {loading ? 'Creating backup...' : 'Create Backup'}
          </button>
        </form>
      )}
    </div>
  )
}

export default NodeBackup

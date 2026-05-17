import React, { useState, useCallback } from 'react'

/**
 * NodeBackup - Node backup utility
 * Styles in CSS: .node-backup__*
 *
 * Allows users to download backups of their writeups and/or drafts.
 */
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
      <div className="node-backup">
        <div className="node-backup__header">
          <h1 className="node-backup__title">Node Backup</h1>
        </div>
        <div className="node-backup__dev-notice">
          <p><strong>Node backup is not available in the development environment.</strong></p>
          <p>This feature requires AWS S3 access for storing backups, which is only configured in production.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="node-backup">
      <div className="node-backup__header">
        <h1 className="node-backup__title">Node Backup</h1>
      </div>

      <div className="node-backup__intro">
        <p>Welcome to the node backup utility. Here you can download all of your writeups
        and/or drafts in a handy zipfile.</p>
      </div>

      {error && <div className="node-backup__error">{error}</div>}

      {result ? (
        <div className="node-backup__success">
          <p><strong>Your backup is ready!</strong></p>
          <p>You can download it here:</p>
          <a href={result.downloadUrl} className="node-backup__download-link">
            {result.downloadUrl}
          </a>
          <div className="node-backup__notice">
            <p>This link is public in the sense that anyone with the URL can download it,
            and will last for 7 days, after which it will be automatically deleted.</p>
            <p><strong>This is the only time you will see this link, so download it now.</strong></p>
          </div>
          {result.warning && (
            <div className="node-backup__warning">{result.warning}</div>
          )}
          <p className="node-backup__create-another">
            <button
              onClick={() => setResult(null)}
              className="node-backup__button"
            >
              Create Another Backup
            </button>
          </p>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="node-backup__form">
          <div className="node-backup__form-group">
            <label className="node-backup__label">Back up:</label>
            <select
              value={contentType}
              onChange={(e) => setContentType(e.target.value)}
              className="node-backup__select"
              disabled={loading}
            >
              <option value="both">Writeups and Drafts</option>
              <option value="writeups">Writeups only</option>
              <option value="drafts">Drafts only</option>
            </select>
          </div>

          <div className="node-backup__form-group">
            <label className="node-backup__label">Format:</label>
            <div className="node-backup__radio-group">
              <label className="node-backup__radio-label">
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
              <label className="node-backup__radio-label">
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
              <label className="node-backup__radio-label">
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
            <div className="node-backup__form-group">
              <label className="node-backup__label">
                For noder: <span className="node-backup__admin-note">(admin only)</span>
              </label>
              <input
                type="text"
                value={forNoder}
                onChange={(e) => setForNoder(e.target.value)}
                placeholder="Leave blank for your own backup"
                className="node-backup__input"
                disabled={loading}
              />
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className={`node-backup__button ${loading ? 'node-backup__button--disabled' : ''}`}
          >
            {loading ? 'Creating backup...' : 'Create Backup'}
          </button>
        </form>
      )}
    </div>
  )
}

export default NodeBackup

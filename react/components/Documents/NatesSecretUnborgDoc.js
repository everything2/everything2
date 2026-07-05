import React, { useState } from 'react'

/**
 * NatesSecretUnborgDoc - Instant unborg tool for admins (#4468).
 * Styles in CSS: .nates-secret-unborg-doc__*
 *
 * The unborg moved to POST /api/nate_s_secret_unborg_doc/unborg (was a GET-mutation).
 * On success the page is reloaded: the borg state that gates the chrome (Chatterbox
 * countdown, chat input) is baked into e2.node by buildNodeInfoStructure at load time, so
 * only a fresh load re-enables chat.
 */
const NatesSecretUnborgDoc = ({ data }) => {
  const { is_admin, message: initialMessage } = data

  const [message, setMessage] = useState(initialMessage || '')
  const [loading, setLoading] = useState(false)

  if (!is_admin) {
    return (
      <div className="nates-secret-unborg-doc">
        <p className="nates-secret-unborg-doc__denied">{message}</p>
      </div>
    )
  }

  const handleUnborg = async () => {
    setLoading(true)
    setMessage('')
    try {
      const res = await fetch('/api/nate_s_secret_unborg_doc/unborg', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: '{}',
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        // Reload so buildNodeInfoStructure rebuilds e2.node and chat re-enables.
        window.location.reload()
      } else {
        setMessage((json && json.message) || 'Unborg failed.')
        setLoading(false)
      }
    } catch (err) {
      setMessage('Unborg failed.')
      setLoading(false)
    }
  }

  return (
    <div className="nates-secret-unborg-doc">
      {message && <p className="nates-secret-unborg-doc__success">{message}</p>}
      <button
        type="button"
        onClick={handleUnborg}
        disabled={loading}
        className="nates-secret-unborg-doc__button"
      >
        {loading ? 'Unborging…' : 'Unborg me'}
      </button>
    </div>
  )
}

export default NatesSecretUnborgDoc

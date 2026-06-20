import React from 'react'

/**
 * LogoutLink - logs out via POST /api/sessions/delete (clears the session
 * cookie server-side), then redirects home. Keeps a client-side cookie clear
 * as a backup in case the Set-Cookie response is cached/stripped.
 *
 * Replaces the legacy op=logout dispatch (#4335 Phase 2).
 */
const LogoutLink = ({ display = 'Log Out', style }) => {
  const handleLogout = async (e) => {
    e.preventDefault()
    try {
      await fetch('/api/sessions/delete', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Accept': 'application/json' },
      })
    } catch (err) {
      // ignore network errors; fall through to the client-side clear + redirect
    }
    // Backup client-side clear (in case the Set-Cookie was cached/stripped)
    document.cookie = 'userpass=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;'
    window.location.href = '/'
  }

  return (
    <a href="/" onClick={handleLogout} className="logout-link" style={style}>
      {display}
    </a>
  )
}

export default LogoutLink

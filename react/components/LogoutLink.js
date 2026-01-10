import React from 'react'

/**
 * LogoutLink - Handles logout via server-side op=logout with client-side backup
 *
 * Uses traditional op=logout to let server clear the cookie properly.
 * Also clears cookie client-side as a backup in case server response is cached.
 */
const LogoutLink = ({ display = 'Log Out', style }) => {
  const handleLogout = (e) => {
    // Clear cookie client-side as backup (in case server response is cached/stripped)
    document.cookie = 'userpass=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;'

    // Let the link navigate normally to op=logout
    // Don't preventDefault - allow normal navigation
  }

  return (
    <a href="/node/superdoc/login?op=logout" onClick={handleLogout} style={{ cursor: 'pointer', ...style }}>
      {display}
    </a>
  )
}

export default LogoutLink

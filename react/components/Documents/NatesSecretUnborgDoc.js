import React from 'react'

/**
 * NatesSecretUnborgDoc - Instant unborg tool for admins.
 * Styles in CSS: .nates-secret-unborg-doc__*
 * Simple action page that immediately unborgs the user.
 */
const NatesSecretUnborgDoc = ({ data }) => {
  const { success, message } = data

  return (
    <div className="nates-secret-unborg-doc">
      <p className={success ? 'nates-secret-unborg-doc__success' : 'nates-secret-unborg-doc__denied'}>
        {message}
      </p>
    </div>
  )
}

export default NatesSecretUnborgDoc

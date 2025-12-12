import React from 'react'

/**
 * NatesSecretUnborgDoc - Instant unborg tool for admins.
 * Simple action page that immediately unborgs the user.
 */
const NatesSecretUnborgDoc = ({ data }) => {
  const { success, message } = data

  return (
    <div style={styles.container}>
      <p style={success ? styles.success : styles.denied}>{message}</p>
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  success: {
    color: '#2e7d32',
    fontWeight: 'bold'
  },
  denied: {
    color: '#c62828'
  }
}

export default NatesSecretUnborgDoc

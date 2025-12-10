import React from 'react'

/**
 * The Killing Floor - Deprecated Editorial Tool
 *
 * Legacy editorial tool no longer used by the editing system.
 * Preserved for technical site integrity only.
 */
const TheKillingFloor = ({ data }) => {
  const { title = 'The Killing Floor' } = data

  return (
    <div style={styles.container}>
      <div style={styles.warningBox}>
        <h3 style={styles.warningTitle}>⚠️ Deprecated Feature</h3>
        <p style={styles.warningText}>
          <strong>{title}</strong> is no longer in use by the editing system.
        </p>
        <p style={styles.warningText}>
          This node has been preserved for technical site integrity, but its functionality
          is no longer necessary. If you are looking for editorial tools, please visit the
          Content Reports page or consult with site administrators.
        </p>
      </div>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    padding: '20px'
  },
  warningBox: {
    backgroundColor: '#fff3cd',
    border: '2px solid #ffc107',
    borderRadius: '6px',
    padding: '20px',
    marginBottom: '20px'
  },
  warningTitle: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#856404',
    marginTop: '0',
    marginBottom: '15px',
    display: 'flex',
    alignItems: 'center',
    gap: '8px'
  },
  warningText: {
    color: '#856404',
    marginBottom: '10px',
    lineHeight: '1.6'
  }
}

export default TheKillingFloor

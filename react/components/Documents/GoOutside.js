import React from 'react'

/**
 * GoOutside - Moves user to the "outside" room (room 0).
 * Displays result message after the action is performed.
 */
const GoOutside = ({ data }) => {
  const { success, locked_in, remaining_time, message } = data

  return (
    <div style={styles.container}>
      {locked_in ? (
        <div style={styles.errorBox}>
          <p style={styles.warningText}>
            <strong>You cannot change rooms for {remaining_time} minutes.</strong>
          </p>
          <p>You can still send private messages, however, or talk to people in your current room.</p>
        </div>
      ) : success ? (
        <div style={styles.successBox}>
          <p>{message}</p>
        </div>
      ) : (
        <div style={styles.errorBox}>
          <p>{message}</p>
        </div>
      )}
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
  successBox: {
    backgroundColor: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    padding: '15px',
    color: '#2e7d32'
  },
  errorBox: {
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    padding: '15px',
    color: '#c62828'
  },
  warningText: {
    color: 'red',
    margin: '0 0 10px 0'
  }
}

export default GoOutside

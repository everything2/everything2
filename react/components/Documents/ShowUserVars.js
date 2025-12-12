import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * ShowUserVars - Displays user variables for debugging.
 * Admin/Developer tool.
 */
const ShowUserVars = ({ data }) => {
  const { access_denied, message, is_admin, inspect_user, vars_data, user_data, viewvars_mode } = data

  const [username, setUsername] = useState(inspect_user?.title || '')

  if (access_denied) {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>Show User Vars</h2>
        <div style={styles.errorBox}>
          <p>{message}</p>
        </div>
      </div>
    )
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>Show User Vars</h2>

      {viewvars_mode ? (
        <p>
          Showing variables for: <LinkNode nodeId={inspect_user.node_id} title={inspect_user.title} />
        </p>
      ) : is_admin ? (
        <form method="GET" style={styles.form}>
          <input type="hidden" name="node_id" value={nodeId} />
          <label>
            Showing user variables for{' '}
            <input
              type="text"
              name="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              style={styles.input}
              size={30}
            />
          </label>{' '}
          <button type="submit" style={styles.button}>
            Show user vars
          </button>
        </form>
      ) : (
        <p>
          <LinkNode nodeId={inspect_user.node_id} title={inspect_user.title} />
        </p>
      )}

      {/* VARS table */}
      <h3 style={styles.subtitle}>VARS</h3>
      <table style={styles.table}>
        <tbody>
          {vars_data.map((item, idx) => (
            <tr key={item.key} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
              <td style={styles.keyCell}>{item.key}</td>
              <td style={styles.valueCell}>{String(item.value)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* USER table (admin only) */}
      {is_admin && user_data.length > 0 && (
        <>
          <h3 style={styles.subtitle}>USER</h3>
          <table style={styles.table}>
            <tbody>
              {user_data.map((item, idx) => (
                <tr key={item.key} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                  <td style={styles.keyCell}>{item.key}</td>
                  <td style={styles.valueCell}>{String(item.value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
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
  title: {
    fontSize: '18px',
    fontWeight: 'bold',
    margin: '0 0 15px 0',
    color: '#38495e'
  },
  subtitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    margin: '20px 0 10px 0',
    color: '#38495e'
  },
  form: {
    marginBottom: '20px'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px'
  },
  button: {
    padding: '6px 15px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    border: '1px solid #d3d3d3'
  },
  keyCell: {
    padding: '4px 8px',
    borderBottom: '1px solid #e0e0e0',
    fontWeight: 'bold',
    width: '200px',
    fontFamily: 'monospace'
  },
  valueCell: {
    padding: '4px 8px',
    borderBottom: '1px solid #e0e0e0',
    fontFamily: 'monospace',
    wordBreak: 'break-all'
  },
  oddRow: {
    backgroundColor: '#ffffff'
  },
  evenRow: {
    backgroundColor: '#f8f9f9'
  },
  errorBox: {
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    padding: '15px',
    color: '#c62828'
  }
}

export default ShowUserVars

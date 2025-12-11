import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * IP Hunter - Admin tool for tracking IP addresses and user logins
 *
 * Allows admins to search by:
 * - Username: See all IPs a user has logged in from
 * - IP Address: See all users that have logged in from an IP
 */
const IpHunter = ({ data, e2 }) => {
  const {
    error,
    search_type,
    search_value,
    user_id,
    user_title,
    results = [],
    result_limit
  } = data

  const [huntName, setHuntName] = useState('')
  const [huntIp, setHuntIp] = useState('')

  // IP lookup tools helper
  const renderIpLookup = (ip) => {
    return (
      <span style={styles.lookupLinks}>
        <a href={`http://whois.arin.net/rest/ip/${ip}`} target="_blank" rel="noopener noreferrer">ARIN</a>
        {' | '}
        <a href={`https://www.robtex.com/ip-lookup/${ip}`} target="_blank" rel="noopener noreferrer">Robtex</a>
        {' | '}
        <a href={`https://www.shodan.io/host/${ip}`} target="_blank" rel="noopener noreferrer">Shodan</a>
      </span>
    )
  }

  if (error) {
    return (
      <div style={styles.container}>
        <h2 style={styles.heading}>IP Hunter</h2>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.heading}>IP Hunter</h2>

      {/* Search Form */}
      <form method="post" style={styles.form}>
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />
        <table style={styles.formTable}>
          <tbody>
            <tr>
              <td style={styles.labelCell}><strong>name:</strong></td>
              <td>
                <input
                  type="text"
                  name="hunt_name"
                  value={huntName}
                  onChange={(e) => setHuntName(e.target.value)}
                  style={styles.input}
                />
              </td>
            </tr>
            <tr>
              <td></td>
              <td><strong> - or -</strong></td>
            </tr>
            <tr>
              <td style={styles.labelCell}><strong>IP:</strong></td>
              <td>
                <input
                  type="text"
                  name="hunt_ip"
                  value={huntIp}
                  onChange={(e) => setHuntIp(e.target.value)}
                  style={styles.input}
                />
              </td>
            </tr>
            <tr>
              <td></td>
              <td>
                <input type="submit" value="hunt" style={styles.submitButton} />
              </td>
            </tr>
          </tbody>
        </table>
      </form>

      <hr style={styles.divider} />

      {/* Results */}
      {search_type === 'ip' && (
        <div>
          <p>
            The IP ({search_value}) <small>({renderIpLookup(search_value)})</small> has been here and logged on as:
          </p>
          <p style={styles.limitNote}>(only showing {result_limit} most recent)</p>

          <table style={styles.resultsTable}>
            <thead>
              <tr>
                <th style={styles.th}>#</th>
                <th style={styles.th} colSpan="2">Who (Hunt User)</th>
                <th style={styles.th}>When</th>
              </tr>
            </thead>
            <tbody>
              {results.map((result, idx) => (
                <tr key={idx}>
                  <td style={styles.td}>{idx + 1}</td>
                  <td style={styles.td}>
                    {result.user_id ? (
                      <LinkNode nodeId={result.user_id} title={result.user_title} />
                    ) : (
                      <strong>Deleted user</strong>
                    )}
                  </td>
                  <td style={{...styles.td, textAlign: 'right'}}>
                    <a href={`?hunt_name=${encodeURIComponent(result.user_title)}`}>hunt</a>
                  </td>
                  <td style={styles.td}>{result.time}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {search_type === 'user' && (
        <div>
          <p>
            The user {user_id ? <LinkNode nodeId={user_id} title={user_title} /> : user_title} has been here as IPs:
          </p>
          <p style={styles.limitNote}>(only showing {result_limit} most recent)</p>

          <table style={styles.resultsTable}>
            <thead>
              <tr>
                <th style={styles.th}>#</th>
                <th style={styles.th}>IP</th>
                <th style={styles.th}>When</th>
                <th style={styles.th}>Look up</th>
              </tr>
            </thead>
            <tbody>
              {results.map((result, idx) => {
                const isBanned = result.banned || result.banned_ranged
                return (
                  <tr key={idx}>
                    <td style={styles.td}>{idx + 1}</td>
                    <td style={styles.td}>
                      {isBanned ? (
                        <strike><strong>
                          <a href={`?hunt_ip=${encodeURIComponent(result.ip)}`}>{result.ip}</a>
                        </strong></strike>
                      ) : (
                        <a href={`?hunt_ip=${encodeURIComponent(result.ip)}`}>{result.ip}</a>
                      )}
                    </td>
                    <td style={styles.td}>{result.time}</td>
                    <td style={styles.td}>{renderIpLookup(result.ip)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      {!search_type && !error && (
        <p>Please enter an IP address or a name to continue</p>
      )}
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
  heading: {
    fontSize: '20px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '20px'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginBottom: '20px'
  },
  form: {
    marginBottom: '20px'
  },
  formTable: {
    borderSpacing: '5px'
  },
  labelCell: {
    width: '50px',
    verticalAlign: 'middle'
  },
  input: {
    padding: '5px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '3px'
  },
  submitButton: {
    padding: '5px 15px',
    fontSize: '13px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer'
  },
  divider: {
    margin: '20px 0',
    border: 'none',
    borderTop: '1px solid #ccc'
  },
  limitNote: {
    fontSize: '12px',
    color: '#666',
    fontStyle: 'italic'
  },
  resultsTable: {
    borderCollapse: 'collapse',
    border: '1px solid #38495e',
    marginTop: '10px'
  },
  th: {
    backgroundColor: '#f0f0f0',
    padding: '8px',
    border: '1px solid #38495e',
    fontWeight: 'bold',
    textAlign: 'left'
  },
  td: {
    padding: '6px 8px',
    border: '1px solid #38495e'
  },
  lookupLinks: {
    fontSize: '11px'
  }
}

export default IpHunter

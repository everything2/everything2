import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Ip2name - Look up users by IP address.
 * Admin/Editor tool that searches user settings for matching IP addresses.
 */
const Ip2name = ({ data }) => {
  const { access_denied, ipaddy: initialIp, results: initialResults } = data

  const [ipaddy, setIpaddy] = useState(initialIp || '')
  const [results, setResults] = useState(initialResults || [])
  const [searched, setSearched] = useState(Boolean(initialIp))

  if (access_denied) {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>IP2Name</h2>
        <div style={styles.errorBox}>
          <p>Access denied. Editors and admins only.</p>
        </div>
      </div>
    )
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    // Submit to server via page reload with query param
    const params = new URLSearchParams()
    params.set('node_id', window.e2?.node_id || '')
    params.set('ipaddy', ipaddy)
    window.location.href = `?${params.toString()}`
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>IP2Name</h2>

      <p style={styles.warning}>
        Please use me sparingly! I am expensive to run! Note: this probably won&apos;t work too well
        with people that have dynamic IP addresses.
      </p>

      {searched && (
        <div style={styles.results}>
          {results.length > 0 ? (
            <>
              <p>
                <strong>Users found:</strong>
              </p>
              <ul style={styles.list}>
                {results.map((user) => (
                  <li key={user.node_id}>
                    <LinkNode nodeId={user.node_id} title={user.title} />
                  </li>
                ))}
              </ul>
            </>
          ) : (
            <p>
              <em>nein!</em>
            </p>
          )}
        </div>
      )}

      <form onSubmit={handleSubmit} style={styles.form}>
        <label>
          IP Address:{' '}
          <input
            type="text"
            value={ipaddy}
            onChange={(e) => setIpaddy(e.target.value)}
            style={styles.input}
            placeholder="e.g. 192.168.1.1"
          />
        </label>{' '}
        <button type="submit" style={styles.button}>
          Search
        </button>
      </form>
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
    margin: '0 0 10px 0',
    color: '#38495e'
  },
  warning: {
    color: '#c62828',
    marginBottom: '15px',
    fontStyle: 'italic'
  },
  form: {
    marginTop: '15px'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '200px'
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
  results: {
    backgroundColor: '#f8f9f9',
    padding: '10px',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  list: {
    margin: '10px 0 0 0',
    paddingLeft: '20px'
  },
  errorBox: {
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    padding: '15px',
    color: '#c62828'
  }
}

export default Ip2name

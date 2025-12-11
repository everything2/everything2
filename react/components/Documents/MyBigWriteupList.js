import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * MyBigWriteupList - Comprehensive listing of all writeups by a user
 *
 * Features:
 * - Multiple sorting options (title, type, C!, reputation, date)
 * - Raw data export mode with custom delimiter
 * - Admins can search for other users
 * - Shows reputation details for user's own writeups or admins
 */
const MyBigWriteupList = ({ data }) => {
  const {
    guest,
    error,
    username,
    user_id,
    is_admin,
    is_me,
    show_rep,
    total_count,
    writeups = [],
    order_by: initialOrderBy = 'title ASC',
    raw_mode: initialRawMode = false,
    delimiter: initialDelimiter = '_'
  } = data

  const [usersearch, setUsersearch] = useState(username || '')
  const [orderBy, setOrderBy] = useState(initialOrderBy)
  const [rawMode, setRawMode] = useState(initialRawMode)
  const [delimiter, setDelimiter] = useState(initialDelimiter)

  if (guest) {
    return (
      <div style={styles.container}>
        <p>
          You need an account to access this node.
          <br />
          <br />
          Why not <LinkNode title="Sign Up" /> one?
        </p>
      </div>
    )
  }

  if (error) {
    return (
      <div style={styles.container}>
        {renderSearchForm()}
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  const handleSubmit = (e) => {
    // Let form submit naturally
  }

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp.replace(' ', 'T') + 'Z')
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    const month = months[date.getUTCMonth()]
    const day = date.getUTCDate()
    const year = date.getUTCFullYear()
    const hours = String(date.getUTCHours()).padStart(2, '0')
    const minutes = String(date.getUTCMinutes()).padStart(2, '0')
    return `${month} ${day}, ${year} at ${hours}:${minutes}`
  }

  function renderSearchForm() {
    const orderOptions = [
      { value: 'title ASC', label: 'Title' },
      { value: 'wrtype_writeuptype ASC,title ASC', label: 'Writeup type, then title' },
      { value: 'cooled DESC,title ASC', label: 'C!, then title' },
      { value: 'cooled DESC,node.reputation DESC,title ASC', label: 'C!, then reputation' },
      { value: 'node.reputation DESC,title ASC', label: 'Reputation' },
      { value: 'writeup.publishtime DESC', label: 'Date, most recent first' },
      { value: 'writeup.publishtime ASC', label: 'Date, most recent last' }
    ]

    return (
      <div style={styles.formContainer}>
        <form method="get" onSubmit={handleSubmit}>
          <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />

          {is_admin ? (
            <div style={styles.formRow}>
              <label>
                Search for user:{' '}
                <input
                  type="text"
                  name="usersearch"
                  value={usersearch}
                  onChange={(e) => setUsersearch(e.target.value)}
                  style={styles.input}
                  className="userComplete"
                />
              </label>
            </div>
          ) : (
            <>
              <input type="hidden" name="usersearch" value={username} />
              <div style={styles.formRow}>For: {username}</div>
            </>
          )}

          <div style={styles.formRow}>
            <label>
              Order By:{' '}
              <select
                name="orderby"
                value={orderBy}
                onChange={(e) => setOrderBy(e.target.value)}
                style={styles.select}
              >
                {orderOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div style={styles.formRow}>
            <label>
              <input
                type="checkbox"
                name="raw"
                checked={rawMode}
                onChange={(e) => setRawMode(e.target.checked)}
                value="1"
              />
              {' Raw Data'}
            </label>
            {' \u00a0\u00a0'}
            <label>
              Delimiter:{' '}
              <input
                type="text"
                name="delimiter"
                value={delimiter}
                onChange={(e) => setDelimiter(e.target.value)}
                style={styles.delimiterInput}
                maxLength={1}
              />
            </label>
          </div>

          <div style={styles.formRow}>
            <button type="submit" name="sexisgood" value="submit" style={styles.button}>
              Submit
            </button>
          </div>
        </form>
      </div>
    )
  }

  function renderRawData() {
    const lines = writeups.map((wu) => {
      let line = wu.title + delimiter

      if (wu.cooled) {
        line += wu.cooled + 'C!' + delimiter
      } else {
        line += ' ' + delimiter
      }

      // Show rep if globally allowed (own writeups/editor/admin) OR user voted on this writeup
      const canSeeRep = show_rep || wu.voted
      if (canSeeRep && wu.reputation !== undefined) {
        line += (wu.reputation || 0) + delimiter
        line += (wu.total_votes || 0) + delimiter
      }

      line += formatTimestamp(wu.publishtime)
      return line
    })

    return (
      <div>
        {renderSearchForm()}
        <pre style={styles.pre}>{lines.join('\n')}</pre>
      </div>
    )
  }

  function renderTable() {
    return (
      <div>
        {renderSearchForm()}

        <p>
          {total_count === 1
            ? 'This writeup was'
            : `These ${total_count} writeups were all`}{' '}
          written by{' '}
          <LinkNode nodeId={user_id} title={is_me ? 'you' : username} />:
        </p>

        {total_count === 0 ? (
          <p>
            <LinkNode nodeId={user_id} title={username} /> has no writeups.
          </p>
        ) : (
          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th} align="left">
                  Writeup Title (type)
                </th>
                <th style={styles.th}>C!</th>
                <th style={styles.th} colSpan={2} align="center">
                  Rep
                </th>
                <th style={styles.th} align="center">
                  Published
                </th>
              </tr>
            </thead>
            <tbody>
              {writeups.map((wu, index) => {
                // Show rep if globally allowed (own writeups/editor/admin) OR user voted on this writeup
                const canSeeRep = show_rep || wu.voted
                return (
                  <tr
                    key={index}
                    style={index % 2 === 1 ? styles.oddRow : {}}
                  >
                    <td style={styles.td} nowrap="nowrap">
                      <LinkNode nodeId={wu.parent_e2node} title={wu.title} />
                    </td>
                    <td style={styles.td}>
                      {wu.cooled ? <strong>{wu.cooled}C!</strong> : ''}
                    </td>
                    {canSeeRep && wu.reputation !== undefined ? (
                      <>
                        <td style={styles.td}>{wu.reputation || 0}</td>
                        <td style={styles.tdSmall}>
                          +{wu.upvotes}/-{wu.downvotes}
                        </td>
                      </>
                    ) : (
                      <td style={styles.td} colSpan={2}></td>
                    )}
                    <td style={{ ...styles.td, ...styles.tdRight }} nowrap="nowrap">
                      <small>{formatTimestamp(wu.publishtime)}</small>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    )
  }

  return (
    <div style={styles.container}>
      {rawMode ? renderRawData() : renderTable()}
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginTop: '20px'
  },
  formContainer: {
    padding: '15px',
    backgroundColor: '#f8f9f9',
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    marginBottom: '20px'
  },
  formRow: {
    marginBottom: '10px'
  },
  input: {
    padding: '6px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontSize: '13px',
    minWidth: '200px'
  },
  select: {
    padding: '6px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontSize: '13px',
    minWidth: '250px'
  },
  delimiterInput: {
    padding: '6px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontSize: '13px',
    width: '30px',
    textAlign: 'center'
  },
  button: {
    padding: '8px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: 'bold'
  },
  pre: {
    backgroundColor: '#f8f9f9',
    padding: '15px',
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    overflow: 'auto',
    fontSize: '12px',
    lineHeight: '1.4'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    border: '1px solid #d3d3d3',
    marginTop: '10px'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px',
    border: '1px solid #38495e',
    fontSize: '13px'
  },
  td: {
    border: '1px solid #d3d3d3',
    padding: '6px'
  },
  tdSmall: {
    border: '1px solid #d3d3d3',
    padding: '6px',
    fontSize: '11px'
  },
  tdRight: {
    textAlign: 'right'
  },
  oddRow: {
    backgroundColor: '#bbbbff'
  }
}

export default MyBigWriteupList

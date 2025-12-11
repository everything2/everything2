import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * IP Blacklist - Admin tool for managing blocked IP addresses
 *
 * Manages IP addresses that are barred from creating new accounts.
 * Supports individual IPs and CIDR ranges (e.g., 192.168.1.0/24).
 */
const IpBlacklist = ({ data, e2 }) => {
  const {
    error_message,
    success_message,
    entries = [],
    total_count,
    offset,
    page_size,
    guest_user_id,
    posted_ip = '',
    posted_reason = ''
  } = data

  const [badIp, setBadIp] = useState(posted_ip)
  const [blockReason, setBlockReason] = useState(posted_reason)

  // Pagination helpers
  const hasMore = total_count > offset + entries.length
  const hasPrev = offset > 0

  const nextOffset = offset + page_size
  const prevOffset = Math.max(0, offset - page_size)

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        This page manages the IP addresses which are barred from <strong>creating new accounts</strong>.
        {' '}Except for very extreme circumstances, we don't block pageloads as{' '}
        <LinkNode nodeId={guest_user_id} title="Guest User" />.
      </p>

      <p style={styles.warning}>
        <strong>
          This tool should ONLY be used to block access at the IP level for users whose primary
          accounts have been locked if they continue to abuse our hospitality.
        </strong>
        {' '}Usually the 'Smite Spammer' tool will do the job automatically for you when it needs to be done.
      </p>

      {success_message && (
        <div style={styles.successBox}>{success_message}</div>
      )}

      {error_message && (
        <div style={styles.errorBox}>{error_message}</div>
      )}

      <h3 style={styles.heading}>Blacklist an IP</h3>

      <form method="post" style={styles.form}>
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />

        <div style={styles.formGroup}>
          <strong>IP Address</strong>
          <br />
          <input
            type="text"
            name="bad_ip"
            value={badIp}
            onChange={(e) => setBadIp(e.target.value)}
            size="20"
            style={styles.input}
            placeholder="192.168.1.1 or 192.168.1.0/24"
          />
          <br />
          <small style={styles.helpText}>
            Enter a single IP address or CIDR range (e.g., 192.168.1.0/24)
          </small>
        </div>

        <div style={styles.formGroup}>
          <strong>Reason</strong>
          <br />
          <input
            type="text"
            name="block_reason"
            value={blockReason}
            onChange={(e) => setBlockReason(e.target.value)}
            size="50"
            style={styles.input}
            placeholder="Reason for blocking this IP"
          />
        </div>

        <input
          type="submit"
          name="add_ip_block"
          value="Please blacklist this IP"
          style={styles.submitButton}
        />
      </form>

      <h3 style={styles.heading}>Blacklisted IPs</h3>

      {entries.length === 0 ? (
        <p>No blacklisted IPs found.</p>
      ) : (
        <>
          <p style={styles.pagination}>
            Showing {offset + 1} - {offset + entries.length} of {total_count}
          </p>

          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th}>IP Address</th>
                <th style={styles.th}>Reason</th>
                <th style={styles.th}>Date</th>
                <th style={styles.th}>Action</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, idx) => (
                <tr key={entry.id} style={idx % 2 === 0 ? styles.evenRow : styles.oddRow}>
                  <td style={styles.td}>{entry.ip_address}</td>
                  <td style={styles.td}>
                    <div dangerouslySetInnerHTML={{ __html: entry.comment }} />
                  </td>
                  <td style={styles.td}>{entry.timestamp}</td>
                  <td style={styles.td}>
                    <form method="post" style={{ display: 'inline' }}>
                      <input type="hidden" name="node_id" value={e2?.node_id || ''} />
                      <input type="hidden" name="remove_ip_block_ref" value={entry.id} />
                      <input
                        type="submit"
                        value="Remove"
                        style={styles.removeButton}
                      />
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {(hasPrev || hasMore) && (
            <div style={styles.paginationLinks}>
              {hasPrev && (
                <a href={`?offset=${prevOffset}`} style={styles.link}>
                  ← Previous {page_size}
                </a>
              )}
              {hasPrev && hasMore && <span style={{ margin: '0 10px' }}>|</span>}
              {hasMore && (
                <a href={`?offset=${nextOffset}`} style={styles.link}>
                  Next {page_size} →
                </a>
              )}
            </div>
          )}
        </>
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
  intro: {
    marginBottom: '15px'
  },
  warning: {
    marginBottom: '20px',
    color: '#c62828'
  },
  heading: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#38495e',
    marginTop: '30px',
    marginBottom: '15px',
    borderBottom: '1px solid #38495e',
    paddingBottom: '5px'
  },
  successBox: {
    padding: '15px',
    backgroundColor: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    color: '#2e7d32',
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
    marginBottom: '30px'
  },
  formGroup: {
    marginBottom: '15px'
  },
  input: {
    padding: '6px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '3px',
    marginTop: '5px'
  },
  helpText: {
    color: '#666',
    fontSize: '11px'
  },
  submitButton: {
    padding: '8px 15px',
    fontSize: '13px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    marginTop: '10px'
  },
  pagination: {
    fontSize: '12px',
    color: '#666',
    marginBottom: '10px'
  },
  paginationLinks: {
    marginTop: '20px',
    textAlign: 'center'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  table: {
    borderCollapse: 'collapse',
    border: '1px solid #38495e',
    width: '100%'
  },
  th: {
    backgroundColor: '#f0f0f0',
    padding: '8px',
    border: '1px solid #38495e',
    fontWeight: 'bold',
    textAlign: 'left'
  },
  td: {
    padding: '8px',
    border: '1px solid #38495e',
    verticalAlign: 'top'
  },
  evenRow: {
    backgroundColor: '#ffffff'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  },
  removeButton: {
    padding: '4px 10px',
    fontSize: '12px',
    backgroundColor: '#d32f2f',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer'
  }
}

export default IpBlacklist

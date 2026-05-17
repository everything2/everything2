import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * IP Blacklist - Admin tool for managing blocked IP addresses
 * Styles in CSS: .ip-blacklist__*
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
    <div className="ip-blacklist">
      <p className="ip-blacklist__intro">
        This page manages the IP addresses which are barred from <strong>creating new accounts</strong>.
        {' '}Except for very extreme circumstances, we don't block pageloads as{' '}
        <LinkNode nodeId={guest_user_id} title="Guest User" />.
      </p>

      <p className="ip-blacklist__warning">
        <strong>
          This tool should ONLY be used to block access at the IP level for users whose primary
          accounts have been locked if they continue to abuse our hospitality.
        </strong>
        {' '}Usually the 'Smite Spammer' tool will do the job automatically for you when it needs to be done.
      </p>

      {success_message && (
        <div className="ip-blacklist__success">{success_message}</div>
      )}

      {error_message && (
        <div className="ip-blacklist__error">{error_message}</div>
      )}

      <h3 className="ip-blacklist__heading">Blacklist an IP</h3>

      <form method="post" className="ip-blacklist__form">
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />

        <div className="ip-blacklist__form-group">
          <strong>IP Address</strong>
          <br />
          <input
            type="text"
            name="bad_ip"
            value={badIp}
            onChange={(e) => setBadIp(e.target.value)}
            className="ip-blacklist__input"
            placeholder="192.168.1.1 or 192.168.1.0/24"
          />
          <br />
          <small className="ip-blacklist__help-text">
            Enter a single IP address or CIDR range (e.g., 192.168.1.0/24)
          </small>
        </div>

        <div className="ip-blacklist__form-group">
          <strong>Reason</strong>
          <br />
          <input
            type="text"
            name="block_reason"
            value={blockReason}
            onChange={(e) => setBlockReason(e.target.value)}
            className="ip-blacklist__input"
            placeholder="Reason for blocking this IP"
          />
        </div>

        <input
          type="submit"
          name="add_ip_block"
          value="Please blacklist this IP"
          className="ip-blacklist__submit-button"
        />
      </form>

      <h3 className="ip-blacklist__heading">Blacklisted IPs</h3>

      {entries.length === 0 ? (
        <p>No blacklisted IPs found.</p>
      ) : (
        <>
          <p className="ip-blacklist__pagination">
            Showing {offset + 1} - {offset + entries.length} of {total_count}
          </p>

          <table className="ip-blacklist__table">
            <thead>
              <tr>
                <th className="ip-blacklist__th">IP Address</th>
                <th className="ip-blacklist__th">Reason</th>
                <th className="ip-blacklist__th">Date</th>
                <th className="ip-blacklist__th">Action</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, idx) => (
                <tr key={entry.id} className={idx % 2 === 0 ? 'ip-blacklist__row--even' : 'ip-blacklist__row--odd'}>
                  <td className="ip-blacklist__td">{entry.ip_address}</td>
                  <td className="ip-blacklist__td">
                    <div dangerouslySetInnerHTML={{ __html: entry.comment }} />
                  </td>
                  <td className="ip-blacklist__td">{entry.timestamp}</td>
                  <td className="ip-blacklist__td">
                    <form method="post" className="ip-blacklist__remove-form">
                      <input type="hidden" name="node_id" value={e2?.node_id || ''} />
                      <input type="hidden" name="remove_ip_block_ref" value={entry.id} />
                      <input
                        type="submit"
                        value="Remove"
                        className="ip-blacklist__remove-button"
                      />
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {(hasPrev || hasMore) && (
            <div className="ip-blacklist__pagination-links">
              {hasPrev && (
                <a href={`?offset=${prevOffset}`} className="ip-blacklist__link">
                  ← Previous {page_size}
                </a>
              )}
              {hasPrev && hasMore && <span className="ip-blacklist__separator">|</span>}
              {hasMore && (
                <a href={`?offset=${nextOffset}`} className="ip-blacklist__link">
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

export default IpBlacklist

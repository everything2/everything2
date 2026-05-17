import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Mass IP Blacklister - Admin tool for bulk IP address blocking
 * Styles in CSS: .mass-ip-blacklister__*
 *
 * Manages IP addresses that are barred from creating new accounts.
 * Unlike the regular IP Blacklist, this accepts multiple IPs (one per line)
 * for batch processing based on externally maintained blacklists.
 */
const MassIpBlacklister = ({ data, e2 }) => {
  const {
    error,
    error_messages = [],
    success_messages = [],
    entries = [],
    total_count,
    offset,
    page_size,
    guest_user_id,
    posted_ips = '',
    posted_reason = ''
  } = data

  const [badIps, setBadIps] = useState(posted_ips)
  const [blockReason, setBlockReason] = useState(posted_reason)

  // Pagination helpers
  const hasMore = total_count > offset + entries.length
  const hasPrev = offset > 0

  const nextOffset = offset + page_size
  const prevOffset = Math.max(0, offset - page_size)

  if (error) {
    return (
      <div className="mass-ip-blacklister">
        <div className="mass-ip-blacklister__error-box">{error}</div>
      </div>
    )
  }

  return (
    <div className="mass-ip-blacklister">
      <p className="mass-ip-blacklister__intro">
        This page manages the IP addresses which are barred from <strong>creating new accounts</strong>.
        {' '}Except for very extreme circumstances, we don't block pageloads as{' '}
        <LinkNode nodeId={guest_user_id} title="Guest User" />.
      </p>

      {success_messages.length > 0 && (
        <div className="mass-ip-blacklister__success-box">
          <ol className="mass-ip-blacklister__list">
            {success_messages.map((msg, idx) => (
              <li key={idx}>{msg}</li>
            ))}
          </ol>
        </div>
      )}

      {error_messages.length > 0 && (
        <div className="mass-ip-blacklister__error-box">
          <ol className="mass-ip-blacklister__list">
            {error_messages.map((msg, idx) => (
              <li key={idx}>{msg}</li>
            ))}
          </ol>
        </div>
      )}

      <h3 className="mass-ip-blacklister__heading">Blacklist IPs (one per line)</h3>

      <form method="post" className="mass-ip-blacklister__form">
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />

        <div className="mass-ip-blacklister__form-group">
          <strong>IP Addresses</strong>
          <br />
          <textarea
            name="bad_ips"
            value={badIps}
            onChange={(e) => setBadIps(e.target.value)}
            rows={20}
            className="mass-ip-blacklister__textarea"
            placeholder="192.168.1.1&#10;192.168.1.2&#10;192.168.1.3"
          />
        </div>

        <div className="mass-ip-blacklister__form-group">
          <strong>Reason</strong>
          <br />
          <input
            type="text"
            name="block_reason"
            value={blockReason}
            onChange={(e) => setBlockReason(e.target.value)}
            className="mass-ip-blacklister__input"
            placeholder="Reason for blocking these IPs"
          />
        </div>

        <input
          type="submit"
          name="add_ip_block"
          value="Please blacklist these IPs"
          className="mass-ip-blacklister__submit-button"
        />
      </form>

      <h3 className="mass-ip-blacklister__heading">Blacklisted IPs</h3>

      {entries.length === 0 ? (
        <p>No blacklisted IPs found.</p>
      ) : (
        <>
          <p className="mass-ip-blacklister__pagination">
            Showing {offset + 1} - {offset + entries.length} of {total_count}
          </p>

          <table className="mass-ip-blacklister__table">
            <thead>
              <tr>
                <th className="mass-ip-blacklister__th">IP Address</th>
                <th className="mass-ip-blacklister__th">Reason</th>
                <th className="mass-ip-blacklister__th">Date</th>
                <th className="mass-ip-blacklister__th">Action</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, idx) => (
                <tr key={entry.id} className={idx % 2 === 0 ? 'mass-ip-blacklister__even-row' : 'mass-ip-blacklister__odd-row'}>
                  <td className="mass-ip-blacklister__td">{entry.ip_address}</td>
                  <td className="mass-ip-blacklister__td">
                    <div dangerouslySetInnerHTML={{ __html: entry.comment }} />
                  </td>
                  <td className="mass-ip-blacklister__td">{entry.timestamp}</td>
                  <td className="mass-ip-blacklister__td">
                    <form method="post" className="mass-ip-blacklister__inline-form">
                      <input type="hidden" name="node_id" value={e2?.node_id || ''} />
                      <input type="hidden" name="remove_ip_block_ref" value={entry.id} />
                      <input
                        type="submit"
                        value="Remove"
                        className="mass-ip-blacklister__remove-button"
                      />
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {(hasPrev || hasMore) && (
            <div className="mass-ip-blacklister__pagination-links">
              {hasPrev && (
                <a href={`?offset=${prevOffset}`} className="mass-ip-blacklister__link">
                  ← Previous {page_size}
                </a>
              )}
              {hasPrev && hasMore && <span className="mass-ip-blacklister__pagination-separator">|</span>}
              {hasMore && (
                <a href={`?offset=${nextOffset}`} className="mass-ip-blacklister__link">
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

export default MassIpBlacklister

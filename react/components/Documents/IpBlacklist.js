import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * IP Blacklist - Admin tool for managing blocked IP addresses (#4464).
 * Styles in CSS: .ip-blacklist__*
 *
 * One unified interface for both the ip_blacklist and mass_ip_blacklister Document pages:
 * the add box takes one entry per line (a single IP OR a CIDR range like 192.168.1.0/24),
 * so a single IP is just a one-line list. add/remove/list are driven by
 * POST /api/ip_blacklist/*; `data.source` selects the audit-log event server-side.
 */
const IpBlacklist = ({ data }) => {
  const {
    error,
    source,
    guest_user_id,
    page_size = 200,
  } = data

  const [entries, setEntries] = useState(data.entries || [])
  const [totalCount, setTotalCount] = useState(data.total_count || 0)
  const [offset, setOffset] = useState(data.offset || 0)
  const [badIps, setBadIps] = useState('')
  const [reason, setReason] = useState('')
  const [results, setResults] = useState([])
  const [banner, setBanner] = useState('')
  const [loading, setLoading] = useState(false)

  if (error) {
    return (
      <div className="ip-blacklist">
        <div className="ip-blacklist__error">{error}</div>
      </div>
    )
  }

  const post = async (route, body) => {
    const res = await fetch(`/api/ip_blacklist/${route}`, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ source, offset, ...body }),
    })
    return res.ok ? res.json() : null
  }

  // Every response folds in the refreshed list page, so update it in one shot.
  const applyList = (json) => {
    if (!json) return
    if (Array.isArray(json.entries)) setEntries(json.entries)
    if (typeof json.total_count === 'number') setTotalCount(json.total_count)
    if (typeof json.offset === 'number') setOffset(json.offset)
  }

  const handleAdd = async (e) => {
    e.preventDefault()
    setLoading(true)
    setBanner('')
    setResults([])
    try {
      const json = await post('add', { ips: badIps, reason })
      if (json && json.success) {
        setResults(json.results || [])
        // Clear the entry box if every line succeeded.
        if ((json.results || []).every((r) => r.success)) setBadIps('')
      } else {
        setBanner((json && json.error) || 'Add failed.')
      }
      applyList(json)
    } catch (err) {
      setBanner(err.message || 'Add failed.')
    } finally {
      setLoading(false)
    }
  }

  const handleRemove = async (id) => {
    setLoading(true)
    setBanner('')
    setResults([])
    try {
      const json = await post('remove', { id })
      if (json && json.message) setResults([{ ip: '', success: json.success ? 1 : 0, message: json.message }])
      else if (json && json.error) setBanner(json.error)
      applyList(json)
    } catch (err) {
      setBanner(err.message || 'Remove failed.')
    } finally {
      setLoading(false)
    }
  }

  const gotoOffset = async (newOffset) => {
    setLoading(true)
    try {
      const json = await post('list', { offset: newOffset })
      applyList(json)
    } finally {
      setLoading(false)
    }
  }

  const hasMore = totalCount > offset + entries.length
  const hasPrev = offset > 0

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

      {banner && <div className="ip-blacklist__error">{banner}</div>}

      {results.length > 0 && (
        <div className="ip-blacklist__results">
          <ol className="ip-blacklist__results-list">
            {results.map((r, idx) => (
              <li key={idx} className={r.success ? 'ip-blacklist__success' : 'ip-blacklist__error'}>
                {r.message}
              </li>
            ))}
          </ol>
        </div>
      )}

      <h3 className="ip-blacklist__heading">Blacklist an IP (one entry per line)</h3>

      <form onSubmit={handleAdd} className="ip-blacklist__form">
        <div className="ip-blacklist__form-group">
          <strong>IP Address(es)</strong>
          <br />
          <textarea
            value={badIps}
            onChange={(e) => setBadIps(e.target.value)}
            rows={6}
            className="ip-blacklist__textarea"
            placeholder="192.168.1.1&#10;192.168.1.0/24 (CIDR range)&#10;one per line"
          />
          <br />
          <small className="ip-blacklist__help-text">
            One entry per line. Each entry is a single IP address or a CIDR range (e.g. 192.168.1.0/24).
          </small>
        </div>

        <div className="ip-blacklist__form-group">
          <strong>Reason</strong>
          <br />
          <input
            type="text"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="ip-blacklist__input"
            placeholder="Reason for blocking"
          />
        </div>

        <button type="submit" className="ip-blacklist__submit-button" disabled={loading}>
          {loading ? 'Working…' : 'Please blacklist'}
        </button>
      </form>

      <h3 className="ip-blacklist__heading">Blacklisted IPs</h3>

      {entries.length === 0 ? (
        <p>No blacklisted IPs found.</p>
      ) : (
        <>
          <p className="ip-blacklist__pagination">
            Showing {offset + 1} - {offset + entries.length} of {totalCount}
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
                    <button
                      type="button"
                      onClick={() => handleRemove(entry.id)}
                      disabled={loading}
                      className="ip-blacklist__remove-button"
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {(hasPrev || hasMore) && (
            <div className="ip-blacklist__pagination-links">
              {hasPrev && (
                <button
                  type="button"
                  onClick={() => gotoOffset(Math.max(0, offset - page_size))}
                  disabled={loading}
                  className="ip-blacklist__link"
                >
                  ← Previous {page_size}
                </button>
              )}
              {hasPrev && hasMore && <span className="ip-blacklist__separator">|</span>}
              {hasMore && (
                <button
                  type="button"
                  onClick={() => gotoOffset(offset + page_size)}
                  disabled={loading}
                  className="ip-blacklist__link"
                >
                  Next {page_size} →
                </button>
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default IpBlacklist

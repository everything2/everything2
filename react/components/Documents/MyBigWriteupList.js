import React, { useState, useEffect, useMemo } from 'react'
import LinkNode from '../LinkNode'

// Copy for each API error state (#4524): the server ships { state }, React owns the words.
const ERROR_COPY = {
  user_not_found: (username) => `User '${username}' doesn't exist. Did you type their name correctly?`,
  edb: () => 'G r o w l !',
  webster: () => 'Are you really looking for almost all the words in the English language?',
  bad_delimiter: () => 'Delimiter must be exactly one character.'
}

/**
 * MyBigWriteupList - Comprehensive listing of all writeups by a user
 * Styles in CSS: .my-big-writeup-list__*
 *
 * Fully client-resolved (#4524): the Page is a pure gate. This reads usersearch/orderby/raw/delimiter
 * off the URL and fetches GET /api/my_big_writeup_list, which enforces the NoGuest gate, resolves the
 * target user, computes per-writeup reputation visibility, and returns the list (or an error state).
 * The form navigates by query param (full page load); read back on mount.
 */
const MyBigWriteupList = ({ user }) => {
  const initial = useMemo(() => {
    const qs = new URLSearchParams(window.location.search)
    return {
      usersearch: qs.get('usersearch') || '',
      orderby: qs.get('orderby') || 'title ASC',
      raw: qs.get('raw') ? true : false,
      delimiter: qs.get('delimiter') || '_'
    }
  }, [])

  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams({ orderby: initial.orderby, delimiter: initial.delimiter })
    if (initial.usersearch) params.set('usersearch', initial.usersearch)
    if (initial.raw) params.set('raw', '1')
    let cancelled = false
    fetch(`/api/my_big_writeup_list?${params}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [initial])

  const {
    state,
    username,
    user_id,
    is_me,
    show_rep,
    total_count,
    writeups = []
  } = data || {}

  const isAdmin = !!user?.admin

  const [usersearch, setUsersearch] = useState(initial.usersearch)
  const [orderBy, setOrderBy] = useState(initial.orderby)
  const [rawMode, setRawMode] = useState(initial.raw)
  const [delimiter, setDelimiter] = useState(initial.delimiter)

  // Keep the admin username field in sync with the resolved user once the fetch lands.
  useEffect(() => {
    if (data && data.username && !initial.usersearch) setUsersearch(data.username)
  }, [data, initial.usersearch])

  if (loading) {
    return (
      <div className="my-big-writeup-list">
        <p>Loading writeups...</p>
      </div>
    )
  }

  if (state === 'guest') {
    return (
      <div className="my-big-writeup-list">
        <p>
          You need an account to access this node.
          <br />
          <br />
          Why not <LinkNode title="Sign Up" /> one?
        </p>
      </div>
    )
  }

  if (state && ERROR_COPY[state]) {
    return (
      <div className="my-big-writeup-list">
        {renderSearchForm()}
        <div className="my-big-writeup-list__error-box">{ERROR_COPY[state](username)}</div>
      </div>
    )
  }

  // Function declaration (hoisted) so renderSearchForm can reference it from the early error-state
  // return above, before this point in source order. The form navigates by GET naturally.
  function handleSubmit (e) {
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
      <div className="my-big-writeup-list__form-container">
        <form method="get" onSubmit={handleSubmit}>
          <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />

          {isAdmin ? (
            <div className="my-big-writeup-list__form-row">
              <label>
                Search for user:{' '}
                <input
                  type="text"
                  name="usersearch"
                  value={usersearch}
                  onChange={(e) => setUsersearch(e.target.value)}
                  className="my-big-writeup-list__input userComplete"
                />
              </label>
            </div>
          ) : (
            <>
              <input type="hidden" name="usersearch" value={username} />
              <div className="my-big-writeup-list__form-row">For: {username}</div>
            </>
          )}

          <div className="my-big-writeup-list__form-row">
            <label>
              Order By:{' '}
              <select
                name="orderby"
                value={orderBy}
                onChange={(e) => setOrderBy(e.target.value)}
                className="my-big-writeup-list__select"
              >
                {orderOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="my-big-writeup-list__form-row">
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
                className="my-big-writeup-list__delimiter-input"
                maxLength={1}
              />
            </label>
          </div>

          <div className="my-big-writeup-list__form-row">
            <button type="submit" name="sexisgood" value="submit" className="my-big-writeup-list__button">
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
        <pre className="my-big-writeup-list__pre">{lines.join('\n')}</pre>
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
          <table className="my-big-writeup-list__table">
            <thead>
              {/* One label per column (5) so the header reads 1:1 with the data. The rep block used
                  to be a single colSpan=2 "Rep", which read as off-by-one against the 5 data cells. */}
              <tr>
                <th className="my-big-writeup-list__th" align="left">
                  Writeup Title (type)
                </th>
                <th className="my-big-writeup-list__th">C!</th>
                <th className="my-big-writeup-list__th" align="center">Rep</th>
                <th className="my-big-writeup-list__th" align="center">(+/&minus;)</th>
                <th className="my-big-writeup-list__th" align="center">
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
                    className={index % 2 === 1 ? 'my-big-writeup-list__odd-row' : ''}
                  >
                    <td className="my-big-writeup-list__td" nowrap="nowrap">
                      <LinkNode nodeId={wu.parent_e2node} title={wu.title} />
                    </td>
                    <td className="my-big-writeup-list__td">
                      {wu.cooled ? <strong>{wu.cooled}C!</strong> : <span className="my-big-writeup-list__muted">&mdash;</span>}
                    </td>
                    {canSeeRep && wu.reputation !== undefined ? (
                      <>
                        <td className="my-big-writeup-list__td">{wu.reputation || 0}</td>
                        <td className="my-big-writeup-list__td my-big-writeup-list__td--small">
                          +{wu.upvotes}/-{wu.downvotes}
                        </td>
                      </>
                    ) : (
                      <td className="my-big-writeup-list__td" colSpan={2}></td>
                    )}
                    <td className="my-big-writeup-list__td my-big-writeup-list__td--right" nowrap="nowrap">
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
    <div className="my-big-writeup-list">
      {rawMode ? renderRawData() : renderTable()}
    </div>
  )
}

export default MyBigWriteupList

import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * MyBigWriteupList - Comprehensive listing of all writeups by a user
 * Styles in CSS: .my-big-writeup-list__*
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

  if (error) {
    return (
      <div className="my-big-writeup-list">
        {renderSearchForm()}
        <div className="my-big-writeup-list__error-box">{error}</div>
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
      <div className="my-big-writeup-list__form-container">
        <form method="get" onSubmit={handleSubmit}>
          <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />

          {is_admin ? (
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
              <tr>
                <th className="my-big-writeup-list__th" align="left">
                  Writeup Title (type)
                </th>
                <th className="my-big-writeup-list__th">C!</th>
                <th className="my-big-writeup-list__th" colSpan={2} align="center">
                  Rep
                </th>
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
                      {wu.cooled ? <strong>{wu.cooled}C!</strong> : ''}
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

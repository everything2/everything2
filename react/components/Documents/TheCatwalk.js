import React, { useState } from 'react'
import { formatShortDate } from '../../utils/dateFormat'

/**
 * TheCatwalk - Complete stylesheet browser
 * Styles in CSS: .catwalk__*
 *
 * Displays all stylesheets on E2 with sorting, filtering by author,
 * and pagination. Users can test different themes.
 */
const TheCatwalk = ({ data, user }) => {
  const isGuest = !!user?.guest
  const {
    message,
    stylesheets = [],
    current_style,
    has_custom_style,
    pagination = {},
    sort_options = [],
    current_sort,
    filter = {}
  } = data || {}

  const handleClearStyle = async (e) => {
    e.preventDefault()
    try {
      const res = await fetch('/api/customstyle/clear', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { Accept: 'application/json' },
      })
      const result = res.ok ? await res.json() : null
      if (result && result.success) {
        window.location.reload()
      }
    } catch (err) {
      // leave the page as-is on failure
    }
  }

  // Local state for form
  const [sortValue, setSortValue] = useState(current_sort || '0')
  const [filterUser, setFilterUser] = useState(filter.user_name || '')
  const [filterUserNot, setFilterUserNot] = useState(filter.is_not || false)

  // Guest message
  if (isGuest) {
    return (
      <div className="catwalk__guest-message">
        {message}
      </div>
    )
  }

  // Date validity + UTC-aware formatting delegate to shared utility.
  // MySQL zero-date ("0000-00-00 00:00:00") and ISO epoch-0 both return null.
  const isValidDate = (dateStr) => {
    if (typeof dateStr === 'string' && dateStr.startsWith('0000-00-00')) return false
    return formatShortDate(dateStr) !== null
  }
  const formatDate = (dateStr) => isValidDate(dateStr) ? formatShortDate(dateStr) : '—'

  // Calculate time since
  const timeSince = (dateStr) => {
    if (!isValidDate(dateStr)) return '—'
    const date = new Date(dateStr)
    const now = new Date()
    const diffMs = now - date
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

    if (diffDays < 1) return 'today'
    if (diffDays === 1) return '1 day ago'
    if (diffDays < 30) return `${diffDays} days ago`
    if (diffDays < 365) {
      const months = Math.floor(diffDays / 30)
      return months === 1 ? '1 month ago' : `${months} months ago`
    }
    const years = Math.floor(diffDays / 365)
    return years === 1 ? '1 year ago' : `${years} years ago`
  }

  // Build pagination links with current params
  const buildPageUrl = (newOffset) => {
    const params = new URLSearchParams()
    params.set('next', newOffset)
    if (filterUser) {
      params.set('filter_user', filterUser)
      if (filterUserNot) params.set('filter_user_not', '1')
    }
    params.set('fetch', '1')
    return `?${params.toString()}`
  }

  const { offset = 0, limit = 100, total = 0 } = pagination
  const showingStart = offset + 1
  const showingEnd = Math.min(offset + stylesheets.length, total)
  const hasPrev = offset > 0
  const hasNext = offset + limit < total

  return (
    <div className="catwalk">
      {current_style && (
        <div className="catwalk__current-style">
          What's your style? Currently{' '}
          <a href={`/node/${current_style.node_id}`} className="catwalk__link">
            {current_style.title}
          </a>.
        </div>
      )}

      <p className="catwalk__intro">
        A selection of popular stylesheets can be found at{' '}
        <a href="/title/Theme%20Nirvana" className="catwalk__link">Theme Nirvana</a>;
        below is a list of every stylesheet ever submitted here.
      </p>

      {has_custom_style ? (
        <div className="catwalk__custom-warning">
          <p>
            Note that you have customised your style using the{' '}
            <a href="/title/style%20defacer" className="catwalk__link">style defacer</a>,
            which is going to affect the formatting of any stylesheet you choose. If that's not
            what you want, you can reset it:
          </p>
          <button type="button" className="catwalk__clear-button" onClick={handleClearStyle}>
            Clear my custom style
          </button>
        </div>
      ) : (
        <p className="catwalk__intro">
          You can customise your stylesheet at the{' '}
          <a href="/title/style%20defacer" className="catwalk__link">style defacer</a>.
        </p>
      )}

      {/* Filter/Sort Form */}
      <form method="GET" action="/title/The+Catwalk" className="catwalk__filter-box">

        <div className="catwalk__filter-row">
          <label className="catwalk__label">Sort order:</label>
          <select
            name="ListNodesOfType_Sort"
            value={sortValue}
            onChange={(e) => setSortValue(e.target.value)}
            className="catwalk__select"
          >
            {sort_options.map(opt => (
              <option key={opt.value} value={opt.value}>{opt.label}</option>
            ))}
          </select>
        </div>

        <div className="catwalk__filter-controls">
          <span className="catwalk__label">Only show things</span>
          <label className="catwalk__checkbox-label">
            <input
              type="checkbox"
              name="filter_user_not"
              value="1"
              checked={filterUserNot}
              onChange={(e) => setFilterUserNot(e.target.checked)}
              className="catwalk__checkbox"
            />
            not
          </label>
          <span>written by</span>
          <input
            type="text"
            name="filter_user"
            value={filterUser}
            onChange={(e) => setFilterUser(e.target.value)}
            placeholder="username"
            className="catwalk__input"
          />
          <button type="submit" className="catwalk__btn">
            Fetch!
          </button>
        </div>
      </form>

      {/* Filter description */}
      {filter.user_name && (
        <p className="catwalk__intro catwalk__filter-desc">
          {filter.is_not ? 'Not created' : 'Created'} by{' '}
          <a href={`/user/${filter.user_name}`} className="catwalk__link">{filter.user_name}</a>
          {' '}(Showing items {showingStart} to {showingEnd}.)
        </p>
      )}

      {!filter.user_name && total > 0 && (
        <p className="catwalk__intro catwalk__filter-desc">
          Showing items {showingStart} to {showingEnd} of {total}.
        </p>
      )}

      {/* Stylesheets Table */}
      <div className="catwalk__table-container">
        <table className="catwalk__table">
          <thead>
            <tr>
              <th className="catwalk__th">Title</th>
              <th className="catwalk__th">Author</th>
              <th className="catwalk__th">Created</th>
              <th className="catwalk__th">Age</th>
              <th className="catwalk__th catwalk__th--narrow">&nbsp;</th>
            </tr>
          </thead>
          <tbody>
            {stylesheets.map((style, idx) => (
              <tr key={style.node_id}>
                <td className={`catwalk__td ${idx % 2 === 1 ? 'catwalk__td--odd' : 'catwalk__td--even'}`}>
                  <a href={`/node/${style.node_id}`} className="catwalk__link">
                    {style.title}
                  </a>
                </td>
                <td className={`catwalk__td ${idx % 2 === 1 ? 'catwalk__td--odd' : 'catwalk__td--even'}`}>
                  {style.author ? (
                    <a href={`/node/${style.author.node_id}`} className="catwalk__link">
                      {style.author.title}
                    </a>
                  ) : (
                    <span className="catwalk__empty">—</span>
                  )}
                </td>
                <td className={`catwalk__td ${idx % 2 === 1 ? 'catwalk__td--odd' : 'catwalk__td--even'}`}>
                  {formatDate(style.createtime)}
                </td>
                <td className={`catwalk__td ${idx % 2 === 1 ? 'catwalk__td--odd' : 'catwalk__td--even'}`}>
                  {timeSince(style.createtime)}
                </td>
                <td className={`catwalk__td ${idx % 2 === 1 ? 'catwalk__td--odd' : 'catwalk__td--even'}`}>
                  <a
                    href={`/title/Settings?trytheme=${style.node_id}`}
                    className="catwalk__test-link"
                  >
                    [ test ]
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {total > limit && (
        <div className="catwalk__pagination">
          <div>
            {hasPrev ? (
              <a href={buildPageUrl(offset - limit)} className="catwalk__nav-btn">
                ← Previous {limit}
              </a>
            ) : (
              <span className="catwalk__nav-btn catwalk__nav-btn--disabled">← Previous {limit}</span>
            )}
          </div>

          <span className="catwalk__page-info">
            {showingStart} - {showingEnd} of {total}
          </span>

          <div>
            {hasNext ? (
              <a href={buildPageUrl(offset + limit)} className="catwalk__nav-btn">
                Next {Math.min(limit, total - offset - limit)} →
              </a>
            ) : (
              <span className="catwalk__nav-btn catwalk__nav-btn--disabled">Next →</span>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

export default TheCatwalk

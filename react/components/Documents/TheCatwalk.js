import React, { useState } from 'react'

/**
 * TheCatwalk - Complete stylesheet browser
 *
 * Displays all stylesheets on E2 with sorting, filtering by author,
 * and pagination. Users can test different themes.
 */
const TheCatwalk = ({ data }) => {
  const {
    is_guest,
    message,
    stylesheets = [],
    current_style,
    has_custom_style,
    pagination = {},
    sort_options = [],
    current_sort,
    filter = {}
  } = data || {}

  // Local state for form
  const [sortValue, setSortValue] = useState(current_sort || '0')
  const [filterUser, setFilterUser] = useState(filter.user_name || '')
  const [filterUserNot, setFilterUserNot] = useState(filter.is_not || false)

  // Kernel Blue colors
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111'
  }

  // Guest message
  if (is_guest) {
    return (
      <div style={{ padding: '40px 20px', textAlign: 'center', color: colors.secondary }}>
        {message}
      </div>
    )
  }

  // Check if date is valid (not 0000-00-00 or invalid)
  const isValidDate = (dateStr) => {
    if (!dateStr) return false
    // MySQL zero date
    if (dateStr.startsWith('0000-00-00')) return false
    const date = new Date(dateStr)
    return !isNaN(date.getTime())
  }

  // Format date
  const formatDate = (dateStr) => {
    if (!isValidDate(dateStr)) return '—'
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
  }

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

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '1100px',
    margin: '0 auto'
  }

  const introStyle = {
    color: colors.text,
    lineHeight: '1.6',
    marginBottom: '20px'
  }

  const currentStyleStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: colors.background,
    borderRadius: '6px',
    borderLeft: `4px solid ${colors.accent}`
  }

  const customStyleWarningStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#fff8e1',
    borderRadius: '6px',
    border: '1px solid #ffcc02',
    lineHeight: '1.6'
  }

  const filterBoxStyle = {
    backgroundColor: colors.background,
    padding: '20px',
    borderRadius: '8px',
    marginBottom: '20px',
    border: `1px solid ${colors.secondary}20`
  }

  const selectStyle = {
    padding: '8px 12px',
    border: `1px solid ${colors.secondary}`,
    borderRadius: '4px',
    fontSize: '14px',
    backgroundColor: '#fff',
    marginRight: '15px'
  }

  const inputStyle = {
    padding: '8px 12px',
    border: `1px solid ${colors.secondary}`,
    borderRadius: '4px',
    fontSize: '14px',
    width: '200px'
  }

  const buttonStyle = {
    padding: '8px 16px',
    backgroundColor: colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: 'pointer'
  }

  const tableStyle = {
    width: '100%',
    borderCollapse: 'collapse',
    backgroundColor: '#fff',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
    borderRadius: '8px',
    overflow: 'hidden'
  }

  const thStyle = {
    backgroundColor: colors.primary,
    color: '#fff',
    padding: '12px 15px',
    textAlign: 'left',
    fontSize: '14px',
    fontWeight: '600'
  }

  const tdStyle = (isOdd) => ({
    padding: '10px 15px',
    borderBottom: '1px solid #eee',
    fontSize: '14px',
    backgroundColor: isOdd ? colors.background : '#fff'
  })

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    fontWeight: '500'
  }

  const testLinkStyle = {
    color: colors.secondary,
    textDecoration: 'none',
    fontSize: '13px'
  }

  const paginationStyle = {
    display: 'flex',
    justifyContent: 'space-between',
    marginTop: '20px',
    padding: '15px',
    backgroundColor: colors.background,
    borderRadius: '4px'
  }

  const navButtonStyle = (disabled) => ({
    padding: '8px 16px',
    backgroundColor: disabled ? '#ccc' : colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: disabled ? 'not-allowed' : 'pointer',
    textDecoration: 'none'
  })

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
    <div style={containerStyle}>
      {current_style && (
        <div style={currentStyleStyle}>
          What's your style? Currently{' '}
          <a href={`/node/${current_style.node_id}`} style={linkStyle}>
            {current_style.title}
          </a>.
        </div>
      )}

      <p style={introStyle}>
        A selection of popular stylesheets can be found at{' '}
        <a href="/title/Theme%20Nirvana" style={linkStyle}>Theme Nirvana</a>;
        below is a list of every stylesheet ever submitted here.
      </p>

      {has_custom_style ? (
        <div style={customStyleWarningStyle}>
          Note that you have customised your style using the{' '}
          <a href="/title/style%20defacer" style={linkStyle}>style defacer</a>,
          which is going to affect the formatting of any stylesheet you choose.{' '}
          <a href="?clearVandalism=true" style={linkStyle}>Click here to clear that out</a>{' '}
          if that's not what you want. If you want to create a whole new stylesheet,
          visit <a href="/title/the%20draughty%20atelier" style={linkStyle}>the draughty atelier</a>.
        </div>
      ) : (
        <p style={introStyle}>
          You can customise your stylesheet at the{' '}
          <a href="/title/style%20defacer" style={linkStyle}>style defacer</a> or,
          if you're feeling brave, create a whole new stylesheet at{' '}
          <a href="/title/the%20draughty%20atelier" style={linkStyle}>the draughty atelier</a>.
        </p>
      )}

      {/* Filter/Sort Form */}
      <form method="POST" style={filterBoxStyle}>
        <input type="hidden" name="node_id" value={data?.node_id || ''} />

        <div style={{ marginBottom: '15px' }}>
          <label style={{ marginRight: '10px', fontWeight: '500' }}>Sort order:</label>
          <select
            name="ListNodesOfType_Sort"
            value={sortValue}
            onChange={(e) => setSortValue(e.target.value)}
            style={selectStyle}
          >
            {sort_options.map(opt => (
              <option key={opt.value} value={opt.value}>{opt.label}</option>
            ))}
          </select>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
          <span style={{ fontWeight: '500' }}>Only show things</span>
          <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
            <input
              type="checkbox"
              name="filter_user_not"
              value="1"
              checked={filterUserNot}
              onChange={(e) => setFilterUserNot(e.target.checked)}
              style={{ marginRight: '5px' }}
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
            style={inputStyle}
          />
          <button type="submit" name="fetch" value="1" style={buttonStyle}>
            Fetch!
          </button>
        </div>
      </form>

      {/* Filter description */}
      {filter.user_name && (
        <p style={{ ...introStyle, fontStyle: 'italic' }}>
          {filter.is_not ? 'Not created' : 'Created'} by{' '}
          <a href={`/user/${filter.user_name}`} style={linkStyle}>{filter.user_name}</a>
          {' '}(Showing items {showingStart} to {showingEnd}.)
        </p>
      )}

      {!filter.user_name && total > 0 && (
        <p style={{ ...introStyle, fontStyle: 'italic' }}>
          Showing items {showingStart} to {showingEnd} of {total}.
        </p>
      )}

      {/* Stylesheets Table */}
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Title</th>
            <th style={thStyle}>Author</th>
            <th style={thStyle}>Created</th>
            <th style={thStyle}>Age</th>
            <th style={{ ...thStyle, width: '60px' }}>&nbsp;</th>
          </tr>
        </thead>
        <tbody>
          {stylesheets.map((style, idx) => (
            <tr key={style.node_id}>
              <td style={tdStyle(idx % 2 === 1)}>
                <a href={`/node/${style.node_id}`} style={linkStyle}>
                  {style.title}
                </a>
              </td>
              <td style={tdStyle(idx % 2 === 1)}>
                {style.author ? (
                  <a href={`/node/${style.author.node_id}`} style={linkStyle}>
                    {style.author.title}
                  </a>
                ) : (
                  <span style={{ color: '#999' }}>—</span>
                )}
              </td>
              <td style={tdStyle(idx % 2 === 1)}>
                {formatDate(style.createtime)}
              </td>
              <td style={tdStyle(idx % 2 === 1)}>
                {timeSince(style.createtime)}
              </td>
              <td style={tdStyle(idx % 2 === 1)}>
                <a
                  href={`/?displaytype=choosetheme&theme=${style.node_id}&noscript=1`}
                  style={testLinkStyle}
                  onFocus={(e) => {
                    e.target.href = e.target.href.replace('&noscript=1', '')
                  }}
                >
                  [ test ]
                </a>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Pagination */}
      {total > limit && (
        <div style={paginationStyle}>
          <div>
            {hasPrev ? (
              <a href={buildPageUrl(offset - limit)} style={navButtonStyle(false)}>
                ← Previous {limit}
              </a>
            ) : (
              <span style={navButtonStyle(true)}>← Previous {limit}</span>
            )}
          </div>

          <span style={{ fontSize: '14px', color: colors.secondary, alignSelf: 'center' }}>
            {showingStart} - {showingEnd} of {total}
          </span>

          <div>
            {hasNext ? (
              <a href={buildPageUrl(offset + limit)} style={navButtonStyle(false)}>
                Next {Math.min(limit, total - offset - limit)} →
              </a>
            ) : (
              <span style={navButtonStyle(true)}>Next →</span>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

export default TheCatwalk

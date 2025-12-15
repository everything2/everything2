import React, { useState, useEffect, useCallback } from 'react'

/**
 * CoolArchive - Browse the complete archive of editor-selected (C!'ed) content
 *
 * Features:
 * - Multiple sort options (most recent, oldest, title, reputation, most cooled)
 * - Filter by specific user (cooled by or written by)
 * - Paginated results with infinite scroll support
 * - Modern Kernel Blue UI with responsive design
 */
const CoolArchive = ({ data, user }) => {
  const { feed_url } = data || {}

  // Filter state
  const [sortBy, setSortBy] = useState('tstamp DESC')
  const [userAction, setUserAction] = useState('cooled')
  const [username, setUsername] = useState('')
  const [searchUsername, setSearchUsername] = useState('') // Actual username being searched

  // Data state
  const [writeups, setWriteups] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [offset, setOffset] = useState(0)
  const [hasMore, setHasMore] = useState(true)

  const pageSize = 50

  // Kernel Blue colors
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111'
  }

  // Sort options
  const sortOptions = [
    { value: 'tstamp DESC', label: 'Most Recently Cooled' },
    { value: 'tstamp ASC', label: 'Oldest Cooled' },
    { value: 'title ASC', label: 'Title (requires user)' },
    { value: 'title DESC', label: 'Title (Reverse)' },
    { value: 'reputation DESC, title ASC', label: 'Highest Reputation' },
    { value: 'reputation ASC, title ASC', label: 'Lowest Reputation' },
    { value: 'cooled DESC, title ASC', label: 'Most Cooled' }
  ]

  const sortNeedsUser = (sort) => {
    return sort.includes('title') || sort.includes('reputation') || sort.includes('cooled')
  }

  // Fetch writeups
  // newOffset parameter is used for pagination to avoid stale closure issues
  const fetchWriteups = useCallback(async (reset = false, newOffset = null) => {
    // Don't fetch if sort requires user but none provided
    if (sortNeedsUser(sortBy) && !searchUsername) {
      if (reset) {
        setWriteups([])
        setError('This sort option requires a username')
      }
      return
    }

    setLoading(true)
    setError(null)

    try {
      const currentOffset = reset ? 0 : (newOffset !== null ? newOffset : offset)
      const params = new URLSearchParams({
        orderby: sortBy,
        useraction: userAction,
        limit: pageSize,
        offset: currentOffset
      })

      if (searchUsername) {
        params.append('cooluser', searchUsername)
      }

      const response = await fetch(`/api/cool_archive?${params}`)
      const result = await response.json()

      if (result.success) {
        if (reset) {
          setWriteups(result.writeups || [])
          setOffset(0)
        } else {
          setWriteups(prev => [...prev, ...(result.writeups || [])])
        }
        setHasMore(result.has_more || false)
      } else {
        setError(result.error || 'Failed to load writeups')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    }

    setLoading(false)
  }, [sortBy, userAction, searchUsername, offset])

  // Initial load and reset on filter change
  useEffect(() => {
    fetchWriteups(true)
  }, [sortBy, userAction, searchUsername])

  // Handle search submit
  const handleSearch = (e) => {
    e.preventDefault()
    setSearchUsername(username.trim())
    setOffset(0)
  }

  // Load more (pagination)
  const loadMore = () => {
    if (!loading && hasMore) {
      const newOffset = offset + pageSize
      setOffset(newOffset)
      fetchWriteups(false, newOffset)
    }
  }

  // Styles
  const containerStyle = {
    padding: '20px',
    maxWidth: '1200px',
    margin: '0 auto'
  }

  const headerStyle = {
    marginBottom: '30px',
    borderBottom: `2px solid ${colors.primary}`,
    paddingBottom: '15px'
  }

  const titleStyle = {
    fontSize: '28px',
    color: colors.primary,
    marginBottom: '10px'
  }

  const introStyle = {
    color: colors.secondary,
    lineHeight: '1.6',
    marginBottom: '10px'
  }

  const filterBoxStyle = {
    backgroundColor: colors.background,
    padding: '20px',
    borderRadius: '8px',
    marginBottom: '20px',
    border: `1px solid ${colors.secondary}20`
  }

  const filterRowStyle = {
    display: 'flex',
    gap: '15px',
    alignItems: 'flex-end',
    flexWrap: 'wrap',
    marginBottom: '10px'
  }

  const filterGroupStyle = {
    display: 'flex',
    flexDirection: 'column',
    gap: '5px',
    flex: '1',
    minWidth: '200px'
  }

  const labelStyle = {
    fontSize: '13px',
    fontWeight: '600',
    color: colors.primary
  }

  const selectStyle = {
    padding: '8px 12px',
    border: `1px solid ${colors.secondary}`,
    borderRadius: '4px',
    fontSize: '14px',
    backgroundColor: '#fff',
    color: colors.text,
    cursor: 'pointer'
  }

  const inputStyle = {
    padding: '8px 12px',
    border: `1px solid ${colors.secondary}`,
    borderRadius: '4px',
    fontSize: '14px',
    backgroundColor: '#fff',
    color: colors.text
  }

  const buttonStyle = {
    padding: '9px 20px',
    backgroundColor: colors.highlight,
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: 'pointer',
    transition: 'background-color 0.2s'
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
    padding: '12px 15px',
    borderBottom: '1px solid #eee',
    fontSize: '14px',
    backgroundColor: isOdd ? colors.background : '#fff'
  })

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none',
    fontWeight: '500'
  }

  const authorLinkStyle = {
    color: colors.secondary,
    textDecoration: 'none'
  }

  const loadMoreButtonStyle = {
    ...buttonStyle,
    width: '100%',
    marginTop: '20px',
    padding: '12px',
    backgroundColor: loading ? '#999' : colors.accent,
    cursor: loading ? 'wait' : 'pointer'
  }

  const errorStyle = {
    padding: '15px',
    backgroundColor: '#fff5f5',
    border: '1px solid #feb2b2',
    borderRadius: '4px',
    color: '#c53030',
    marginBottom: '20px'
  }

  const emptyStyle = {
    padding: '40px',
    textAlign: 'center',
    color: colors.secondary,
    fontSize: '16px'
  }

  return (
    <div style={containerStyle}>
      {/* Header */}
      <div style={headerStyle}>
        <h1 style={titleStyle}>Cool Archive</h1>
        <p style={introStyle}>
          Welcome to the Cool Archive page — where you can see the entire library of
          especially worthwhile content in the mess of Everything history. Enjoy.
        </p>
        {feed_url && (
          <p style={{ fontSize: '12px', color: colors.secondary }}>
            <a href={feed_url} style={linkStyle}>RSS Feed</a>
          </p>
        )}
      </div>

      {/* Filters */}
      <form onSubmit={handleSearch}>
        <div style={filterBoxStyle}>
          <div style={filterRowStyle}>
            {/* Sort by */}
            <div style={filterGroupStyle}>
              <label style={labelStyle}>Order by:</label>
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                style={selectStyle}
              >
                {sortOptions.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>

            {/* User action */}
            <div style={{ ...filterGroupStyle, flex: '0 0 150px' }}>
              <label style={labelStyle}>Action:</label>
              <select
                value={userAction}
                onChange={(e) => setUserAction(e.target.value)}
                style={selectStyle}
              >
                <option value="cooled">Cooled by</option>
                <option value="written">Written by</option>
              </select>
            </div>

            {/* Username */}
            <div style={filterGroupStyle}>
              <label style={labelStyle}>User:</label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Enter username..."
                style={inputStyle}
              />
            </div>

            {/* Search button */}
            <button type="submit" style={buttonStyle}>
              Search
            </button>
          </div>

          {sortNeedsUser(sortBy) && (
            <p style={{ fontSize: '12px', color: colors.secondary, marginTop: '10px', marginBottom: '0' }}>
              <strong>Note:</strong> This sort option requires entering a username
            </p>
          )}
        </div>
      </form>

      {/* Error message */}
      {error && (
        <div style={errorStyle}>
          {error}
        </div>
      )}

      {/* Results table */}
      {writeups.length > 0 ? (
        <>
          <table style={tableStyle}>
            <thead>
              <tr>
                <th style={thStyle}>Writeup</th>
                <th style={{ ...thStyle, width: '200px' }}>Written by</th>
                <th style={{ ...thStyle, width: '200px' }}>Cooled by</th>
              </tr>
            </thead>
            <tbody>
              {writeups.map((wu, idx) => (
                <tr key={wu.writeup_id || idx}>
                  <td style={tdStyle(idx % 2 === 1)}>
                    <a href={`/node/${wu.parent_node_id}`} style={linkStyle}>
                      {wu.parent_title}
                    </a>
                    {wu.writeup_type && (
                      <span style={{ fontSize: '12px', color: colors.secondary, marginLeft: '8px' }}>
                        ({wu.writeup_type})
                      </span>
                    )}
                  </td>
                  <td style={tdStyle(idx % 2 === 1)}>
                    <a href={`/user/${wu.author_name}`} style={authorLinkStyle}>
                      {wu.author_name}
                    </a>
                  </td>
                  <td style={tdStyle(idx % 2 === 1)}>
                    <a href={`/user/${wu.cooled_by_name}`} style={authorLinkStyle}>
                      {wu.cooled_by_name}
                    </a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {/* Load more button */}
          {hasMore && (
            <button
              onClick={loadMore}
              disabled={loading}
              style={loadMoreButtonStyle}
            >
              {loading ? 'Loading...' : `Load Next ${pageSize} Writeups`}
            </button>
          )}

          {!hasMore && writeups.length > 0 && (
            <p style={{ textAlign: 'center', marginTop: '20px', color: colors.secondary }}>
              End of results
            </p>
          )}
        </>
      ) : !loading && !error && (
        <div style={emptyStyle}>
          {sortNeedsUser(sortBy) && !searchUsername
            ? 'Enter a username to search'
            : 'No writeups found'}
        </div>
      )}

      {/* Loading indicator */}
      {loading && writeups.length === 0 && (
        <div style={emptyStyle}>
          Loading...
        </div>
      )}
    </div>
  )
}

export default CoolArchive

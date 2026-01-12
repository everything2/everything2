import React, { useState, useEffect, useCallback, useRef } from 'react'
import { FaUser, FaTimes } from 'react-icons/fa'
import { useIsMobile } from '../../hooks/useMediaQuery'

/**
 * UserSearchField - Inline user search input with dropdown suggestions
 */
const UserSearchField = ({ id, name, value, onChange, onSubmit, placeholder, colors }) => {
  const [inputValue, setInputValue] = useState(value || '')
  const [suggestions, setSuggestions] = useState([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)
  const [loading, setLoading] = useState(false)

  const searchTimeoutRef = useRef(null)
  const containerRef = useRef(null)

  // Sync input with external value changes
  useEffect(() => {
    setInputValue(value || '')
  }, [value])

  // Search for users via API
  const searchUsers = useCallback(async (query) => {
    if (query.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      return
    }

    setLoading(true)
    try {
      const response = await fetch(
        `/api/node_search?q=${encodeURIComponent(query)}&scope=users&limit=10`
      )
      const data = await response.json()
      if (data.success && data.results) {
        setSuggestions(data.results)
        setShowSuggestions(data.results.length > 0)
        setSelectedIndex(-1)
      }
    } catch (err) {
      console.error('User search failed:', err)
      setSuggestions([])
    } finally {
      setLoading(false)
    }
  }, [])

  // Handle input change with debounced search
  const handleInputChange = useCallback((e) => {
    const newValue = e.target.value
    setInputValue(newValue)
    onChange(newValue)

    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchUsers(newValue.trim())
    }, 200)
  }, [searchUsers, onChange])

  // Handle selecting a user from suggestions
  const handleSelectUser = useCallback((user) => {
    setInputValue(user.title)
    onChange(user.title)
    setSuggestions([])
    setShowSuggestions(false)
    setSelectedIndex(-1)
    // Trigger submit when user is selected from dropdown
    if (onSubmit) {
      onSubmit(user.title)
    }
  }, [onChange, onSubmit])

  // Handle keyboard navigation
  const handleKeyDown = useCallback((e) => {
    if (e.key === 'Enter') {
      if (selectedIndex >= 0 && suggestions[selectedIndex]) {
        e.preventDefault()
        handleSelectUser(suggestions[selectedIndex])
      }
      // Let form handle Enter if no suggestion selected
      return
    }

    if (!showSuggestions || suggestions.length === 0) {
      return
    }

    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setSelectedIndex(prev =>
        prev < suggestions.length - 1 ? prev + 1 : prev
      )
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setSelectedIndex(prev => prev > 0 ? prev - 1 : -1)
    } else if (e.key === 'Escape') {
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedIndex, handleSelectUser])

  // Close suggestions when clicking outside
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (containerRef.current && !containerRef.current.contains(e.target)) {
        setShowSuggestions(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (searchTimeoutRef.current) {
        clearTimeout(searchTimeoutRef.current)
      }
    }
  }, [])

  // Clear button handler
  const handleClear = () => {
    setInputValue('')
    onChange('')
    setSuggestions([])
    setShowSuggestions(false)
  }

  const styles = {
    container: {
      position: 'relative',
      flex: '1',
      minWidth: '200px'
    },
    inputWrapper: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center'
    },
    icon: {
      position: 'absolute',
      left: 10,
      color: colors?.secondary || '#507898',
      fontSize: 14,
      pointerEvents: 'none'
    },
    input: {
      width: '100%',
      padding: '8px 32px 8px 32px',
      fontSize: 14,
      border: `1px solid ${colors?.secondary || '#507898'}`,
      borderRadius: 4,
      boxSizing: 'border-box',
      backgroundColor: '#fff'
    },
    loadingIndicator: {
      position: 'absolute',
      right: 32,
      color: colors?.secondary || '#507898',
      fontSize: 12
    },
    clearButton: {
      position: 'absolute',
      right: 8,
      background: 'none',
      border: 'none',
      color: '#999',
      cursor: 'pointer',
      padding: 4,
      fontSize: 12,
      display: 'flex',
      alignItems: 'center'
    },
    dropdown: {
      position: 'absolute',
      top: '100%',
      left: 0,
      right: 0,
      backgroundColor: '#fff',
      border: `1px solid ${colors?.secondary || '#507898'}`,
      borderTop: 'none',
      borderRadius: '0 0 4px 4px',
      boxShadow: '0 4px 8px rgba(0,0,0,0.1)',
      maxHeight: 200,
      overflowY: 'auto',
      zIndex: 100
    },
    suggestionItem: {
      padding: '10px 12px',
      cursor: 'pointer',
      fontSize: 14,
      color: colors?.primary || '#38495e',
      borderBottom: '1px solid #eee',
      display: 'flex',
      alignItems: 'center',
      gap: 8
    },
    suggestionItemSelected: {
      backgroundColor: '#e8f4f8',
      color: colors?.highlight || '#4060b0'
    },
    suggestionIcon: {
      fontSize: 12,
      color: colors?.secondary || '#507898'
    }
  }

  return (
    <div ref={containerRef} style={styles.container}>
      <div style={styles.inputWrapper}>
        <FaUser style={styles.icon} />
        <input
          type="text"
          id={id}
          name={name}
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          placeholder={placeholder}
          style={styles.input}
          autoComplete="off"
        />
        {loading && <span style={styles.loadingIndicator}>...</span>}
        {inputValue && !loading && (
          <button
            type="button"
            onClick={handleClear}
            style={styles.clearButton}
            title="Clear"
          >
            <FaTimes />
          </button>
        )}

        {/* Suggestions dropdown */}
        {showSuggestions && suggestions.length > 0 && (
          <div style={styles.dropdown}>
            {suggestions.map((user, index) => (
              <div
                key={user.node_id}
                onClick={() => handleSelectUser(user)}
                onMouseEnter={() => setSelectedIndex(index)}
                style={{
                  ...styles.suggestionItem,
                  ...(index === selectedIndex ? styles.suggestionItemSelected : {})
                }}
              >
                <FaUser style={styles.suggestionIcon} />
                <span>{user.title}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

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
  const isMobile = useIsMobile()

  // Pre-fill with foruser parameter from URL (e.g., from homenode links)
  const urlParams = new URLSearchParams(window.location.search)
  const initialUsername = urlParams.get('foruser') || ''

  // Filter state
  const [sortBy, setSortBy] = useState('tstamp DESC')
  const [userAction, setUserAction] = useState('cooled')
  const [username, setUsername] = useState(initialUsername)
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

  // Styles - responsive padding
  const containerStyle = {
    padding: isMobile ? '0' : '20px',
    maxWidth: isMobile ? '100%' : '1200px',
    margin: '0 auto'
  }

  const introStyle = {
    color: colors.secondary,
    lineHeight: '1.6',
    marginTop: 0,
    marginBottom: isMobile ? '12px' : '16px',
    fontSize: isMobile ? '14px' : '16px'
  }

  const filterBoxStyle = {
    backgroundColor: colors.background,
    padding: isMobile ? '12px' : '20px',
    borderRadius: isMobile ? '0' : '8px',
    marginBottom: isMobile ? '12px' : '20px',
    border: `1px solid ${colors.secondary}20`
  }

  const filterRowStyle = {
    display: 'flex',
    gap: isMobile ? '10px' : '15px',
    alignItems: 'flex-end',
    flexWrap: 'wrap',
    marginBottom: '10px'
  }

  const filterGroupStyle = {
    display: 'flex',
    flexDirection: 'column',
    gap: '5px',
    flex: '1',
    minWidth: isMobile ? '100%' : '200px'
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
      {/* Intro - no H1 since PageHeader already renders the title */}
      <p style={introStyle}>
        Browse the complete archive of editor-selected content from Everything2's history.
        These are the writeups our editors have recognized as especially noteworthy.
      </p>

      {/* Filters */}
      <form onSubmit={handleSearch}>
        <div style={filterBoxStyle}>
          <div style={filterRowStyle}>
            {/* Sort by */}
            <div style={filterGroupStyle}>
              <label htmlFor="cool-archive-sort" style={labelStyle}>Order by:</label>
              <select
                id="cool-archive-sort"
                name="sort"
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
              <label htmlFor="cool-archive-action" style={labelStyle}>Action:</label>
              <select
                id="cool-archive-action"
                name="action"
                value={userAction}
                onChange={(e) => setUserAction(e.target.value)}
                style={selectStyle}
              >
                <option value="cooled">Cooled by</option>
                <option value="written">Written by</option>
              </select>
            </div>

            {/* Username with search */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '5px', flex: '1', minWidth: '200px' }}>
              <label htmlFor="cool-archive-user" style={labelStyle}>User:</label>
              <UserSearchField
                id="cool-archive-user"
                name="user"
                value={username}
                onChange={setUsername}
                onSubmit={(selectedUsername) => {
                  setSearchUsername(selectedUsername)
                  setOffset(0)
                }}
                placeholder="Search for user..."
                colors={colors}
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
                <tr key={`${wu.writeup_id}-${wu.cooled_by_id || idx}`}>
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

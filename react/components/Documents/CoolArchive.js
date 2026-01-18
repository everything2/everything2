import React, { useState, useEffect, useCallback, useRef } from 'react'
import { FaUser, FaTimes } from 'react-icons/fa'
import { useIsMobile } from '../../hooks/useMediaQuery'

/**
 * UserSearchField - Inline user search input with dropdown suggestions
 */
const UserSearchField = ({ id, name, value, onChange, onSubmit, placeholder }) => {
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

  return (
    <div ref={containerRef} className="cool-archive__user-search">
      <div className="cool-archive__user-search-wrapper">
        <FaUser className="cool-archive__user-search-icon" />
        <input
          type="text"
          id={id}
          name={name}
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          placeholder={placeholder}
          className="cool-archive__user-search-input"
          autoComplete="off"
        />
        {loading && <span className="cool-archive__user-search-loading">...</span>}
        {inputValue && !loading && (
          <button
            type="button"
            onClick={handleClear}
            className="cool-archive__user-search-clear"
            title="Clear"
          >
            <FaTimes />
          </button>
        )}

        {/* Suggestions dropdown */}
        {showSuggestions && suggestions.length > 0 && (
          <div className="cool-archive__user-search-dropdown">
            {suggestions.map((user, index) => (
              <div
                key={user.node_id}
                onClick={() => handleSelectUser(user)}
                onMouseEnter={() => setSelectedIndex(index)}
                className={`cool-archive__user-search-item${index === selectedIndex ? ' cool-archive__user-search-item--selected' : ''}`}
              >
                <FaUser className="cool-archive__user-search-item-icon" />
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

  // Container class based on mobile
  const containerClass = `cool-archive${isMobile ? ' cool-archive--mobile' : ''}`

  return (
    <div className={containerClass}>
      {/* Intro - no H1 since PageHeader already renders the title */}
      <p className="cool-archive__intro">
        Browse the complete archive of editor-selected content from Everything2's history.
        These are the writeups our editors have recognized as especially noteworthy.
      </p>

      {/* Filters */}
      <form onSubmit={handleSearch}>
        <div className="cool-archive__filters">
          <div className="cool-archive__filter-row">
            {/* Sort by */}
            <div className="cool-archive__filter-group">
              <label htmlFor="cool-archive-sort" className="cool-archive__label">Order by:</label>
              <select
                id="cool-archive-sort"
                name="sort"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="cool-archive__select"
              >
                {sortOptions.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>

            {/* User action */}
            <div className="cool-archive__filter-group cool-archive__filter-group--action">
              <label htmlFor="cool-archive-action" className="cool-archive__label">Action:</label>
              <select
                id="cool-archive-action"
                name="action"
                value={userAction}
                onChange={(e) => setUserAction(e.target.value)}
                className="cool-archive__select"
              >
                <option value="cooled">Cooled by</option>
                <option value="written">Written by</option>
              </select>
            </div>

            {/* Username with search */}
            <div className="cool-archive__filter-group">
              <label htmlFor="cool-archive-user" className="cool-archive__label">User:</label>
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
              />
            </div>

            {/* Search button */}
            <button type="submit" className="cool-archive__search-btn">
              Search
            </button>
          </div>

          {sortNeedsUser(sortBy) && (
            <p className="cool-archive__note">
              <strong>Note:</strong> This sort option requires entering a username
            </p>
          )}
        </div>
      </form>

      {/* Error message */}
      {error && (
        <div className="cool-archive__error">
          {error}
        </div>
      )}

      {/* Results table */}
      {writeups.length > 0 ? (
        <>
          <table className="cool-archive__table">
            <thead>
              <tr>
                <th className="cool-archive__th">Writeup</th>
                <th className="cool-archive__th cool-archive__th--author">Written by</th>
                <th className="cool-archive__th cool-archive__th--author">Cooled by</th>
              </tr>
            </thead>
            <tbody>
              {writeups.map((wu, idx) => (
                <tr key={`${wu.writeup_id}-${wu.cooled_by_id || idx}`}>
                  <td className={`cool-archive__td${idx % 2 === 1 ? ' cool-archive__td--odd' : ''}`}>
                    <a href={`/node/${wu.parent_node_id}`} className="cool-archive__writeup-link">
                      {wu.parent_title}
                    </a>
                    {wu.writeup_type && (
                      <span className="cool-archive__writeup-type">
                        ({wu.writeup_type})
                      </span>
                    )}
                  </td>
                  <td className={`cool-archive__td${idx % 2 === 1 ? ' cool-archive__td--odd' : ''}`}>
                    <a href={`/user/${wu.author_name}`} className="cool-archive__author-link">
                      {wu.author_name}
                    </a>
                  </td>
                  <td className={`cool-archive__td${idx % 2 === 1 ? ' cool-archive__td--odd' : ''}`}>
                    <a href={`/user/${wu.cooled_by_name}`} className="cool-archive__author-link">
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
              className="cool-archive__load-more"
            >
              {loading ? 'Loading...' : `Load Next ${pageSize} Writeups`}
            </button>
          )}

          {!hasMore && writeups.length > 0 && (
            <p className="cool-archive__end-results">
              End of results
            </p>
          )}
        </>
      ) : !loading && !error && (
        <div className="cool-archive__empty">
          {sortNeedsUser(sortBy) && !searchUsername
            ? 'Enter a username to search'
            : 'No writeups found'}
        </div>
      )}

      {/* Loading indicator */}
      {loading && writeups.length === 0 && (
        <div className="cool-archive__empty">
          Loading...
        </div>
      )}
    </div>
  )
}

export default CoolArchive

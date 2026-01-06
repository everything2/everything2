import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import LinkNode from '../LinkNode'

// Notable E2 contributors for suggestions
const NOTABLE_USERS = [
  'Tem42', 'wertperch', 'The Custodian', 'mauler', 'Glowing Fish',
  'DonJaime', 'Jet-Poop', 'Cletus the Foetus', 'borgo', 'lizardinlaw',
  'Simulacron3', 'etouffee', 'lostcauser', 'artman2003', 'Zephronias',
  'JD', 'Pandeism Fish', 'Chord', 'Yurei', 'E2D2', 'Clockmaker'
]

// Randomly select n items from an array
const selectRandom = (arr, n) => {
  const shuffled = [...arr].sort(() => Math.random() - 0.5)
  return shuffled.slice(0, n)
}

// Empty state component with randomized suggestions
const EmptyState = ({ onSelectUser }) => {
  // Randomly select 3 users on mount (useMemo ensures consistent selection during render)
  const suggestedUsers = useMemo(() => selectRandom(NOTABLE_USERS, 3), [])

  return (
    <div style={styles.emptyState}>
      <p>Enter a username above to browse their writeups.</p>
      <p style={styles.hint}>
        Try searching for some of E2's notable contributors like{' '}
        {suggestedUsers.map((name, index) => (
          <span key={name}>
            {index > 0 && (index === suggestedUsers.length - 1 ? ', or ' : ', ')}
            <button
              style={styles.suggestionLink}
              onClick={() => onSelectUser(name)}
            >
              {name}
            </button>
          </span>
        ))}.
      </p>
    </div>
  )
}

/**
 * Everything User Search - Browse writeups by user
 *
 * A modern, clean interface for discovering content by author.
 * Supports sorting, pagination, and filtering.
 */
const UserSearch = ({ data, user }) => {
  const [username, setUsername] = useState(data.initialUsername || '')
  const [searchInput, setSearchInput] = useState(data.initialUsername || '')
  const [orderby, setOrderby] = useState(data.initialOrderby || 'publishtime_desc')
  const [page, setPage] = useState(data.initialPage || 1)
  const [filterHidden, setFilterHidden] = useState(data.initialFilterHidden || 0)

  const [results, setResults] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  // Autocomplete state
  const [suggestions, setSuggestions] = useState([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedSuggestionIndex, setSelectedSuggestionIndex] = useState(-1)
  const searchTimeoutRef = useRef(null)
  const inputRef = useRef(null)

  // Sort options for dropdown
  const sortOptions = [
    { value: 'publishtime_desc', label: 'Newest First' },
    { value: 'publishtime_asc', label: 'Oldest First' },
    { value: 'title_asc', label: 'Title A-Z' },
    { value: 'title_desc', label: 'Title Z-A' },
    { value: 'reputation_desc', label: 'Highest Reputation' },
    { value: 'reputation_asc', label: 'Lowest Reputation' },
    { value: 'cools_desc', label: 'Most Cools' },
    { value: 'cools_asc', label: 'Fewest Cools' },
    { value: 'hits_desc', label: 'Most Viewed' },
    { value: 'hits_asc', label: 'Least Viewed' },
    { value: 'type_asc', label: 'By Type' },
    { value: 'random', label: 'Random' }
  ]

  // Column sort configuration - maps column key to sort field
  const columnSortMap = {
    cools: 'cools',
    title: 'title',
    reputation: 'reputation',
    hidden: null, // Not sortable
    notes: null,  // Not sortable
    publishtime: 'publishtime',
    hits: 'hits',
    type: 'type'
  }

  // Get current sort info from orderby state
  const getCurrentSort = () => {
    const match = orderby.match(/^(\w+?)_(asc|desc)$/)
    if (match) {
      return { field: match[1], direction: match[2] }
    }
    if (orderby === 'random') {
      return { field: 'random', direction: null }
    }
    return { field: 'publishtime', direction: 'desc' }
  }

  // Handle column header click for sorting
  const handleColumnSort = (columnKey) => {
    const sortField = columnSortMap[columnKey]
    if (!sortField) return // Column not sortable

    const current = getCurrentSort()
    let newOrderby

    if (current.field === sortField) {
      // Same column - toggle direction
      newOrderby = `${sortField}_${current.direction === 'desc' ? 'asc' : 'desc'}`
    } else {
      // Different column - default to desc (except title which defaults to asc)
      const defaultDir = sortField === 'title' ? 'asc' : 'desc'
      newOrderby = `${sortField}_${defaultDir}`
    }

    setOrderby(newOrderby)
    setPage(1)
  }

  // Check if a column is the current sort column
  const isColumnSorted = (columnKey) => {
    const sortField = columnSortMap[columnKey]
    if (!sortField) return false
    const current = getCurrentSort()
    return current.field === sortField
  }

  // Get sort direction indicator
  const getSortIndicator = (columnKey) => {
    if (!isColumnSorted(columnKey)) return null
    const current = getCurrentSort()
    return current.direction === 'asc' ? ' ▲' : ' ▼'
  }

  // Check if column is sortable
  const isColumnSortable = (columnKey) => {
    return columnSortMap[columnKey] !== null
  }

  // Fetch writeups
  const fetchWriteups = useCallback(async () => {
    if (!username.trim()) {
      setResults(null)
      return
    }

    setLoading(true)
    setError(null)

    try {
      const params = new URLSearchParams({
        username: username,
        orderby: orderby,
        page: page.toString(),
        per_page: '50',
        filter_hidden: filterHidden.toString()
      })

      // Use window.location.origin to bypass any <base> tag that might be set
      const response = await fetch(`${window.location.origin}/api/user_search/?${params}`, {
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to fetch writeups')
      }

      const data = await response.json()
      setResults(data)

      if (data.error === 'User not found') {
        setError(`User "${username}" not found`)
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [username, orderby, page, filterHidden])

  // Fetch on initial load if username provided
  useEffect(() => {
    if (data.initialUsername) {
      fetchWriteups()
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Refetch when sort/filter/page changes (but only if we have results)
  useEffect(() => {
    if (username && results) {
      fetchWriteups()
    }
  }, [orderby, page, filterHidden]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSearch = (e) => {
    e.preventDefault()
    const trimmedInput = searchInput.trim()
    if (trimmedInput) {
      setUsername(trimmedInput)
      setPage(1)
    }
  }

  // Effect to trigger search when username changes
  useEffect(() => {
    if (username) {
      fetchWriteups()
    }
  }, [username]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSortChange = (e) => {
    setOrderby(e.target.value)
    setPage(1)
  }

  const handleFilterChange = (newFilter) => {
    setFilterHidden(newFilter)
    setPage(1)
  }

  // Autocomplete: search for users as user types
  const searchUsers = useCallback(async (query) => {
    if (query.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      return
    }

    try {
      const response = await fetch(
        `/api/node_search?q=${encodeURIComponent(query)}&scope=users&limit=10`
      )
      const data = await response.json()
      if (data.success && data.results) {
        setSuggestions(data.results)
        setShowSuggestions(data.results.length > 0)
        setSelectedSuggestionIndex(-1)
      }
    } catch (err) {
      console.error('User search failed:', err)
      setSuggestions([])
    }
  }, [])

  // Handle input change with debounced autocomplete
  const handleInputChange = useCallback((e) => {
    const newValue = e.target.value
    setSearchInput(newValue)

    // Clear results if user is typing a different name than what was searched
    if (newValue.trim().toLowerCase() !== username.trim().toLowerCase()) {
      setResults(null)
      setError(null)
    }

    // Debounced autocomplete search
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchUsers(newValue.trim())
    }, 200)
  }, [username, searchUsers])

  // Handle selecting a suggestion
  const handleSelectSuggestion = useCallback((suggestion) => {
    setSearchInput(suggestion.title)
    setUsername(suggestion.title)
    setSuggestions([])
    setShowSuggestions(false)
    setSelectedSuggestionIndex(-1)
    setPage(1)
  }, [])

  // Handle keyboard navigation in suggestions
  const handleKeyDown = useCallback((e) => {
    if (!showSuggestions || suggestions.length === 0) return

    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setSelectedSuggestionIndex(prev =>
        prev < suggestions.length - 1 ? prev + 1 : prev
      )
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setSelectedSuggestionIndex(prev => prev > 0 ? prev - 1 : -1)
    } else if (e.key === 'Enter' && selectedSuggestionIndex >= 0) {
      e.preventDefault()
      handleSelectSuggestion(suggestions[selectedSuggestionIndex])
    } else if (e.key === 'Escape') {
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedSuggestionIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedSuggestionIndex, handleSelectSuggestion])

  // Close suggestions when clicking outside
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (inputRef.current && !inputRef.current.contains(e.target)) {
        setShowSuggestions(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Format date
  const formatDate = (dateStr) => {
    if (!dateStr) return ''
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
  }

  // Render pagination
  const renderPagination = () => {
    if (!results || results.total_pages <= 1) return null

    const pages = []
    const totalPages = results.total_pages
    const currentPage = results.page

    // Always show first page
    pages.push(1)

    // Show pages around current
    for (let i = Math.max(2, currentPage - 2); i <= Math.min(totalPages - 1, currentPage + 2); i++) {
      if (pages[pages.length - 1] !== i - 1) {
        pages.push('...')
      }
      pages.push(i)
    }

    // Always show last page
    if (totalPages > 1) {
      if (pages[pages.length - 1] !== totalPages - 1 && pages[pages.length - 1] !== '...') {
        pages.push('...')
      }
      if (pages[pages.length - 1] !== totalPages) {
        pages.push(totalPages)
      }
    }

    return (
      <div style={styles.pagination}>
        <button
          onClick={() => setPage(p => Math.max(1, p - 1))}
          disabled={currentPage === 1}
          style={styles.pageButton}
        >
          ← Previous
        </button>

        <div style={styles.pageNumbers}>
          {pages.map((p, i) => (
            p === '...' ? (
              <span key={`ellipsis-${i}`} style={styles.ellipsis}>...</span>
            ) : (
              <button
                key={p}
                onClick={() => setPage(p)}
                style={{
                  ...styles.pageNumber,
                  ...(p === currentPage ? styles.pageNumberActive : {})
                }}
              >
                {p}
              </button>
            )
          ))}
        </div>

        <button
          onClick={() => setPage(p => Math.min(totalPages, p + 1))}
          disabled={currentPage === totalPages}
          style={styles.pageButton}
        >
          Next →
        </button>
      </div>
    )
  }

  // Render vote indicator
  const renderVote = (vote) => {
    if (vote === undefined || vote === null) return null
    if (vote === 1) return <span style={styles.voteUp}>+</span>
    if (vote === -1) return <span style={styles.voteDown}>−</span>
    return null
  }

  return (
    <div className="document" style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>User Writeups</h1>
        <p style={styles.subtitle}>
          Explore the collected works of Everything2 contributors
        </p>
      </div>

      {/* Search Form */}
      <form onSubmit={handleSearch} style={styles.searchForm}>
        <div style={styles.searchRow}>
          <div style={styles.inputGroup} ref={inputRef}>
            <label htmlFor="username-input" style={styles.label}>Username</label>
            <div style={styles.autocompleteContainer}>
              <input
                id="username-input"
                type="text"
                value={searchInput}
                onChange={handleInputChange}
                onKeyDown={handleKeyDown}
                onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
                placeholder="Enter a username..."
                style={styles.input}
                autoComplete="off"
              />
              {/* Autocomplete suggestions dropdown */}
              {showSuggestions && suggestions.length > 0 && (
                <div style={styles.suggestionsDropdown}>
                  {suggestions.map((suggestion, index) => (
                    <div
                      key={suggestion.node_id}
                      onClick={() => handleSelectSuggestion(suggestion)}
                      style={{
                        ...styles.suggestionItem,
                        ...(index === selectedSuggestionIndex ? styles.suggestionItemSelected : {})
                      }}
                      onMouseEnter={() => setSelectedSuggestionIndex(index)}
                    >
                      <span style={styles.suggestionIcon}>👤</span>
                      <span>{suggestion.title}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div style={styles.inputGroup}>
            <label htmlFor="sort-select" style={styles.label}>Sort by</label>
            <select
              id="sort-select"
              value={orderby}
              onChange={handleSortChange}
              style={styles.select}
            >
              {sortOptions.map(opt => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
          </div>

          <button type="submit" style={styles.searchButton} disabled={loading}>
            {loading ? 'Searching...' : 'Search'}
          </button>
        </div>
      </form>

      {/* Error */}
      {error && (
        <div style={styles.error}>
          {error}
        </div>
      )}

      {/* Results */}
      {results && !results.error && (
        <div style={styles.results}>
          {/* Results Header */}
          <div style={styles.resultsHeader}>
            <div style={styles.resultsInfo}>
              <h2 style={styles.resultsTitle}>
                <LinkNode type="user" title={results.username} />
              </h2>
              <span style={styles.resultCount}>
                {results.total} writeup{results.total !== 1 ? 's' : ''}
                {results.total > 50 && ` (showing ${(results.page - 1) * 50 + 1}-${Math.min(results.page * 50, results.total)})`}
              </span>
            </div>

            {/* Filter options for self/editors */}
            {results.can_see_rep === 1 && (
              <div style={styles.filterButtons}>
                <span style={styles.filterLabel}>Show:</span>
                <button
                  onClick={() => handleFilterChange(0)}
                  style={{
                    ...styles.filterButton,
                    ...(filterHidden === 0 ? styles.filterButtonActive : {})
                  }}
                >
                  All
                </button>
                <button
                  onClick={() => handleFilterChange(1)}
                  style={{
                    ...styles.filterButton,
                    ...(filterHidden === 1 ? styles.filterButtonActive : {})
                  }}
                  title="Visible in New Writeups"
                >
                  Visible
                </button>
                <button
                  onClick={() => handleFilterChange(2)}
                  style={{
                    ...styles.filterButton,
                    ...(filterHidden === 2 ? styles.filterButtonActive : {})
                  }}
                  title="Hidden from New Writeups"
                >
                  Hidden
                </button>
              </div>
            )}
          </div>

          {/* Writeups Table */}
          {results.writeups.length > 0 ? (
            <>
              <div style={styles.tableContainer}>
                <table style={styles.table}>
                  <thead>
                    <tr>
                      <th
                        style={{
                          ...styles.th,
                          ...styles.sortableHeader,
                          ...(isColumnSorted('cools') ? styles.sortedColumn : {})
                        }}
                        title="Sort by cools received"
                        onClick={() => handleColumnSort('cools')}
                      >
                        Cools{getSortIndicator('cools')}
                      </th>
                      <th
                        style={{
                          ...styles.th,
                          textAlign: 'left',
                          ...styles.sortableHeader,
                          ...(isColumnSorted('title') ? styles.sortedColumn : {})
                        }}
                        title="Sort by title"
                        onClick={() => handleColumnSort('title')}
                      >
                        Title{getSortIndicator('title')}
                      </th>
                      {(results.can_see_rep === 1 || results.is_self !== 1) && (
                        <th
                          style={{
                            ...styles.th,
                            ...(results.can_see_rep === 1 ? styles.sortableHeader : {}),
                            ...(isColumnSorted('reputation') ? styles.sortedColumn : {})
                          }}
                          title={results.can_see_rep === 1 ? "Sort by reputation" : "Reputation score"}
                          onClick={results.can_see_rep === 1 ? () => handleColumnSort('reputation') : undefined}
                        >
                          Reputation{results.can_see_rep === 1 && getSortIndicator('reputation')}
                        </th>
                      )}
                      {results.is_self === 1 && (
                        <th style={styles.th} title="Vote spread (upvotes/downvotes)">Votes</th>
                      )}
                      {results.is_self !== 1 && !user?.guest && (
                        <th style={styles.th} title="Your vote on this writeup">Your Vote</th>
                      )}
                      {results.can_see_rep === 1 && (
                        <th style={styles.th} title="Hidden from public view (not sortable)">Hidden</th>
                      )}
                      {results.is_editor === 1 && (
                        <th style={styles.th} title="Has editor notes (not sortable)">Notes</th>
                      )}
                      <th
                        style={{
                          ...styles.th,
                          textAlign: 'right',
                          ...styles.sortableHeader,
                          ...(isColumnSorted('publishtime') ? styles.sortedColumn : {})
                        }}
                        title="Sort by publish date"
                        onClick={() => handleColumnSort('publishtime')}
                      >
                        Published{getSortIndicator('publishtime')}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {results.writeups.map((wu, index) => (
                      <tr key={wu.node_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                        <td style={{
                          ...styles.tdCenter,
                          ...(isColumnSorted('cools') ? styles.sortedCell : {})
                        }}>
                          {wu.cools > 0 && (
                            <span style={styles.cools}>
                              {wu.cools}C!{wu.cools > 1 ? 's' : ''}
                            </span>
                          )}
                        </td>
                        <td style={{
                          ...styles.td,
                          ...(isColumnSorted('title') ? styles.sortedCell : {})
                        }}>
                          <LinkNode
                            type="writeup"
                            title={wu.parent_title || wu.title}
                            author={results.username}
                            display={wu.parent_title || wu.title}
                          />
                          {wu.writeup_type && (
                            <span style={styles.writeupType}> ({wu.writeup_type})</span>
                          )}
                        </td>
                        {(results.can_see_rep === 1 || results.is_self !== 1) && (
                          <td style={{
                            ...styles.tdCenter,
                            ...(isColumnSorted('reputation') ? styles.sortedCell : {})
                          }}>
                            {wu.reputation !== undefined ? (
                              <span style={wu.reputation >= 0 ? styles.repPositive : styles.repNegative}>
                                {wu.reputation}
                              </span>
                            ) : (
                              <span style={styles.repHidden}>-</span>
                            )}
                          </td>
                        )}
                        {results.is_self === 1 && (
                          <td style={styles.tdCenter}>
                            {wu.upvotes !== undefined && wu.downvotes !== undefined ? (
                              <span style={styles.voteSpread}>
                                <span style={styles.voteUp}>+{wu.upvotes}</span>
                                {' / '}
                                <span style={styles.voteDown}>−{wu.downvotes}</span>
                              </span>
                            ) : (
                              <span style={styles.repHidden}>-</span>
                            )}
                          </td>
                        )}
                        {results.is_self !== 1 && !user?.guest && (
                          <td style={styles.tdCenter}>
                            {renderVote(wu.user_vote)}
                          </td>
                        )}
                        {results.can_see_rep === 1 && (
                          <td style={styles.tdCenter}>
                            {wu.hidden ? <span style={styles.hiddenIndicator}>H</span> : ''}
                          </td>
                        )}
                        {results.is_editor === 1 && (
                          <td style={styles.tdCenter}>
                            {wu.has_note ? <span style={styles.noteIndicator}>N</span> : ''}
                          </td>
                        )}
                        <td style={{
                          ...styles.tdRight,
                          ...(isColumnSorted('publishtime') ? styles.sortedCell : {})
                        }}>
                          <span style={styles.date}>{formatDate(wu.publishtime)}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {renderPagination()}
            </>
          ) : (
            <div style={styles.noResults}>
              No writeups found.
            </div>
          )}
        </div>
      )}

      {/* Empty state - shown only when no search has been performed */}
      {!results && !loading && !error && (
        <EmptyState onSelectUser={(name) => {
          setSearchInput(name)
          setUsername(name)
        }} />
      )}
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '1000px',
    margin: '0 auto',
    padding: '20px'
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px'
  },
  title: {
    fontSize: '28px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '8px'
  },
  subtitle: {
    fontSize: '16px',
    color: '#507898',
    margin: 0
  },
  searchForm: {
    background: '#f8f9f9',
    padding: '20px',
    borderRadius: '8px',
    marginBottom: '24px',
    border: '1px solid #dee2e6'
  },
  searchRow: {
    display: 'flex',
    gap: '16px',
    alignItems: 'flex-end',
    flexWrap: 'wrap'
  },
  inputGroup: {
    flex: '1',
    minWidth: '200px',
    position: 'relative'
  },
  autocompleteContainer: {
    position: 'relative'
  },
  suggestionsDropdown: {
    position: 'absolute',
    top: '100%',
    left: 0,
    right: 0,
    backgroundColor: '#fff',
    border: '1px solid #ced4da',
    borderTop: 'none',
    borderRadius: '0 0 4px 4px',
    boxShadow: '0 4px 8px rgba(0,0,0,0.1)',
    maxHeight: '250px',
    overflowY: 'auto',
    zIndex: 100
  },
  suggestionItem: {
    padding: '10px 12px',
    cursor: 'pointer',
    fontSize: '14px',
    color: '#38495e',
    borderBottom: '1px solid #eee',
    display: 'flex',
    alignItems: 'center',
    gap: '8px'
  },
  suggestionItemSelected: {
    backgroundColor: '#e8f4f8',
    color: '#4060b0'
  },
  suggestionIcon: {
    fontSize: '14px',
    width: '20px',
    textAlign: 'center',
    color: '#507898'
  },
  label: {
    display: 'block',
    fontSize: '13px',
    fontWeight: '500',
    color: '#38495e',
    marginBottom: '6px'
  },
  input: {
    width: '100%',
    padding: '10px 12px',
    fontSize: '15px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    boxSizing: 'border-box'
  },
  select: {
    width: '100%',
    padding: '10px 12px',
    fontSize: '15px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    background: 'white',
    cursor: 'pointer'
  },
  searchButton: {
    padding: '10px 24px',
    fontSize: '15px',
    fontWeight: '500',
    color: 'white',
    background: '#4060b0',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    whiteSpace: 'nowrap'
  },
  error: {
    background: '#fee',
    border: '1px solid #fcc',
    color: '#c33',
    padding: '12px 16px',
    borderRadius: '4px',
    marginBottom: '16px'
  },
  results: {
    marginTop: '24px'
  },
  resultsHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: '16px',
    marginBottom: '16px',
    paddingBottom: '16px',
    borderBottom: '2px solid #38495e'
  },
  resultsInfo: {
    display: 'flex',
    alignItems: 'baseline',
    gap: '12px',
    flexWrap: 'wrap'
  },
  resultsTitle: {
    fontSize: '20px',
    fontWeight: '600',
    color: '#38495e',
    margin: 0
  },
  resultCount: {
    fontSize: '14px',
    color: '#507898'
  },
  filterButtons: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px'
  },
  filterLabel: {
    fontSize: '13px',
    color: '#507898'
  },
  filterButton: {
    padding: '6px 12px',
    fontSize: '13px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    background: 'white',
    cursor: 'pointer',
    color: '#38495e'
  },
  filterButtonActive: {
    background: '#38495e',
    color: 'white',
    borderColor: '#38495e'
  },
  tableContainer: {
    overflowX: 'auto'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '14px'
  },
  th: {
    padding: '10px 8px',
    textAlign: 'center',
    fontWeight: '600',
    color: '#38495e',
    borderBottom: '1px solid #dee2e6',
    whiteSpace: 'nowrap'
  },
  sortableHeader: {
    cursor: 'pointer',
    userSelect: 'none',
    transition: 'background-color 0.15s ease'
  },
  sortedColumn: {
    backgroundColor: '#e8f4f8',
    color: '#38495e'
  },
  sortedCell: {
    backgroundColor: 'rgba(59, 181, 195, 0.08)'
  },
  td: {
    padding: '10px 8px',
    borderBottom: '1px solid #eee'
  },
  tdCenter: {
    padding: '10px 8px',
    textAlign: 'center',
    borderBottom: '1px solid #eee'
  },
  tdRight: {
    padding: '10px 8px',
    textAlign: 'right',
    borderBottom: '1px solid #eee'
  },
  evenRow: {
    background: '#fff'
  },
  oddRow: {
    background: '#f8f9fa'
  },
  cools: {
    color: '#3bb5c3',
    fontWeight: '600',
    fontSize: '12px'
  },
  writeupType: {
    color: '#507898',
    fontSize: '13px'
  },
  repPositive: {
    color: '#28a745'
  },
  repNegative: {
    color: '#dc3545'
  },
  repHidden: {
    color: '#999'
  },
  voteUp: {
    color: '#28a745',
    fontWeight: 'bold'
  },
  voteDown: {
    color: '#dc3545',
    fontWeight: 'bold'
  },
  voteSpread: {
    fontSize: '13px',
    whiteSpace: 'nowrap'
  },
  hiddenIndicator: {
    color: '#ffc107',
    fontWeight: '600'
  },
  noteIndicator: {
    color: '#17a2b8',
    fontWeight: '600'
  },
  date: {
    color: '#6c757d',
    fontSize: '13px',
    whiteSpace: 'nowrap'
  },
  pagination: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '16px',
    marginTop: '24px',
    padding: '16px 0'
  },
  pageButton: {
    padding: '8px 16px',
    fontSize: '14px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    background: 'white',
    cursor: 'pointer',
    color: '#38495e'
  },
  pageNumbers: {
    display: 'flex',
    gap: '4px',
    alignItems: 'center'
  },
  pageNumber: {
    padding: '8px 12px',
    fontSize: '14px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    background: 'white',
    cursor: 'pointer',
    color: '#38495e',
    minWidth: '40px'
  },
  pageNumberActive: {
    background: '#38495e',
    color: 'white',
    borderColor: '#38495e'
  },
  ellipsis: {
    padding: '8px 4px',
    color: '#6c757d'
  },
  noResults: {
    textAlign: 'center',
    padding: '40px 20px',
    color: '#6c757d',
    fontSize: '16px'
  },
  emptyState: {
    textAlign: 'center',
    padding: '60px 20px',
    background: '#f8f9f9',
    borderRadius: '8px',
    color: '#507898'
  },
  hint: {
    fontSize: '14px',
    marginTop: '12px'
  },
  suggestionLink: {
    background: 'none',
    border: 'none',
    color: '#4060b0',
    cursor: 'pointer',
    textDecoration: 'underline',
    padding: 0,
    font: 'inherit'
  }
}

export default UserSearch

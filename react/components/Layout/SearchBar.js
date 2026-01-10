import React, { useState, useCallback, useEffect, useRef } from 'react'
import { FaSearch } from 'react-icons/fa'

/**
 * SearchBar - Site search component with live autocomplete
 *
 * Provides the main search input for navigating to e2nodes and other content.
 * Features live search suggestions as the user types.
 * "Show all results" option at bottom of dropdown for full search.
 *
 * Props:
 * - initialValue: Initial value for search input (e.g., current node title)
 * - lastNodeId: The lastnode_id to include in search (for softlink tracking)
 * - compact: Use compact styling (default: false)
 */
const SearchBar = ({
  initialValue = '',
  lastNodeId = 0,
  compact = false
}) => {
  const [searchValue, setSearchValue] = useState(initialValue)
  const [suggestions, setSuggestions] = useState([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)
  const [loading, setLoading] = useState(false)

  const searchTimeoutRef = useRef(null)
  const containerRef = useRef(null)

  // Total items includes suggestions + "show all" option
  const totalItems = suggestions.length + (suggestions.length > 0 ? 1 : 0)

  // Set lastnode_id cookie for softlink tracking before navigating
  const setLastNodeCookie = useCallback(() => {
    if (lastNodeId && lastNodeId > 0) {
      document.cookie = `lastnode_id=${lastNodeId}; path=/; SameSite=Lax; max-age=3600`
    }
  }, [lastNodeId])

  // Search for nodes via API
  const searchNodes = useCallback(async (query) => {
    if (query.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      return
    }

    setLoading(true)
    try {
      const response = await fetch(
        `/api/node_search?q=${encodeURIComponent(query)}&scope=all&limit=8`
      )
      const data = await response.json()
      if (data.success && data.results) {
        setSuggestions(data.results)
        setShowSuggestions(data.results.length > 0)
        setSelectedIndex(-1)
      }
    } catch (err) {
      console.error('Search failed:', err)
      setSuggestions([])
    } finally {
      setLoading(false)
    }
  }, [])

  const handleInputChange = useCallback((e) => {
    const newValue = e.target.value
    setSearchValue(newValue)

    // Debounced live search
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchNodes(newValue.trim())
    }, 200)
  }, [searchNodes])

  // Navigate to a selected suggestion
  const handleSelectSuggestion = useCallback((suggestion) => {
    // Set softlink cookie before navigating
    setLastNodeCookie()
    // Navigate to the node
    const url = suggestion.type === 'user'
      ? `/user/${encodeURIComponent(suggestion.title)}`
      : `/title/${encodeURIComponent(suggestion.title)}`
    window.location.href = url
  }, [setLastNodeCookie])

  // Navigate to full search results
  const handleShowAll = useCallback(() => {
    setLastNodeCookie()
    window.location.href = `/?node=${encodeURIComponent(searchValue)}&match_all=1`
  }, [searchValue, setLastNodeCookie])

  // Handle form submission (set cookie before submitting)
  const handleSubmit = useCallback((e) => {
    setLastNodeCookie()
    // Let form submit naturally
  }, [setLastNodeCookie])

  // Handle keyboard navigation
  const handleKeyDown = useCallback((e) => {
    if (!showSuggestions || suggestions.length === 0) {
      return // Let form submit naturally
    }

    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setSelectedIndex(prev =>
        prev < totalItems - 1 ? prev + 1 : prev
      )
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setSelectedIndex(prev => prev > 0 ? prev - 1 : -1)
    } else if (e.key === 'Enter' && selectedIndex >= 0) {
      e.preventDefault()
      if (selectedIndex < suggestions.length) {
        handleSelectSuggestion(suggestions[selectedIndex])
      } else {
        handleShowAll()
      }
    } else if (e.key === 'Escape') {
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedIndex, totalItems, handleSelectSuggestion, handleShowAll])

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

  // Get icon for node type
  const getTypeIcon = (type) => {
    switch (type) {
      case 'user': return '👤'
      case 'e2node': return '📄'
      case 'writeup': return '✍️'
      case 'superdoc': return '📋'
      case 'superdocnolinks': return '📋'
      case 'usergroup': return '👥'
      case 'document': return '📝'
      case 'debate': return '💬'
      case 'podcast': return '🎙️'
      case 'fullpage': return '📰'
      case 'draft': return '📝'
      default: return '📄'
    }
  }

  // Get user-friendly display name for node type
  const getTypeDisplayName = (type) => {
    switch (type) {
      case 'user': return 'user'
      case 'usergroup': return 'group'
      case 'superdoc': return 'page'
      case 'superdocnolinks': return 'page'
      case 'oppressor_superdoc': return 'page'
      case 'fullpage': return 'page'
      case 'document': return 'page'
      case 'debate': return 'debate'
      case 'podcast': return 'podcast'
      case 'draft': return 'draft'
      default: return type
    }
  }

  return (
    <div ref={containerRef} style={styles.container}>
      <form
        method="GET"
        action="/"
        id="search_form"
        role="search"
        style={compact ? styles.formCompact : styles.form}
        onSubmit={handleSubmit}
      >
        <div style={styles.inputWrapper}>
          <FaSearch style={styles.searchIcon} aria-hidden="true" />
          <input
            type="text"
            name="node"
            value={searchValue}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
            placeholder="Search"
            maxLength={230}
            style={compact ? styles.inputCompact : styles.input}
            id="node_search"
            aria-label="Search Everything2"
            autoComplete="off"
          />
          {loading && <span style={styles.loadingIndicator}>...</span>}

          {/* Live search suggestions dropdown */}
          {showSuggestions && suggestions.length > 0 && (
            <div style={styles.dropdown}>
              {suggestions.map((item, index) => (
                <div
                  key={`${item.type}-${item.node_id}`}
                  onClick={() => handleSelectSuggestion(item)}
                  onMouseEnter={() => setSelectedIndex(index)}
                  style={{
                    ...styles.suggestionItem,
                    ...(index === selectedIndex ? styles.suggestionItemSelected : {})
                  }}
                >
                  <span style={styles.typeIcon}>{getTypeIcon(item.type)}</span>
                  <span style={styles.suggestionTitle}>{item.title}</span>
                  {/* Don't show type for e2node since it's the default content type */}
                  {item.type !== 'e2node' && (
                    <span style={styles.suggestionType}>{getTypeDisplayName(item.type)}</span>
                  )}
                </div>
              ))}
              {/* Show all results option */}
              <div
                onClick={handleShowAll}
                onMouseEnter={() => setSelectedIndex(suggestions.length)}
                style={{
                  ...styles.showAllItem,
                  ...(selectedIndex === suggestions.length ? styles.suggestionItemSelected : {})
                }}
              >
                <FaSearch style={styles.showAllIcon} />
                <span>Show all results for "<strong>{searchValue}</strong>"</span>
              </div>
            </div>
          )}
        </div>
        <input type="hidden" name="lastnode_id" value={lastNodeId} />
      </form>
    </div>
  )
}

const styles = {
  container: {
    position: 'relative'
  },
  form: {
    display: 'flex',
    flexDirection: 'column'
  },
  formCompact: {
    display: 'flex',
    flexDirection: 'row',
    alignItems: 'center'
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
    flex: 1
  },
  searchIcon: {
    position: 'absolute',
    left: 12,
    color: '#507898',
    fontSize: 14,
    pointerEvents: 'none',
    zIndex: 1
  },
  input: {
    width: '100%',
    padding: '8px 14px 8px 36px',
    fontSize: 14,
    border: '1px solid #507898',
    borderRadius: 18,
    color: '#38495e',
    backgroundColor: '#fff',
    boxSizing: 'border-box',
    outline: 'none'
  },
  inputCompact: {
    width: 200,
    padding: '6px 10px 6px 30px',
    fontSize: 13,
    border: '1px solid #507898',
    borderRadius: 14,
    color: '#38495e',
    backgroundColor: '#fff',
    boxSizing: 'border-box',
    outline: 'none'
  },
  loadingIndicator: {
    position: 'absolute',
    right: 12,
    color: '#507898',
    fontSize: 12
  },
  dropdown: {
    position: 'absolute',
    top: 'calc(100% + 4px)',
    left: 0,
    right: 0,
    minWidth: 320,
    backgroundColor: '#fff',
    border: '1px solid #ced4da',
    borderRadius: 12,
    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
    maxHeight: 400,
    overflowY: 'auto',
    zIndex: 1000
  },
  suggestionItem: {
    padding: '10px 14px',
    cursor: 'pointer',
    fontSize: 14,
    color: '#38495e',
    borderBottom: '1px solid #f0f0f0',
    display: 'flex',
    alignItems: 'center',
    gap: 10
  },
  suggestionItemSelected: {
    backgroundColor: '#e8f4f8',
    color: '#4060b0'
  },
  typeIcon: {
    fontSize: 16,
    width: 24,
    textAlign: 'center',
    flexShrink: 0
  },
  suggestionTitle: {
    flex: 1,
    wordBreak: 'break-word'
  },
  suggestionType: {
    fontSize: 11,
    color: '#999',
    textTransform: 'uppercase',
    flexShrink: 0
  },
  showAllItem: {
    padding: '12px 14px',
    cursor: 'pointer',
    fontSize: 14,
    color: '#4060b0',
    backgroundColor: '#f8f9fa',
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    borderTop: '1px solid #e0e0e0'
  },
  showAllIcon: {
    fontSize: 14,
    color: '#4060b0'
  }
}

export default SearchBar

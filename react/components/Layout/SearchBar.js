import React, { useState, useCallback, useEffect, useRef } from 'react'
import { FaSearch } from 'react-icons/fa'
import { useAutocompleteSearch } from '../../hooks/useAutocompleteSearch'
import { useClickOutside } from '../../hooks/useClickOutside'

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
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)

  const containerRef = useRef(null)

  // Debounce / abort / stale-guard live in useAutocompleteSearch.
  const searchNodes = useCallback(async (query, { signal }) => {
    const response = await fetch(
      `/api/node_search?q=${encodeURIComponent(query)}&scope=all&limit=10`,
      { signal }
    )
    const data = await response.json()
    return data.success && data.results ? data.results : []
  }, [])
  const {
    results: suggestions,
    loading,
    triggerSearch,
    clearResults,
  } = useAutocompleteSearch({ search: searchNodes })

  // Open dropdown when fresh results arrive.
  useEffect(() => {
    if (suggestions.length > 0) {
      setShowSuggestions(true)
      setSelectedIndex(-1)
    }
  }, [suggestions])

  // Total items includes suggestions + "show all" option
  const totalItems = suggestions.length + (suggestions.length > 0 ? 1 : 0)

  // Set lastnode_id cookie for softlink tracking before navigating
  const setLastNodeCookie = useCallback(() => {
    if (lastNodeId && lastNodeId > 0) {
      document.cookie = `lastnode_id=${lastNodeId}; path=/; SameSite=Lax; max-age=3600`
    }
  }, [lastNodeId])

  const handleInputChange = useCallback((e) => {
    const newValue = e.target.value
    setSearchValue(newValue)
    const trimmed = newValue.trim()
    if (trimmed.length < 2) setShowSuggestions(false)
    triggerSearch(trimmed)
  }, [triggerSearch])

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
      clearResults()
      setShowSuggestions(false)
      setSelectedIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedIndex, totalItems, handleSelectSuggestion, handleShowAll, clearResults])

  useClickOutside(containerRef, () => setShowSuggestions(false))

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

  const formClass = compact ? 'search-bar-form search-bar-form--compact' : 'search-bar-form'
  const inputClass = compact ? 'search-bar-input search-bar-input--compact' : 'search-bar-input'

  return (
    <div ref={containerRef} className="search-bar-container">
      <form
        method="GET"
        action="/"
        id="search_form"
        role="search"
        className={formClass}
        onSubmit={handleSubmit}
      >
        <div className="search-bar-input-wrapper">
          <FaSearch className="search-bar-icon" aria-hidden="true" />
          <input
            type="text"
            name="node"
            value={searchValue}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
            placeholder="Search"
            maxLength={230}
            className={inputClass}
            id="node_search"
            aria-label="Search Everything2"
            autoComplete="off"
          />
          {loading && <span className="search-bar-loading">...</span>}

          {/* Live search suggestions dropdown */}
          {showSuggestions && suggestions.length > 0 && (
            <div className="search-bar-dropdown">
              {suggestions.map((item, index) => (
                <div
                  key={`${item.type}-${item.node_id}`}
                  onClick={() => handleSelectSuggestion(item)}
                  onMouseEnter={() => setSelectedIndex(index)}
                  className={`search-bar-suggestion${index === selectedIndex ? ' search-bar-suggestion--selected' : ''}`}
                >
                  <span className="search-bar-suggestion-icon">{getTypeIcon(item.type)}</span>
                  <span className="search-bar-suggestion-title">{item.title}</span>
                  {/* Don't show type for e2node since it's the default content type */}
                  {item.type !== 'e2node' && (
                    <span className="search-bar-suggestion-type">{getTypeDisplayName(item.type)}</span>
                  )}
                </div>
              ))}
              {/* Show all results option */}
              <div
                onClick={handleShowAll}
                onMouseEnter={() => setSelectedIndex(suggestions.length)}
                className={`search-bar-show-all${selectedIndex === suggestions.length ? ' search-bar-show-all--selected' : ''}`}
              >
                <FaSearch className="search-bar-show-all-icon" />
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

export default SearchBar

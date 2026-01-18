import React, { useState, useEffect, useCallback, useRef } from 'react'
import PropTypes from 'prop-types'

/**
 * UserSearchInput - Live search input for finding E2 users
 *
 * Features:
 * - Debounced autocomplete as user types
 * - Keyboard navigation (up/down arrows, enter, escape)
 * - Click outside to close dropdown
 * - Customizable placeholder and button text
 */
const UserSearchInput = ({
  onSelect,
  placeholder = 'Search for a user...',
  buttonText = 'Add',
  disabled = false,
  clearOnSelect = true
}) => {
  const [inputValue, setInputValue] = useState('')
  const [suggestions, setSuggestions] = useState([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)
  const [loading, setLoading] = useState(false)

  const searchTimeoutRef = useRef(null)
  const containerRef = useRef(null)

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

    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchUsers(newValue.trim())
    }, 200)
  }, [searchUsers])

  // Handle selecting a user from suggestions
  const handleSelectUser = useCallback((user) => {
    if (onSelect) {
      onSelect(user)
    }
    if (clearOnSelect) {
      setInputValue('')
    } else {
      setInputValue(user.title)
    }
    setSuggestions([])
    setShowSuggestions(false)
    setSelectedIndex(-1)
  }, [onSelect, clearOnSelect])

  // Handle form submission (when clicking button or pressing enter without selection)
  const handleSubmit = useCallback((e) => {
    if (e) e.preventDefault()

    // If a suggestion is selected, use that
    if (selectedIndex >= 0 && suggestions[selectedIndex]) {
      handleSelectUser(suggestions[selectedIndex])
      return
    }

    // Otherwise, if we have text, try to use it as a username
    const trimmedValue = inputValue.trim()
    if (trimmedValue && onSelect) {
      // Pass a user object with just the title
      onSelect({ title: trimmedValue, node_id: null })
      if (clearOnSelect) {
        setInputValue('')
      }
      setSuggestions([])
      setShowSuggestions(false)
    }
  }, [inputValue, selectedIndex, suggestions, handleSelectUser, onSelect, clearOnSelect])

  // Handle keyboard navigation
  const handleKeyDown = useCallback((e) => {
    if (!showSuggestions || suggestions.length === 0) {
      if (e.key === 'Enter') {
        e.preventDefault()
        handleSubmit()
      }
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
    } else if (e.key === 'Enter') {
      e.preventDefault()
      if (selectedIndex >= 0) {
        handleSelectUser(suggestions[selectedIndex])
      } else {
        handleSubmit()
      }
    } else if (e.key === 'Escape') {
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedIndex, handleSelectUser, handleSubmit])

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

  const btnClass = disabled || !inputValue.trim()
    ? 'user-search__btn user-search__btn--disabled'
    : 'user-search__btn'

  return (
    <div ref={containerRef} className="user-search">
      <div className="user-search__row">
        <div className="user-search__input-wrapper">
          <input
            type="text"
            value={inputValue}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
            placeholder={placeholder}
            disabled={disabled}
            className="user-search__input"
            autoComplete="off"
          />
          {loading && <span className="user-search__loading">...</span>}

          {/* Suggestions dropdown */}
          {showSuggestions && suggestions.length > 0 && (
            <div className="user-search__dropdown">
              {suggestions.map((user, index) => (
                <div
                  key={user.node_id}
                  onClick={() => handleSelectUser(user)}
                  onMouseEnter={() => setSelectedIndex(index)}
                  className={`user-search__suggestion${index === selectedIndex ? ' user-search__suggestion--selected' : ''}`}
                >
                  <span className="user-search__user-icon">👤</span>
                  <span className="user-search__user-name">{user.title}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <button
          type="button"
          onClick={handleSubmit}
          disabled={disabled || !inputValue.trim()}
          className={btnClass}
        >
          {buttonText}
        </button>
      </div>
    </div>
  )
}

UserSearchInput.propTypes = {
  onSelect: PropTypes.func.isRequired,
  placeholder: PropTypes.string,
  buttonText: PropTypes.string,
  disabled: PropTypes.bool,
  clearOnSelect: PropTypes.bool
}

export default UserSearchInput

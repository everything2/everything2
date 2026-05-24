import React, { useState, useEffect, useCallback, useRef } from 'react'
import PropTypes from 'prop-types'
import { useAutocompleteSearch } from '../hooks/useAutocompleteSearch'
import { useClickOutside } from '../hooks/useClickOutside'

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
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(-1)

  const containerRef = useRef(null)

  // Debounce / abort / stale-guard live in useAutocompleteSearch.
  const searchUsers = useCallback(async (query, { signal }) => {
    const response = await fetch(
      `/api/node_search?q=${encodeURIComponent(query)}&scope=users&limit=10`,
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
  } = useAutocompleteSearch({ search: searchUsers })

  useEffect(() => {
    if (suggestions.length > 0) {
      setShowSuggestions(true)
      setSelectedIndex(-1)
    }
  }, [suggestions])

  // Handle input change with debounced search
  const handleInputChange = useCallback((e) => {
    const newValue = e.target.value
    setInputValue(newValue)
    const trimmed = newValue.trim()
    if (trimmed.length < 2) setShowSuggestions(false)
    triggerSearch(trimmed)
  }, [triggerSearch])

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
    clearResults()
    setShowSuggestions(false)
    setSelectedIndex(-1)
  }, [onSelect, clearOnSelect, clearResults])

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
      clearResults()
      setShowSuggestions(false)
    }
  }, [inputValue, selectedIndex, suggestions, handleSelectUser, onSelect, clearOnSelect, clearResults])

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
      clearResults()
      setShowSuggestions(false)
      setSelectedIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedIndex, handleSelectUser, handleSubmit, clearResults])

  useClickOutside(containerRef, () => setShowSuggestions(false))

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

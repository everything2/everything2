import React, { useState, useEffect, useCallback, useRef } from 'react'
import LinkNode from '../LinkNode'
import { FaMicrophone, FaSave, FaSpinner, FaPodcast, FaUser, FaTimes, FaFileAlt } from 'react-icons/fa'

/**
 * UserSearchField - Inline user search input with dropdown suggestions
 * Styles in CSS: .user-search-field__*
 */
const UserSearchField = ({ value, onChange, placeholder, disabled }) => {
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
  }, [onChange])

  // Handle keyboard navigation
  const handleKeyDown = useCallback((e) => {
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
    } else if (e.key === 'Enter') {
      e.preventDefault()
      if (selectedIndex >= 0) {
        handleSelectUser(suggestions[selectedIndex])
      }
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
    <div ref={containerRef} className="user-search-field">
      <div className="user-search-field__wrapper">
        <FaUser className="user-search-field__icon" />
        <input
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          placeholder={placeholder}
          disabled={disabled}
          className="user-search-field__input"
          autoComplete="off"
        />
        {loading && <span className="user-search-field__loading">...</span>}
        {inputValue && !loading && (
          <button
            type="button"
            onClick={handleClear}
            className="user-search-field__clear"
            title="Clear"
          >
            <FaTimes />
          </button>
        )}

        {/* Suggestions dropdown */}
        {showSuggestions && suggestions.length > 0 && (
          <div className="user-search-field__dropdown">
            {suggestions.map((user, index) => (
              <div
                key={user.node_id}
                onClick={() => handleSelectUser(user)}
                onMouseEnter={() => setSelectedIndex(index)}
                className={`user-search-field__option ${index === selectedIndex ? 'user-search-field__option--highlighted' : ''}`}
              >
                <FaUser className="user-search-field__option-icon" />
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
 * E2nodeSearchField - Inline e2node search input with dropdown suggestions
 * When author prop is provided, only shows e2nodes where that author has a writeup
 * Styles in CSS: .e2node-search-field__*
 */
const E2nodeSearchField = ({ value, onChange, placeholder, disabled, author }) => {
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

  // Search for e2nodes via API
  const searchE2nodes = useCallback(async (query) => {
    if (query.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      return
    }

    setLoading(true)
    try {
      // Build URL with optional author filter
      let url = `/api/node_search?q=${encodeURIComponent(query)}&scope=e2nodes&limit=10`
      if (author) {
        url += `&author=${encodeURIComponent(author)}`
      }
      const response = await fetch(url)
      const data = await response.json()
      if (data.success && data.results) {
        setSuggestions(data.results)
        setShowSuggestions(data.results.length > 0)
        setSelectedIndex(-1)
      }
    } catch (err) {
      console.error('E2node search failed:', err)
      setSuggestions([])
    } finally {
      setLoading(false)
    }
  }, [author])

  // Handle input change with debounced search
  const handleInputChange = useCallback((e) => {
    const newValue = e.target.value
    setInputValue(newValue)
    onChange(newValue)

    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchE2nodes(newValue.trim())
    }, 200)
  }, [searchE2nodes, onChange])

  // Handle selecting an e2node from suggestions
  const handleSelectE2node = useCallback((node) => {
    setInputValue(node.title)
    onChange(node.title)
    setSuggestions([])
    setShowSuggestions(false)
    setSelectedIndex(-1)
  }, [onChange])

  // Handle keyboard navigation
  const handleKeyDown = useCallback((e) => {
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
    } else if (e.key === 'Enter') {
      e.preventDefault()
      if (selectedIndex >= 0) {
        handleSelectE2node(suggestions[selectedIndex])
      }
    } else if (e.key === 'Escape') {
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedIndex, handleSelectE2node])

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
    <div ref={containerRef} className="e2node-search-field">
      <div className="e2node-search-field__wrapper">
        <FaFileAlt className="e2node-search-field__icon" />
        <input
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          placeholder={placeholder}
          disabled={disabled}
          className="e2node-search-field__input"
          autoComplete="off"
        />
        {loading && <span className="e2node-search-field__loading">...</span>}
        {inputValue && !loading && (
          <button
            type="button"
            onClick={handleClear}
            className="e2node-search-field__clear"
            title="Clear"
          >
            <FaTimes />
          </button>
        )}

        {/* Suggestions dropdown */}
        {showSuggestions && suggestions.length > 0 && (
          <div className="e2node-search-field__dropdown">
            {suggestions.map((node, index) => (
              <div
                key={node.node_id}
                onClick={() => handleSelectE2node(node)}
                onMouseEnter={() => setSelectedIndex(index)}
                className={`e2node-search-field__option ${index === selectedIndex ? 'e2node-search-field__option--highlighted' : ''}`}
              >
                <FaFileAlt className="e2node-search-field__option-icon" />
                <span>{node.title}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

/**
 * RecordingEdit - Edit recording information
 * Styles in CSS: .recording-edit__*
 *
 * Allows editing recording metadata:
 * - Title
 * - Audio link (URL)
 * - Reader name (user who read it) - with live search
 * - Writeup author + title (to find the writeup) - with live search
 */
const RecordingEdit = ({ data }) => {
  const { recording } = data

  const [formData, setFormData] = useState({
    title: recording.title || '',
    link: recording.link || '',
    read_by_name: recording.read_by?.title || '',
    writeup_author: recording.recording_of?.author?.title || '',
    writeup_title: recording.recording_of?.title?.replace(/ \([^)]+\)$/, '') || ''  // Remove writeup type suffix
  })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    setMessage(null)
  }

  const handleSave = async () => {
    setSaving(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/recordings/${recording.node_id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(formData)
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: 'Recording saved successfully!' })
        // Update local state if read_by or recording_of changed
        if (result.read_by !== undefined) {
          setFormData(prev => ({ ...prev, read_by_name: result.read_by?.title || '' }))
        }
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to save' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="recording-edit">
      {/* Header */}
      <div className="recording-edit__header">
        <FaMicrophone className="recording-edit__header-icon" />
        <span className="recording-edit__header-title">Edit Recording</span>
        <a href={`/node/${recording.node_id}`} className="recording-edit__back-link">
          display
        </a>
      </div>

      {/* Message */}
      {message && (
        <div className={message.type === 'error' ? 'recording-edit__error' : 'recording-edit__success'}>
          {message.text}
        </div>
      )}

      {/* Appears in podcast */}
      {recording.appears_in && (
        <div className="recording-edit__podcast-info">
          <FaPodcast className="recording-edit__podcast-icon" />
          Appears in: <LinkNode nodeId={recording.appears_in.node_id} title={recording.appears_in.title} />
        </div>
      )}

      {/* Form */}
      <div className="recording-edit__form">
        <div className="recording-edit__field">
          <label className="recording-edit__label">Title:</label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => handleChange('title', e.target.value)}
            className="recording-edit__input"
            maxLength={64}
          />
        </div>

        <div className="recording-edit__field">
          <label className="recording-edit__label">Audio Link (URL):</label>
          <input
            type="text"
            value={formData.link}
            onChange={(e) => handleChange('link', e.target.value)}
            className="recording-edit__input"
            placeholder="https://..."
          />
          <div className="recording-edit__hint">
            Direct link to the audio file (MP3, etc.)
          </div>
        </div>

        <div className="recording-edit__field">
          <label className="recording-edit__label">Read by:</label>
          <UserSearchField
            value={formData.read_by_name}
            onChange={(value) => handleChange('read_by_name', value)}
            placeholder="Search for user..."
          />
          <div className="recording-edit__hint">
            The user who read/recorded the audio
          </div>
        </div>

        <div className="recording-edit__section-divider">
          <span>Link to Writeup (Optional)</span>
        </div>

        <div className="recording-edit__field">
          <label className="recording-edit__label">Writeup Author:</label>
          <UserSearchField
            value={formData.writeup_author}
            onChange={(value) => handleChange('writeup_author', value)}
            placeholder="Search for author..."
          />
        </div>

        <div className="recording-edit__field">
          <label className="recording-edit__label">Writeup Title (e2node name):</label>
          <E2nodeSearchField
            value={formData.writeup_title}
            onChange={(value) => handleChange('writeup_title', value)}
            placeholder={formData.writeup_author ? "Search e2nodes with writeups by this author..." : "Select author first, then search..."}
            author={formData.writeup_author}
            disabled={!formData.writeup_author}
          />
          <div className="recording-edit__hint">
            {formData.writeup_author
              ? `Showing e2nodes where ${formData.writeup_author} has a writeup`
              : 'Select an author above to search for their writeups'}
          </div>
        </div>

        <div className="recording-edit__button-row">
          <button
            onClick={handleSave}
            disabled={saving}
            className="recording-edit__submit-button"
          >
            {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
            <span className="recording-edit__button-text">{saving ? 'Saving...' : 'Save Changes'}</span>
          </button>
        </div>
      </div>
    </div>
  )
}

export default RecordingEdit

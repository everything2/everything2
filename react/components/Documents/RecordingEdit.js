import React, { useState, useEffect, useCallback, useRef } from 'react'
import LinkNode from '../LinkNode'
import { FaMicrophone, FaSave, FaSpinner, FaPodcast, FaUser, FaTimes, FaFileAlt } from 'react-icons/fa'

/**
 * UserSearchField - Inline user search input with dropdown suggestions
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
    <div ref={containerRef} style={userSearchStyles.container}>
      <div style={userSearchStyles.inputWrapper}>
        <FaUser style={userSearchStyles.icon} />
        <input
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          placeholder={placeholder}
          disabled={disabled}
          style={userSearchStyles.input}
          autoComplete="off"
        />
        {loading && <span style={userSearchStyles.loadingIndicator}>...</span>}
        {inputValue && !loading && (
          <button
            type="button"
            onClick={handleClear}
            style={userSearchStyles.clearButton}
            title="Clear"
          >
            <FaTimes />
          </button>
        )}

        {/* Suggestions dropdown */}
        {showSuggestions && suggestions.length > 0 && (
          <div style={userSearchStyles.dropdown}>
            {suggestions.map((user, index) => (
              <div
                key={user.node_id}
                onClick={() => handleSelectUser(user)}
                onMouseEnter={() => setSelectedIndex(index)}
                style={{
                  ...userSearchStyles.suggestionItem,
                  ...(index === selectedIndex ? userSearchStyles.suggestionItemSelected : {})
                }}
              >
                <FaUser style={userSearchStyles.suggestionIcon} />
                <span>{user.title}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

const userSearchStyles = {
  container: {
    position: 'relative'
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center'
  },
  icon: {
    position: 'absolute',
    left: 10,
    color: '#507898',
    fontSize: 14,
    pointerEvents: 'none'
  },
  input: {
    width: '100%',
    padding: '8px 32px 8px 32px',
    fontSize: 14,
    border: '1px solid #507898',
    borderRadius: 4,
    boxSizing: 'border-box'
  },
  loadingIndicator: {
    position: 'absolute',
    right: 32,
    color: '#507898',
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
    border: '1px solid #507898',
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
    color: '#38495e',
    borderBottom: '1px solid #eee',
    display: 'flex',
    alignItems: 'center',
    gap: 8
  },
  suggestionItemSelected: {
    backgroundColor: '#e8f4f8',
    color: '#4060b0'
  },
  suggestionIcon: {
    fontSize: 12,
    color: '#507898'
  }
}

/**
 * E2nodeSearchField - Inline e2node search input with dropdown suggestions
 * When author prop is provided, only shows e2nodes where that author has a writeup
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
    <div ref={containerRef} style={e2nodeSearchStyles.container}>
      <div style={e2nodeSearchStyles.inputWrapper}>
        <FaFileAlt style={e2nodeSearchStyles.icon} />
        <input
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          placeholder={placeholder}
          disabled={disabled}
          style={e2nodeSearchStyles.input}
          autoComplete="off"
        />
        {loading && <span style={e2nodeSearchStyles.loadingIndicator}>...</span>}
        {inputValue && !loading && (
          <button
            type="button"
            onClick={handleClear}
            style={e2nodeSearchStyles.clearButton}
            title="Clear"
          >
            <FaTimes />
          </button>
        )}

        {/* Suggestions dropdown */}
        {showSuggestions && suggestions.length > 0 && (
          <div style={e2nodeSearchStyles.dropdown}>
            {suggestions.map((node, index) => (
              <div
                key={node.node_id}
                onClick={() => handleSelectE2node(node)}
                onMouseEnter={() => setSelectedIndex(index)}
                style={{
                  ...e2nodeSearchStyles.suggestionItem,
                  ...(index === selectedIndex ? e2nodeSearchStyles.suggestionItemSelected : {})
                }}
              >
                <FaFileAlt style={e2nodeSearchStyles.suggestionIcon} />
                <span>{node.title}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

const e2nodeSearchStyles = {
  container: {
    position: 'relative'
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center'
  },
  icon: {
    position: 'absolute',
    left: 10,
    color: '#507898',
    fontSize: 14,
    pointerEvents: 'none'
  },
  input: {
    width: '100%',
    padding: '8px 32px 8px 32px',
    fontSize: 14,
    border: '1px solid #507898',
    borderRadius: 4,
    boxSizing: 'border-box'
  },
  loadingIndicator: {
    position: 'absolute',
    right: 32,
    color: '#507898',
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
    border: '1px solid #507898',
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
    color: '#38495e',
    borderBottom: '1px solid #eee',
    display: 'flex',
    alignItems: 'center',
    gap: 8
  },
  suggestionItemSelected: {
    backgroundColor: '#e8f4f8',
    color: '#4060b0'
  },
  suggestionIcon: {
    fontSize: 12,
    color: '#507898'
  }
}

/**
 * RecordingEdit - Edit recording information
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
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaMicrophone style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.headerTitle}>Edit Recording</span>
        <a href={`/node/${recording.node_id}`} style={styles.displayLink}>
          display
        </a>
      </div>

      {/* Message */}
      {message && (
        <div style={{
          ...styles.message,
          backgroundColor: message.type === 'error' ? '#fee' : '#efe',
          borderColor: message.type === 'error' ? '#fcc' : '#cec',
          color: message.type === 'error' ? '#c00' : '#060'
        }}>
          {message.text}
        </div>
      )}

      {/* Appears in podcast */}
      {recording.appears_in && (
        <div style={styles.podcastInfo}>
          <FaPodcast style={{ marginRight: 6, color: '#507898' }} />
          Appears in: <LinkNode nodeId={recording.appears_in.node_id} title={recording.appears_in.title} />
        </div>
      )}

      {/* Form */}
      <div style={styles.form}>
        <div style={styles.field}>
          <label style={styles.label}>Title:</label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => handleChange('title', e.target.value)}
            style={styles.input}
            maxLength={64}
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Audio Link (URL):</label>
          <input
            type="text"
            value={formData.link}
            onChange={(e) => handleChange('link', e.target.value)}
            style={styles.input}
            placeholder="https://..."
          />
          <div style={styles.hint}>
            Direct link to the audio file (MP3, etc.)
          </div>
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Read by:</label>
          <UserSearchField
            value={formData.read_by_name}
            onChange={(value) => handleChange('read_by_name', value)}
            placeholder="Search for user..."
          />
          <div style={styles.hint}>
            The user who read/recorded the audio
          </div>
        </div>

        <div style={styles.sectionDivider}>
          <span>Link to Writeup (Optional)</span>
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Writeup Author:</label>
          <UserSearchField
            value={formData.writeup_author}
            onChange={(value) => handleChange('writeup_author', value)}
            placeholder="Search for author..."
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Writeup Title (e2node name):</label>
          <E2nodeSearchField
            value={formData.writeup_title}
            onChange={(value) => handleChange('writeup_title', value)}
            placeholder={formData.writeup_author ? "Search e2nodes with writeups by this author..." : "Select author first, then search..."}
            author={formData.writeup_author}
            disabled={!formData.writeup_author}
          />
          <div style={styles.hint}>
            {formData.writeup_author
              ? `Showing e2nodes where ${formData.writeup_author} has a writeup`
              : 'Select an author above to search for their writeups'}
          </div>
        </div>

        <div style={styles.buttonRow}>
          <button
            onClick={handleSave}
            disabled={saving}
            style={styles.saveButton}
          >
            {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
            <span style={{ marginLeft: 6 }}>{saving ? 'Saving...' : 'Save Changes'}</span>
          </button>
        </div>
      </div>
    </div>
  )
}

const styles = {
  container: {
    maxWidth: 800,
    margin: '0 auto',
    padding: '16px 0'
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 18,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 16,
    paddingBottom: 12,
    borderBottom: '2px solid #38495e'
  },
  headerTitle: {
    flex: 1
  },
  displayLink: {
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  message: {
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
    border: '1px solid'
  },
  podcastInfo: {
    display: 'flex',
    alignItems: 'center',
    padding: 12,
    marginBottom: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    fontSize: 14
  },
  form: {
    marginBottom: 24
  },
  field: {
    marginBottom: 16
  },
  label: {
    display: 'block',
    fontWeight: 'bold',
    marginBottom: 4,
    color: '#38495e'
  },
  input: {
    width: '100%',
    padding: '8px 10px',
    fontSize: 14,
    border: '1px solid #ccc',
    borderRadius: 4,
    boxSizing: 'border-box'
  },
  hint: {
    marginTop: 4,
    fontSize: 12,
    color: '#666'
  },
  sectionDivider: {
    margin: '24px 0 16px 0',
    paddingBottom: 8,
    borderBottom: '1px solid #ddd',
    fontSize: 14,
    fontWeight: 'bold',
    color: '#507898'
  },
  buttonRow: {
    marginTop: 24
  },
  saveButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '10px 20px',
    backgroundColor: '#4060b0',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 14,
    fontWeight: 'bold'
  }
}

export default RecordingEdit

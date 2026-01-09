import React, { useState, useCallback, useEffect, useRef } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import LinkNode from '../LinkNode'
import { FaUsers, FaUser, FaLock, FaSave, FaSpinner, FaTrash, FaEye, FaLockOpen, FaGlobe, FaTimes, FaSearch } from 'react-icons/fa'
import '../Editor/E2Editor.css'

/**
 * CollaborationEdit - Edit page for collaboration nodes
 *
 * Features:
 * - Lock status display (always locked by current user in edit mode)
 * - TipTap rich editor with Rich/HTML toggle
 * - Public/private toggle
 * - Member management (admin/CE only)
 * - Save/unlock actions
 */

// Get initial editor mode from localStorage
const getInitialEditorMode = () => {
  try {
    const stored = localStorage.getItem('e2_editor_mode')
    if (stored === 'html') return 'html'
  } catch (e) {
    // localStorage may not be available
  }
  return 'rich'
}

const CollaborationEdit = ({ data }) => {
  if (!data) return null

  const {
    collaboration,
    members: initialMembers,
    lockedby,
    can_manage_members,
    user
  } = data

  const [isPublic, setIsPublic] = useState(collaboration.public === 1)
  const [members, setMembers] = useState(initialMembers || [])
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(collaboration.doctext || '')

  // Member management state (admin/CE only)
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState([])
  const [isSearching, setIsSearching] = useState(false)
  const [addingMember, setAddingMember] = useState(false)
  const [hoveredResult, setHoveredResult] = useState(null)
  const searchTimeoutRef = useRef(null)
  const searchContainerRef = useRef(null)

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: breakTags(collaboration.doctext || ''),
    editorProps: {
      attributes: {
        class: 'e2-editor-content'
      }
    }
  })

  // Set initial HTML content for HTML mode
  useEffect(() => {
    setHtmlContent(collaboration.doctext || '')
  }, [collaboration.doctext])

  // Close search results when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (searchContainerRef.current && !searchContainerRef.current.contains(event.target)) {
        setSearchResults([])
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Live search for members
  const handleSearch = async (query) => {
    setSearchQuery(query)
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    if (query.length < 2) {
      setSearchResults([])
      return
    }
    searchTimeoutRef.current = setTimeout(async () => {
      setIsSearching(true)
      try {
        const response = await fetch(
          `/api/node_search?q=${encodeURIComponent(query)}&scope=group_addable&group_id=${collaboration.node_id}`
        )
        const data = await response.json()
        if (data.success) {
          // Filter out current members
          const currentIds = new Set(members.map(m => m.node_id))
          setSearchResults(data.results.filter(r => !currentIds.has(r.node_id)))
        }
      } catch (error) {
        console.error('Search failed:', error)
      } finally {
        setIsSearching(false)
      }
    }, 300)
  }

  // Handle mode toggle
  const handleModeToggle = useCallback(() => {
    const newMode = editorMode === 'rich' ? 'html' : 'rich'

    if (editor) {
      if (editorMode === 'rich') {
        // Switching to HTML - capture rich content
        const html = editor.getHTML()
        const withEntities = convertRawBracketsToEntities(html)
        setHtmlContent(convertToE2Syntax(withEntities))
      } else {
        // Switching to rich - load HTML into editor
        editor.commands.setContent(breakTags(htmlContent))
      }
    }

    setEditorMode(newMode)

    // Save preference to localStorage
    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // localStorage may not be available
    }

    // Persist to server
    fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tiptap_editor_raw: newMode === 'html' ? 1 : 0 })
    }).catch(err => console.error('Failed to save editor mode preference:', err))
  }, [editor, editorMode, htmlContent])

  // Get current doctext content - called at save time
  const getCurrentDoctext = () => {
    if (editorMode === 'html') {
      return htmlContent
    }
    if (editor) {
      const html = editor.getHTML()
      const withEntities = convertRawBracketsToEntities(html)
      return convertToE2Syntax(withEntities)
    }
    return ''
  }

  // Handle HTML textarea change
  const handleHtmlChange = useCallback((e) => {
    setHtmlContent(e.target.value)
    setMessage(null)
  }, [])

  const handleSave = async () => {
    // Don't save if editor isn't ready in rich mode
    if (editorMode === 'rich' && !editor) {
      setMessage({ type: 'error', text: 'Editor is still loading, please wait...' })
      return
    }

    setSaving(true)
    setMessage(null)

    const doctext = getCurrentDoctext()

    try {
      const response = await fetch(`/api/collaborations/${collaboration.node_id}/action/save`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ doctext, public: isPublic ? 1 : 0 })
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: 'Saved successfully!' })
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to save' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setSaving(false)
    }
  }

  const handleUnlock = async () => {
    try {
      const response = await fetch(`/api/collaborations/${collaboration.node_id}/action/unlock`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include'
      })

      const result = await response.json()

      if (result.success) {
        // Redirect to display page
        window.location.href = `/node/${collaboration.node_id}`
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to unlock' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    }
  }

  const handleAddMember = async (selectedMember) => {
    if (!selectedMember) return

    setAddingMember(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/collaborations/${collaboration.node_id}/action/addmember`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ name: selectedMember.title })
      })

      const result = await response.json()

      if (result.success) {
        setMembers(result.members || members)
        setSearchQuery('')
        setSearchResults([])
        setMessage({ type: 'success', text: `Added ${selectedMember.title}` })
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to add member' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setAddingMember(false)
    }
  }

  const handleRemoveMember = async (memberId) => {
    try {
      const response = await fetch(`/api/collaborations/${collaboration.node_id}/action/removemember`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ node_id: memberId })
      })

      const result = await response.json()

      if (result.success) {
        setMembers(result.members || members.filter(m => m.node_id !== memberId))
        setMessage({ type: 'success', text: 'Member removed' })
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to remove member' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    }
  }

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaUsers style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.headerTitle}>Edit Collaboration: {collaboration.title}</span>
        <div style={styles.headerActions}>
          <a href={`/node/${collaboration.node_id}`} style={styles.displayLink}>
            <FaEye style={{ marginRight: 4 }} />
            display
          </a>
          <button onClick={handleUnlock} style={styles.unlockButton}>
            <FaLockOpen style={{ marginRight: 4 }} />
            unlock
          </button>
          {user.is_admin && (
            <a
              href={`/?node_id=${collaboration.node_id}&confirmop=nuke`}
              style={styles.deleteLink}
            >
              <FaTrash style={{ marginRight: 4 }} />
              delete
            </a>
          )}
        </div>
      </div>

      {/* Lock status */}
      <div style={styles.lockStatus}>
        <FaLock style={{ marginRight: 8, color: '#155724' }} />
        <span>Locked by you</span>
        <span style={{ marginLeft: 8, fontSize: 12, color: '#666' }}>
          (Lock expires after 15 minutes of inactivity)
        </span>
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

      {/* Members section (admin/CE only) */}
      {can_manage_members && (
        <div style={styles.membersSection}>
          <h3 style={styles.sectionTitle}>
            <FaUsers style={{ marginRight: 8 }} />
            Allowed Users/Groups
          </h3>
          <div style={styles.membersList}>
            {members.map(member => (
              <span key={member.node_id} style={styles.memberChip}>
                <LinkNode {...member} type={member.type} />
                <button
                  onClick={() => handleRemoveMember(member.node_id)}
                  style={styles.removeMemberButton}
                  title="Remove"
                >
                  <FaTimes />
                </button>
              </span>
            ))}
          </div>
          <div style={styles.searchContainer} ref={searchContainerRef}>
            <div style={styles.searchInputWrapper}>
              <FaSearch style={styles.searchIcon} />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => handleSearch(e.target.value)}
                placeholder="Search for users or usergroups..."
                style={styles.searchInput}
                disabled={addingMember}
              />
              {isSearching && <FaSpinner className="fa-spin" style={styles.searchSpinner} />}
            </div>
            {searchResults.length > 0 && (
              <div style={styles.searchResults}>
                {searchResults.map(result => (
                  <div
                    key={result.node_id}
                    style={{
                      ...styles.searchResultItem,
                      backgroundColor: hoveredResult === result.node_id ? '#e8f4f8' : 'transparent'
                    }}
                    onClick={() => handleAddMember(result)}
                    onMouseEnter={() => setHoveredResult(result.node_id)}
                    onMouseLeave={() => setHoveredResult(null)}
                  >
                    {result.type === 'usergroup' ? (
                      <FaUsers style={{ marginRight: 8, color: '#4060b0' }} />
                    ) : (
                      <FaUser style={{ marginRight: 8, color: '#507898' }} />
                    )}
                    <span>{result.title}</span>
                    <span style={styles.resultType}>{result.type}</span>
                  </div>
                ))}
              </div>
            )}
            {searchQuery.length >= 2 && !isSearching && searchResults.length === 0 && (
              <div style={styles.noResults}>
                No users or usergroups found matching "{searchQuery}"
              </div>
            )}
          </div>
        </div>
      )}

      {/* Public toggle */}
      <div style={styles.publicToggle}>
        <label style={styles.checkboxLabel}>
          <input
            type="checkbox"
            checked={isPublic}
            onChange={(e) => setIsPublic(e.target.checked)}
            style={{ marginRight: 8 }}
          />
          <FaGlobe style={{ marginRight: 6, color: isPublic ? '#155724' : '#666' }} />
          Public (visible to everyone, even without access)
        </label>
      </div>

      {/* Editor */}
      <div style={styles.editorSection}>
        <div style={styles.editorHeader}>
          <label style={styles.label}>Content:</label>
          <EditorModeToggle
            mode={editorMode}
            onToggle={handleModeToggle}
            disabled={saving}
          />
        </div>

        {editorMode === 'rich' ? (
          <div style={styles.editorContainer}>
            <MenuBar editor={editor} />
            <div className="e2-editor-wrapper" style={{ padding: '12px', minHeight: 300 }}>
              <EditorContent editor={editor} />
            </div>
          </div>
        ) : (
          <textarea
            value={htmlContent}
            onChange={handleHtmlChange}
            placeholder="Enter HTML content here..."
            aria-label="Content (HTML)"
            style={styles.htmlTextarea}
            spellCheck={false}
          />
        )}
      </div>

      {/* Save button */}
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
    flexWrap: 'wrap',
    gap: 8,
    fontSize: 18,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 16,
    paddingBottom: 12,
    borderBottom: '2px solid #38495e'
  },
  headerTitle: {
    flex: 1,
    minWidth: 200
  },
  headerActions: {
    display: 'flex',
    gap: 12,
    alignItems: 'center'
  },
  displayLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  unlockButton: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#28a745',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    padding: 0
  },
  deleteLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#dc3545',
    textDecoration: 'none'
  },
  lockStatus: {
    display: 'flex',
    alignItems: 'center',
    padding: 12,
    marginBottom: 16,
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: 4,
    color: '#155724'
  },
  message: {
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
    border: '1px solid'
  },
  membersSection: {
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    padding: 16,
    marginBottom: 20
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    fontWeight: 'bold',
    color: '#38495e',
    marginTop: 0,
    marginBottom: 12
  },
  membersList: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 12
  },
  memberChip: {
    display: 'inline-flex',
    alignItems: 'center',
    backgroundColor: '#e8f4f8',
    padding: '4px 8px',
    borderRadius: 4,
    fontSize: 13
  },
  removeMemberButton: {
    marginLeft: 6,
    padding: '2px 4px',
    background: 'none',
    border: 'none',
    color: '#dc3545',
    cursor: 'pointer',
    fontSize: 12
  },
  searchContainer: {
    position: 'relative'
  },
  searchInputWrapper: {
    display: 'flex',
    alignItems: 'center',
    border: '1px solid #38495e',
    borderRadius: 4,
    backgroundColor: '#fff',
    padding: '6px 10px'
  },
  searchIcon: {
    color: '#507898',
    marginRight: 8,
    fontSize: 14
  },
  searchInput: {
    flex: 1,
    border: 'none',
    outline: 'none',
    fontSize: 13,
    color: '#38495e',
    backgroundColor: 'transparent'
  },
  searchSpinner: {
    color: '#507898',
    marginLeft: 8,
    fontSize: 14
  },
  searchResults: {
    position: 'absolute',
    top: '100%',
    left: 0,
    right: 0,
    backgroundColor: '#fff',
    border: '1px solid #38495e',
    borderTop: 'none',
    borderRadius: '0 0 4px 4px',
    maxHeight: 200,
    overflowY: 'auto',
    zIndex: 100,
    boxShadow: '0 4px 8px rgba(56,73,94,0.15)'
  },
  searchResultItem: {
    display: 'flex',
    alignItems: 'center',
    padding: '8px 12px',
    cursor: 'pointer',
    fontSize: 13,
    color: '#38495e',
    borderBottom: '1px solid #e8f4f8',
    transition: 'background-color 0.15s'
  },
  resultType: {
    marginLeft: 'auto',
    fontSize: 11,
    color: '#507898',
    backgroundColor: '#e8f4f8',
    padding: '2px 6px',
    borderRadius: 3
  },
  noResults: {
    position: 'absolute',
    top: '100%',
    left: 0,
    right: 0,
    backgroundColor: '#fff',
    border: '1px solid #38495e',
    borderTop: 'none',
    borderRadius: '0 0 4px 4px',
    padding: '12px',
    fontSize: 13,
    color: '#507898',
    textAlign: 'center'
  },
  publicToggle: {
    marginBottom: 16,
    padding: 12,
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  checkboxLabel: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    cursor: 'pointer'
  },
  editorSection: {
    marginBottom: 16
  },
  editorHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8
  },
  label: {
    fontWeight: 'bold',
    color: '#38495e'
  },
  editorContainer: {
    border: '1px solid #ced4da',
    borderRadius: 4,
    backgroundColor: '#fff',
    overflow: 'hidden'
  },
  htmlTextarea: {
    width: '100%',
    minHeight: 300,
    fontFamily: 'monospace',
    fontSize: 13,
    padding: 12,
    border: '1px solid #ced4da',
    borderRadius: 4,
    backgroundColor: '#fff',
    color: '#212529',
    lineHeight: 1.5,
    resize: 'vertical',
    boxSizing: 'border-box'
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

export default CollaborationEdit

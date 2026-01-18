import React, { useState, useCallback, useEffect, useRef } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import LinkNode from '../LinkNode'
import ConfirmActionModal from '../ConfirmActionModal'
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
  const searchTimeoutRef = useRef(null)
  const searchContainerRef = useRef(null)

  // Delete confirmation modal state
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)

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

  const handleDelete = () => {
    setIsDeleting(true)
    // Navigate to the delete action URL
    window.location.href = `/?node_id=${collaboration.node_id}&op=nuke`
  }

  return (
    <div className="collab-edit">
      {/* Header */}
      <div className="collab-edit__header">
        <FaUsers className="collab-edit__header-icon" />
        <span className="collab-edit__header-title">Edit Collaboration: {collaboration.title}</span>
        <div className="collab-edit__header-actions">
          <a href={`/node/${collaboration.node_id}`} className="collab-edit__display-link">
            <FaEye style={{ marginRight: 4 }} />
            display
          </a>
          <button onClick={handleUnlock} className="collab-edit__unlock-btn">
            <FaLockOpen style={{ marginRight: 4 }} />
            unlock
          </button>
          {user.is_admin && (
            <button
              onClick={() => setShowDeleteModal(true)}
              className="collab-edit__delete-btn"
            >
              <FaTrash style={{ marginRight: 4 }} />
              delete
            </button>
          )}
        </div>
      </div>

      {/* Lock status */}
      <div className="collab-edit__lock-status">
        <FaLock className="collab-edit__lock-icon" />
        <span>Locked by you</span>
        <span className="collab-edit__lock-hint">
          (Lock expires after 15 minutes of inactivity)
        </span>
      </div>

      {/* Message */}
      {message && (
        <div className={`collab-edit__message collab-edit__message--${message.type}`}>
          {message.text}
        </div>
      )}

      {/* Members section (admin/CE only) */}
      {can_manage_members && (
        <div className="collab-edit__members">
          <h3 className="collab-edit__section-title">
            <FaUsers />
            Allowed Users/Groups
          </h3>
          <div className="collab-edit__members-list">
            {members.map(member => (
              <span key={member.node_id} className="collab-edit__member-chip">
                <LinkNode {...member} type={member.type} />
                <button
                  onClick={() => handleRemoveMember(member.node_id)}
                  className="collab-edit__member-remove"
                  title="Remove"
                >
                  <FaTimes />
                </button>
              </span>
            ))}
          </div>
          <div className="collab-edit__search" ref={searchContainerRef}>
            <div className="collab-edit__search-input-wrapper">
              <FaSearch className="collab-edit__search-icon" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => handleSearch(e.target.value)}
                placeholder="Search for users or usergroups..."
                className="collab-edit__search-input"
                disabled={addingMember}
              />
              {isSearching && <FaSpinner className="fa-spin collab-edit__search-spinner" />}
            </div>
            {searchResults.length > 0 && (
              <div className="collab-edit__search-results">
                {searchResults.map(result => (
                  <div
                    key={result.node_id}
                    className="collab-edit__search-result"
                    onClick={() => handleAddMember(result)}
                  >
                    {result.type === 'usergroup' ? (
                      <FaUsers style={{ color: '#4060b0' }} />
                    ) : (
                      <FaUser style={{ color: '#507898' }} />
                    )}
                    <span>{result.title}</span>
                    <span className="collab-edit__result-type">{result.type}</span>
                  </div>
                ))}
              </div>
            )}
            {searchQuery.length >= 2 && !isSearching && searchResults.length === 0 && (
              <div className="collab-edit__no-results">
                No users or usergroups found matching "{searchQuery}"
              </div>
            )}
          </div>
        </div>
      )}

      {/* Public toggle */}
      <div className="collab-edit__public-toggle">
        <label className="collab-edit__checkbox-label">
          <input
            type="checkbox"
            checked={isPublic}
            onChange={(e) => setIsPublic(e.target.checked)}
          />
          <FaGlobe className={`collab-edit__public-icon ${isPublic ? 'collab-edit__public-icon--active' : 'collab-edit__public-icon--inactive'}`} />
          Public (visible to everyone, even without access)
        </label>
      </div>

      {/* Editor */}
      <div className="collab-edit__editor">
        <div className="collab-edit__editor-header">
          <label className="collab-edit__label">Content:</label>
          <EditorModeToggle
            mode={editorMode}
            onToggle={handleModeToggle}
            disabled={saving}
          />
        </div>

        {editorMode === 'rich' ? (
          <div className="collab-edit__editor-container">
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
            className="collab-edit__html-textarea"
            spellCheck={false}
          />
        )}
      </div>

      {/* Save button */}
      <div className="collab-edit__button-row">
        <button
          onClick={handleSave}
          disabled={saving}
          className="collab-edit__save-btn"
        >
          {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
          <span style={{ marginLeft: 6 }}>{saving ? 'Saving...' : 'Save Changes'}</span>
        </button>
      </div>

      {/* Delete confirmation modal */}
      <ConfirmActionModal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        onConfirm={handleDelete}
        title="Delete Collaboration"
        message={`Do you really want to delete this collaboration "${collaboration.title}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmStyle="danger"
        isSubmitting={isDeleting}
      />
    </div>
  )
}

export default CollaborationEdit

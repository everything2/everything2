import React, { useState, useCallback, useRef, useMemo } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import PreviewContent from '../Editor/PreviewContent'
import LinkNode from '../LinkNode'
import { FaFolder, FaSave, FaTimes, FaGripVertical, FaTrash, FaCheck, FaSpinner, FaEye } from 'react-icons/fa'
import { fetchWithErrorReporting } from '../../utils/reportClientError'
import '../Editor/E2Editor.css'

/**
 * CategoryEdit - Edit component for category nodes
 *
 * Uses the same TipTap editor as InlineWriteupEditor for consistency.
 * Provides rich text/HTML toggle and preview functionality.
 * Editors+ can change title and owner.
 * Editors/owners can reorder and remove members.
 */

// Get initial editor mode from localStorage (same preference as writeup editor)
const getInitialEditorMode = () => {
  try {
    const stored = localStorage.getItem('e2_editor_mode')
    if (stored === 'html') return 'html'
  } catch (e) {
    // localStorage may not be available
  }
  return 'rich'
}

/**
 * SortableMemberItem - Draggable category member with remove button
 */
function SortableMemberItem({ member, onRemove }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: member.node_id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    padding: '10px 12px',
    margin: '4px 0',
    backgroundColor: isDragging ? '#f0f4ff' : 'white',
    border: '1px solid #ddd',
    borderRadius: '4px',
    cursor: 'grab',
    userSelect: 'none',
    opacity: isDragging ? 0.7 : 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  }

  // e2nodes are always owned by Content Editors, so skip showing author for them
  const showAuthor = member.type !== 'e2node'

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      <div style={{ display: 'flex', alignItems: 'center', flex: 1, gap: '8px' }}>
        <span style={{ color: '#4060b0' }}>
          <FaGripVertical size={14} />
        </span>
        <LinkNode nodeId={member.node_id} title={member.title} type={member.type} />
        {showAuthor && (
          <span style={{ color: '#666', fontSize: '12px' }}>
            by {member.author}
          </span>
        )}
      </div>
      <button
        onClick={(e) => {
          e.stopPropagation()
          e.preventDefault()
          onRemove(member)
        }}
        onPointerDown={(e) => e.stopPropagation()}
        style={{
          padding: '4px 8px',
          fontSize: '12px',
          border: '1px solid #d9534f',
          borderRadius: '3px',
          backgroundColor: 'white',
          color: '#d9534f',
          cursor: 'pointer',
          display: 'flex',
          alignItems: 'center',
          gap: '4px'
        }}
        title="Remove from category"
      >
        <FaTrash size={10} />
      </button>
    </div>
  )
}

const CategoryEdit = ({ data }) => {
  const { category, viewer, members: initialMembers, can_edit_meta, can_manage_members, guest_user_id } = data

  if (!category) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>Category not found.</div>
      </div>
    )
  }

  const { node_id, title, description, author, author_id, is_public } = category

  // Editor state
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(description || '')
  const [isSaving, setIsSaving] = useState(false)
  const [saveStatus, setSaveStatus] = useState(null)
  const [showPreview, setShowPreview] = useState(true)
  const [previewTrigger, setPreviewTrigger] = useState(0)
  const [hasChanges, setHasChanges] = useState(false)
  const lastSavedContent = useRef(description || '')

  // Meta editing state (title/owner - editors only)
  const [categoryTitle, setCategoryTitle] = useState(title)
  const [isPublic, setIsPublic] = useState(is_public)
  const [ownerName, setOwnerName] = useState(author || '')
  const [ownerValidation, setOwnerValidation] = useState({
    valid: true,
    checking: false,
    node_id: author_id,
    type: category.author_type || 'user'
  })
  const [hasMetaChanges, setHasMetaChanges] = useState(false)
  const [isMetaSaving, setIsMetaSaving] = useState(false)
  const [metaSaveStatus, setMetaSaveStatus] = useState(null)
  const ownerDebounceRef = useRef(null)

  // Member management state
  const [members, setMembers] = useState(initialMembers || [])
  const [hasMemberChanges, setHasMemberChanges] = useState(false)
  const [isMemberSaving, setIsMemberSaving] = useState(false)
  const [memberSaveStatus, setMemberSaveStatus] = useState(null)

  // DnD sensors
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: description || '',
    editable: true,
    onUpdate: ({ editor }) => {
      const newContent = editor.getHTML()
      if (editorMode === 'rich') {
        setHtmlContent(newContent)
      }
      setHasChanges(newContent !== lastSavedContent.current)
      setPreviewTrigger(prev => prev + 1)
    }
  })

  // Toggle between rich and HTML modes
  const handleModeToggle = useCallback(() => {
    if (!editor) return

    const newMode = editorMode === 'rich' ? 'html' : 'rich'

    if (editorMode === 'rich') {
      const html = editor.getHTML()
      const e2Html = convertToE2Syntax(html)
      const cleanedHtml = convertRawBracketsToEntities(e2Html)
      setHtmlContent(cleanedHtml)
    } else {
      // Apply breakTags to convert plain-text newlines to proper HTML paragraphs
      const withBreaks = breakTags(htmlContent)
      editor.commands.setContent(convertEntitiesToRawBrackets(withBreaks))
    }

    setEditorMode(newMode)

    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // localStorage may not be available
    }

    fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ tiptap_editor_raw: newMode === 'html' ? 1 : 0 })
    }).catch(err => console.error('Failed to save editor mode preference:', err))
  }, [editor, editorMode, htmlContent])

  // Get current content based on mode
  const getCurrentContent = useCallback(() => {
    if (editorMode === 'html') {
      return htmlContent
    } else if (editor) {
      let content = editor.getHTML()
      content = convertToE2Syntax(content)
      content = convertRawBracketsToEntities(content)
      return content
    }
    return htmlContent
  }, [editor, editorMode, htmlContent])

  // Save category description
  const handleSave = useCallback(async () => {
    const content = getCurrentContent()
    setIsSaving(true)
    setSaveStatus(null)

    try {
      const response = await fetchWithErrorReporting('/api/category/update', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          node_id: node_id,
          doctext: content
        })
      })

      const result = await response.json()

      if (result.success) {
        setSaveStatus({ type: 'success', message: 'Saved successfully!' })
        lastSavedContent.current = content
        setHasChanges(false)
        setTimeout(() => {
          window.location.href = `/node/${node_id}`
        }, 1000)
      } else {
        setSaveStatus({ type: 'error', message: result.error || 'Failed to save' })
      }
    } catch (error) {
      console.error('Error saving category:', error)
      setSaveStatus({ type: 'error', message: 'Network error. Please try again.' })
    } finally {
      setIsSaving(false)
    }
  }, [node_id, getCurrentContent])

  // Cancel editing
  const handleCancel = useCallback(() => {
    if (hasChanges || hasMetaChanges || hasMemberChanges) {
      if (!window.confirm('You have unsaved changes. Are you sure you want to cancel?')) {
        return
      }
    }
    window.location.href = `/node/${node_id}`
  }, [node_id, hasChanges, hasMetaChanges, hasMemberChanges])

  // Handle HTML textarea changes
  const handleHtmlChange = (e) => {
    setHtmlContent(e.target.value)
    setHasChanges(e.target.value !== lastSavedContent.current)
    setPreviewTrigger(prev => prev + 1)
  }

  // ========== Meta Editing (Title/Owner) ==========

  const handleTitleChange = (e) => {
    setCategoryTitle(e.target.value)
    setHasMetaChanges(true)
    setMetaSaveStatus(null)
  }

  const handlePublicToggle = (e) => {
    setIsPublic(e.target.checked)
    setHasMetaChanges(true)
    setMetaSaveStatus(null)
    if (e.target.checked) {
      // Clear owner validation when switching to public
      setOwnerName('')
      setOwnerValidation({ valid: true, checking: false, node_id: guest_user_id, type: 'user' })
    }
  }

  const handleOwnerChange = (e) => {
    const name = e.target.value
    setOwnerName(name)
    setHasMetaChanges(true)
    setMetaSaveStatus(null)
    setOwnerValidation(prev => ({ ...prev, valid: null, checking: false }))

    // Debounce the API lookup
    if (ownerDebounceRef.current) {
      clearTimeout(ownerDebounceRef.current)
    }

    if (name.trim().length > 0) {
      ownerDebounceRef.current = setTimeout(() => {
        validateOwner(name)
      }, 500)
    }
  }

  const validateOwner = async (name) => {
    if (!name || name.trim().length === 0) {
      setOwnerValidation({ valid: false, checking: false, node_id: null })
      return
    }

    setOwnerValidation(prev => ({ ...prev, checking: true }))

    try {
      const response = await fetch(`/api/category/lookup_owner?name=${encodeURIComponent(name)}`, {
        credentials: 'same-origin'
      })
      const result = await response.json()

      if (result.success && result.found) {
        setOwnerValidation({
          valid: true,
          checking: false,
          node_id: result.node_id,
          type: result.type,
          title: result.title
        })
      } else {
        setOwnerValidation({ valid: false, checking: false, node_id: null })
      }
    } catch (error) {
      console.error('Error validating owner:', error)
      setOwnerValidation({ valid: false, checking: false, node_id: null })
    }
  }

  const handleSaveMeta = async () => {
    if (!hasMetaChanges) return

    // Validate before saving
    if (!categoryTitle.trim()) {
      setMetaSaveStatus({ type: 'error', message: 'Title cannot be empty' })
      return
    }
    if (!isPublic && !ownerValidation.valid) {
      setMetaSaveStatus({ type: 'error', message: 'Please enter a valid owner' })
      return
    }

    setIsMetaSaving(true)
    setMetaSaveStatus(null)

    try {
      const payload = {
        node_id: node_id,
        title: categoryTitle
      }

      if (isPublic) {
        payload.author_user = guest_user_id
      } else if (ownerValidation.node_id) {
        payload.author_user = ownerValidation.node_id
      }

      const response = await fetchWithErrorReporting('/api/category/update_meta', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      const result = await response.json()

      if (result.success) {
        setMetaSaveStatus({ type: 'success', message: 'Settings saved!' })
        setHasMetaChanges(false)
        // If title changed, we may need to update the URL
        if (categoryTitle !== title) {
          setTimeout(() => {
            window.location.href = `/node/${node_id}?op=edit`
          }, 1000)
        }
      } else {
        setMetaSaveStatus({ type: 'error', message: result.error || 'Failed to save' })
      }
    } catch (error) {
      console.error('Error saving category meta:', error)
      setMetaSaveStatus({ type: 'error', message: 'Network error. Please try again.' })
    } finally {
      setIsMetaSaving(false)
    }
  }

  // ========== Member Management ==========

  const handleDragEnd = (event) => {
    const { active, over } = event

    if (active.id !== over?.id) {
      setMembers((items) => {
        const oldIndex = items.findIndex(i => i.node_id === active.id)
        const newIndex = items.findIndex(i => i.node_id === over.id)
        return arrayMove(items, oldIndex, newIndex)
      })
      setHasMemberChanges(true)
      setMemberSaveStatus(null)
    }
  }

  const handleRemoveMember = async (member) => {
    if (!window.confirm(`Remove "${member.title}" from this category?`)) {
      return
    }

    try {
      const response = await fetchWithErrorReporting('/api/category/remove_member', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          node_id: node_id,
          member_id: member.node_id
        })
      })

      const result = await response.json()

      if (result.success) {
        setMembers(prev => prev.filter(m => m.node_id !== member.node_id))
        setMemberSaveStatus({ type: 'success', message: 'Member removed' })
        setTimeout(() => setMemberSaveStatus(null), 2000)
      } else {
        setMemberSaveStatus({ type: 'error', message: result.error || 'Failed to remove' })
      }
    } catch (error) {
      console.error('Error removing member:', error)
      setMemberSaveStatus({ type: 'error', message: 'Network error' })
    }
  }

  const handleSaveMemberOrder = async () => {
    setIsMemberSaving(true)
    setMemberSaveStatus(null)

    try {
      const response = await fetchWithErrorReporting('/api/category/reorder_members', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          node_id: node_id,
          member_ids: members.map(m => m.node_id)
        })
      })

      const result = await response.json()

      if (result.success) {
        setMemberSaveStatus({ type: 'success', message: 'Order saved!' })
        setHasMemberChanges(false)
      } else {
        setMemberSaveStatus({ type: 'error', message: result.error || 'Failed to save order' })
      }
    } catch (error) {
      console.error('Error saving member order:', error)
      setMemberSaveStatus({ type: 'error', message: 'Network error' })
    } finally {
      setIsMemberSaving(false)
    }
  }

  // Member IDs for sortable context
  const memberIds = useMemo(() => members.map(m => m.node_id), [members])

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <div style={styles.headerTop}>
          <div style={styles.titleRow}>
            <FaFolder size={20} style={{ color: '#4060b0', marginRight: '10px' }} />
            <h1 style={styles.title}>Editing: {title}</h1>
          </div>
          <a
            href={`/node/${node_id}`}
            style={styles.viewButton}
            title="View category"
          >
            <FaEye size={14} style={{ marginRight: '6px' }} />
            View
          </a>
        </div>
        <div style={styles.meta}>
          <span style={styles.metaItem}>
            {is_public ? 'Public category' : `Maintained by ${author}`}
          </span>
        </div>
      </div>

      {/* Category Settings Section (editors+ only) */}
      {can_edit_meta && (
        <div style={styles.settingsSection}>
          <h2 style={styles.sectionTitle}>Category Settings</h2>

          <div style={styles.formRow}>
            <label style={styles.label}>Title:</label>
            <input
              type="text"
              value={categoryTitle}
              onChange={handleTitleChange}
              style={styles.textInput}
            />
          </div>

          <div style={styles.formRow}>
            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                checked={isPublic}
                onChange={handlePublicToggle}
                style={{ marginRight: '8px' }}
              />
              Public category (anyone can edit)
            </label>
          </div>

          {!isPublic && (
            <div style={styles.formRow}>
              <label style={styles.label}>Owner:</label>
              <div style={styles.ownerInputWrapper}>
                <input
                  type="text"
                  value={ownerName}
                  onChange={handleOwnerChange}
                  placeholder="Enter username or usergroup"
                  style={{
                    ...styles.textInput,
                    flex: 1,
                    borderColor: ownerValidation.valid === false ? '#d9534f' :
                                 ownerValidation.valid === true ? '#5cb85c' : '#ccc'
                  }}
                />
                {ownerValidation.checking && (
                  <span style={styles.validationIcon}>
                    <FaSpinner className="fa-spin" size={14} style={{ color: '#666' }} />
                  </span>
                )}
                {ownerValidation.valid === true && !ownerValidation.checking && (
                  <span style={styles.validationIcon}>
                    <FaCheck size={14} style={{ color: '#5cb85c' }} />
                    <span style={{ marginLeft: '4px', fontSize: '11px', color: '#666' }}>
                      ({ownerValidation.type})
                    </span>
                  </span>
                )}
                {ownerValidation.valid === false && !ownerValidation.checking && ownerName && (
                  <span style={{ ...styles.validationIcon, color: '#d9534f' }}>
                    Not found
                  </span>
                )}
              </div>
            </div>
          )}

          <div style={styles.settingsActions}>
            {metaSaveStatus && (
              <span style={{
                color: metaSaveStatus.type === 'success' ? '#5cb85c' : '#d9534f',
                fontSize: '12px',
                marginRight: '10px'
              }}>
                {metaSaveStatus.message}
              </span>
            )}
            <button
              onClick={handleSaveMeta}
              disabled={!hasMetaChanges || isMetaSaving || (!isPublic && !ownerValidation.valid)}
              style={{
                ...styles.saveSettingsButton,
                opacity: (!hasMetaChanges || isMetaSaving || (!isPublic && !ownerValidation.valid)) ? 0.5 : 1,
                cursor: (!hasMetaChanges || isMetaSaving || (!isPublic && !ownerValidation.valid)) ? 'not-allowed' : 'pointer'
              }}
            >
              {isMetaSaving ? 'Saving...' : 'Save Settings'}
            </button>
          </div>
        </div>
      )}

      {/* Member Management Section */}
      {can_manage_members && members.length > 0 ? (
        <div style={styles.membersSection}>
          <h2 style={styles.sectionTitle}>
            Manage Members ({members.length})
          </h2>
          <p style={styles.membersHelp}>
            Drag to reorder. Click × to remove.
          </p>

          <DndContext
            sensors={sensors}
            collisionDetection={closestCenter}
            onDragEnd={handleDragEnd}
          >
            <SortableContext
              items={memberIds}
              strategy={verticalListSortingStrategy}
            >
              {members.map(member => (
                <SortableMemberItem
                  key={member.node_id}
                  member={member}
                  onRemove={handleRemoveMember}
                />
              ))}
            </SortableContext>
          </DndContext>

          <div style={styles.memberActions}>
            {memberSaveStatus && (
              <span style={{
                color: memberSaveStatus.type === 'success' ? '#5cb85c' : '#d9534f',
                fontSize: '12px',
                marginRight: '10px'
              }}>
                {memberSaveStatus.message}
              </span>
            )}
            {hasMemberChanges && (
              <button
                onClick={handleSaveMemberOrder}
                disabled={isMemberSaving}
                style={{
                  ...styles.saveSettingsButton,
                  opacity: isMemberSaving ? 0.5 : 1
                }}
              >
                {isMemberSaving ? 'Saving...' : 'Save Order'}
              </button>
            )}
          </div>
        </div>
      ) : null}

      {/* Description Editor Section */}
      <div style={styles.editorSectionWrapper}>
        {/* Toolbar with mode toggle */}
        <div style={styles.toolbar}>
          <div style={styles.toolbarLeft}>
            {hasChanges && (
              <span style={styles.unsavedIndicator}>Unsaved changes</span>
            )}
            {saveStatus && (
              <span style={{
                ...styles.saveStatus,
                color: saveStatus.type === 'success' ? '#22c55e' : '#f44336'
              }}>
                {saveStatus.message}
              </span>
            )}
          </div>
          <div style={styles.toolbarRight}>
            {/* Rich/HTML mode toggle - uses shared CSS from E2Editor.css */}
            <div
              className="e2-mode-toggle"
              onClick={handleModeToggle}
              title={editorMode === 'rich' ? 'Switch to raw HTML editing' : 'Switch to rich text editing'}
            >
              <div className={`e2-mode-toggle-option ${editorMode === 'rich' ? 'active' : ''}`}
                   style={{ backgroundColor: editorMode === 'rich' ? '#4060b0' : 'transparent' }}>
                Rich
              </div>
              <div className={`e2-mode-toggle-option ${editorMode === 'html' ? 'active' : ''}`}
                   style={{ backgroundColor: editorMode === 'html' ? '#4060b0' : 'transparent' }}>
                HTML
              </div>
            </div>
          </div>
        </div>

        {/* Editor area */}
        <div style={styles.editorSection}>
          <h2 style={styles.sectionTitle}>Category Description</h2>

          {editorMode === 'rich' && editor && (
            <div style={styles.editorWrapper}>
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper" style={{ padding: '12px' }}>
                <EditorContent editor={editor} />
              </div>
            </div>
          )}

          {editorMode === 'html' && (
            <textarea
              value={htmlContent}
              onChange={handleHtmlChange}
              style={styles.htmlTextarea}
              placeholder="Enter HTML content..."
              spellCheck={false}
            />
          )}
        </div>

        {/* Action buttons - right aligned like writeup editor */}
        <div style={styles.actions}>
          <div style={styles.actionsLeft}>
            {/* Status messages on left */}
          </div>
          <div style={styles.actionsRight}>
            <button onClick={handleCancel} style={styles.cancelButton}>
              <FaTimes size={14} style={{ marginRight: '8px' }} />
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={isSaving}
              style={{
                ...styles.saveButton,
                opacity: isSaving ? 0.7 : 1,
                cursor: isSaving ? 'not-allowed' : 'pointer'
              }}
            >
              <FaSave size={14} style={{ marginRight: '8px' }} />
              {isSaving ? 'Saving...' : 'Save Description'}
            </button>
          </div>
        </div>
      </div>

      {/* Live Preview Section - same layout as writeup editor */}
      <div style={styles.previewSection}>
        <div style={styles.previewHeader}>
          <h4 style={styles.previewTitle}>Preview</h4>
          <button
            onClick={() => setShowPreview(!showPreview)}
            style={styles.previewToggleButton}
          >
            {showPreview ? 'Hide' : 'Show'}
          </button>
        </div>
        {showPreview && (
          <PreviewContent
            editor={editor}
            editorMode={editorMode}
            htmlContent={htmlContent}
            previewTrigger={previewTrigger}
          />
        )}
      </div>

      {/* Help text */}
      <div style={styles.helpText}>
        <p>
          <strong>Tip:</strong> You can use{' '}
          <a className="externalLink" href="/title/E2+Link+Syntax" rel="nofollow" title="/title/E2+Link+Syntax" style={{ fontSize: 'inherit' }}>E2 link syntax</a>{' '}
          like <code>[node title]</code> or <code>[display text|node title]</code> to create links.
        </p>
      </div>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    padding: '20px',
    maxWidth: '900px'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828'
  },
  header: {
    marginBottom: '20px',
    paddingBottom: '15px',
    borderBottom: '2px solid #e0e0e0'
  },
  headerTop: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: '10px'
  },
  titleRow: {
    display: 'flex',
    alignItems: 'center'
  },
  viewButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '6px 12px',
    fontSize: '13px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: 'white',
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: '500',
    cursor: 'pointer'
  },
  title: {
    fontSize: '20px',
    fontWeight: 'bold',
    color: '#38495e',
    margin: 0
  },
  meta: {
    fontSize: '13px',
    color: '#666'
  },
  metaItem: {},
  settingsSection: {
    marginBottom: '24px',
    padding: '16px',
    backgroundColor: '#f9f9f9',
    border: '1px solid #e0e0e0',
    borderRadius: '4px'
  },
  sectionTitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '12px',
    marginTop: 0
  },
  formRow: {
    marginBottom: '12px'
  },
  label: {
    display: 'block',
    marginBottom: '4px',
    fontWeight: '500',
    color: '#555'
  },
  checkboxLabel: {
    display: 'flex',
    alignItems: 'center',
    cursor: 'pointer',
    color: '#555'
  },
  textInput: {
    width: '100%',
    padding: '8px 10px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    boxSizing: 'border-box'
  },
  ownerInputWrapper: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px'
  },
  validationIcon: {
    display: 'flex',
    alignItems: 'center',
    fontSize: '12px'
  },
  settingsActions: {
    display: 'flex',
    justifyContent: 'flex-end',
    alignItems: 'center',
    marginTop: '16px',
    paddingTop: '12px',
    borderTop: '1px solid #e0e0e0'
  },
  saveSettingsButton: {
    padding: '6px 16px',
    fontSize: '13px',
    border: 'none',
    borderRadius: '4px',
    background: '#4060b0',
    color: '#fff',
    fontWeight: '500',
    cursor: 'pointer'
  },
  membersSection: {
    marginBottom: '24px',
    padding: '16px',
    backgroundColor: '#fff',
    border: '1px solid #e0e0e0',
    borderRadius: '4px'
  },
  membersHelp: {
    fontSize: '12px',
    color: '#666',
    marginBottom: '12px',
    marginTop: 0
  },
  memberActions: {
    display: 'flex',
    justifyContent: 'flex-end',
    alignItems: 'center',
    marginTop: '12px'
  },
  editorSectionWrapper: {
    border: '1px solid #e0e0e0',
    borderRadius: '4px',
    padding: '16px',
    marginBottom: '20px'
  },
  toolbar: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '15px'
  },
  toolbarLeft: {
    display: 'flex',
    gap: '10px',
    alignItems: 'center'
  },
  toolbarRight: {
    display: 'flex',
    alignItems: 'center',
    gap: '15px'
  },
  unsavedIndicator: {
    fontSize: '12px',
    color: '#f59e0b',
    fontStyle: 'italic'
  },
  saveStatus: {
    fontSize: '12px',
    fontWeight: '500'
  },
  editorSection: {
    marginBottom: '20px'
  },
  editorWrapper: {
    border: '1px solid #ccc',
    borderRadius: '4px',
    overflow: 'hidden',
    backgroundColor: '#fff'
  },
  htmlTextarea: {
    width: '100%',
    minHeight: '200px',
    fontFamily: 'monospace',
    fontSize: '13px',
    padding: '12px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: '#fff',
    color: '#333',
    lineHeight: '1.5',
    resize: 'vertical',
    boxSizing: 'border-box'
  },
  actions: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: '20px',
    paddingTop: '15px',
    borderTop: '1px solid #e0e0e0'
  },
  actionsLeft: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px'
  },
  actionsRight: {
    display: 'flex',
    gap: '10px'
  },
  saveButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '6px 16px',
    fontSize: '13px',
    border: 'none',
    borderRadius: '4px',
    background: '#4060b0',
    color: '#fff',
    fontWeight: '500'
  },
  cancelButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '6px 16px',
    fontSize: '13px',
    border: '1px solid #666',
    borderRadius: '4px',
    background: '#fff',
    color: '#666',
    fontWeight: '500',
    cursor: 'pointer'
  },
  previewSection: {
    marginTop: '16px',
    borderTop: '1px solid #ddd',
    paddingTop: '12px'
  },
  previewHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '8px'
  },
  previewTitle: {
    margin: 0,
    fontSize: '14px',
    color: '#666',
    fontWeight: '500'
  },
  previewToggleButton: {
    background: 'none',
    border: '1px solid #ccc',
    borderRadius: '4px',
    padding: '2px 8px',
    fontSize: '11px',
    color: '#666',
    cursor: 'pointer'
  },
  helpText: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#e3f2fd',
    border: '1px solid #90caf9',
    borderRadius: '4px',
    fontSize: '12px',
    color: '#1565c0'
  }
}

export default CategoryEdit

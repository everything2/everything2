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

  // Only transform/transition need inline styles (dynamic values from drag state)
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.7 : 1,
  }

  // e2nodes are always owned by Content Editors, so skip showing author for them
  const showAuthor = member.type !== 'e2node'

  const itemClass = isDragging
    ? 'category-edit__member-item category-edit__member-item--dragging'
    : 'category-edit__member-item'

  return (
    <div ref={setNodeRef} style={style} className={itemClass} {...attributes} {...listeners}>
      <div className="category-edit__member-content">
        <span className="category-edit__member-handle">
          <FaGripVertical size={14} />
        </span>
        <LinkNode nodeId={member.node_id} title={member.title} type={member.type} />
        {showAuthor && (
          <span className="category-edit__member-author">
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
        className="category-edit__member-remove"
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
      <div className="category-edit">
        <div className="category-edit__error">Category not found.</div>
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

  // Get input validation class
  const getOwnerInputClass = () => {
    let cls = 'category-edit__text-input'
    if (ownerValidation.valid === true) cls += ' category-edit__text-input--valid'
    else if (ownerValidation.valid === false) cls += ' category-edit__text-input--invalid'
    return cls
  }

  return (
    <div className="category-edit">
      {/* Header */}
      <div className="category-edit__header">
        <div className="category-edit__header-top">
          <div className="category-edit__title-row">
            <FaFolder size={20} className="category-edit__title-icon" />
            <h1 className="category-edit__title">Editing: {title}</h1>
          </div>
          <a
            href={`/node/${node_id}`}
            className="category-edit__view-btn"
            title="View category"
          >
            <FaEye size={14} style={{ marginRight: '6px' }} />
            View
          </a>
        </div>
        <div className="category-edit__meta">
          <span>
            {is_public ? 'Public category' : `Maintained by ${author}`}
          </span>
        </div>
      </div>

      {/* Category Settings Section (editors+ only) */}
      {can_edit_meta && (
        <div className="category-edit__settings">
          <h2 className="category-edit__section-title">Category Settings</h2>

          <div className="category-edit__form-row">
            <label className="category-edit__label">Title:</label>
            <input
              type="text"
              value={categoryTitle}
              onChange={handleTitleChange}
              className="category-edit__text-input"
            />
          </div>

          <div className="category-edit__form-row">
            <label className="category-edit__checkbox-label">
              <input
                type="checkbox"
                checked={isPublic}
                onChange={handlePublicToggle}
              />
              Public category (anyone can edit)
            </label>
          </div>

          {!isPublic && (
            <div className="category-edit__form-row">
              <label className="category-edit__label">Owner:</label>
              <div className="category-edit__owner-wrapper">
                <input
                  type="text"
                  value={ownerName}
                  onChange={handleOwnerChange}
                  placeholder="Enter username or usergroup"
                  className={getOwnerInputClass()}
                  style={{ flex: 1 }}
                />
                {ownerValidation.checking && (
                  <span className="category-edit__validation-icon">
                    <FaSpinner className="fa-spin" size={14} />
                  </span>
                )}
                {ownerValidation.valid === true && !ownerValidation.checking && (
                  <span className="category-edit__validation-icon category-edit__validation-icon--success">
                    <FaCheck size={14} />
                    <span className="category-edit__validation-type">
                      ({ownerValidation.type})
                    </span>
                  </span>
                )}
                {ownerValidation.valid === false && !ownerValidation.checking && ownerName && (
                  <span className="category-edit__validation-icon category-edit__validation-icon--error">
                    Not found
                  </span>
                )}
              </div>
            </div>
          )}

          <div className="category-edit__settings-actions">
            {metaSaveStatus && (
              <span className={`category-edit__status category-edit__status--${metaSaveStatus.type}`}>
                {metaSaveStatus.message}
              </span>
            )}
            <button
              onClick={handleSaveMeta}
              disabled={!hasMetaChanges || isMetaSaving || (!isPublic && !ownerValidation.valid)}
              className="category-edit__save-settings-btn"
            >
              {isMetaSaving ? 'Saving...' : 'Save Settings'}
            </button>
          </div>
        </div>
      )}

      {/* Member Management Section */}
      {can_manage_members && members.length > 0 ? (
        <div className="category-edit__members">
          <h2 className="category-edit__section-title">
            Manage Members ({members.length})
          </h2>
          <p className="category-edit__members-help">
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

          <div className="category-edit__member-actions">
            {memberSaveStatus && (
              <span className={`category-edit__status category-edit__status--${memberSaveStatus.type}`}>
                {memberSaveStatus.message}
              </span>
            )}
            {hasMemberChanges && (
              <button
                onClick={handleSaveMemberOrder}
                disabled={isMemberSaving}
                className="category-edit__save-settings-btn"
              >
                {isMemberSaving ? 'Saving...' : 'Save Order'}
              </button>
            )}
          </div>
        </div>
      ) : null}

      {/* Description Editor Section */}
      <div className="category-edit__editor-wrapper">
        {/* Toolbar with mode toggle */}
        <div className="category-edit__toolbar">
          <div className="category-edit__toolbar-left">
            {hasChanges && (
              <span className="category-edit__unsaved">Unsaved changes</span>
            )}
            {saveStatus && (
              <span className={`category-edit__save-status category-edit__save-status--${saveStatus.type}`}>
                {saveStatus.message}
              </span>
            )}
          </div>
          <div className="category-edit__toolbar-right">
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
        <div className="category-edit__editor-section">
          <h2 className="category-edit__section-title">Category Description</h2>

          {editorMode === 'rich' && editor && (
            <div className="category-edit__editor-container">
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
              className="category-edit__html-textarea"
              placeholder="Enter HTML content..."
              spellCheck={false}
            />
          )}
        </div>

        {/* Action buttons - right aligned like writeup editor */}
        <div className="category-edit__actions">
          <div className="category-edit__actions-left">
            {/* Status messages on left */}
          </div>
          <div className="category-edit__actions-right">
            <button onClick={handleCancel} className="category-edit__cancel-btn">
              <FaTimes size={14} style={{ marginRight: '8px' }} />
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={isSaving}
              className="category-edit__save-btn"
            >
              <FaSave size={14} style={{ marginRight: '8px' }} />
              {isSaving ? 'Saving...' : 'Save Description'}
            </button>
          </div>
        </div>
      </div>

      {/* Live Preview Section - same layout as writeup editor */}
      <div className="category-edit__preview">
        <div className="category-edit__preview-header">
          <h4 className="category-edit__preview-title">Preview</h4>
          <button
            onClick={() => setShowPreview(!showPreview)}
            className="category-edit__preview-toggle"
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
      <div className="category-edit__help">
        <p>
          <strong>Tip:</strong> You can use{' '}
          <a className="externalLink" href="/title/E2+Link+Syntax" rel="nofollow" title="/title/E2+Link+Syntax" style={{ fontSize: 'inherit' }}>E2 link syntax</a>{' '}
          like <code>[node title]</code> or <code>[display text|node title]</code> to create links.
        </p>
      </div>
    </div>
  )
}

export default CategoryEdit

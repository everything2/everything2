import React, { useState, useCallback, useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import LinkNode from '../LinkNode'
import { FaComments, FaReply, FaSave, FaTimes, FaUsers, FaExclamationTriangle, FaSpinner } from 'react-icons/fa'
import '../Editor/E2Editor.css'

/**
 * DebatecommentEdit - Edit/Reply form for usergroup discussions
 *
 * Used for both:
 * - edit: Editing an existing comment (author or admin)
 * - replyto: Creating a reply to a comment
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

const DebatecommentEdit = ({ data }) => {
  const isReply = data.mode === 'replyto'
  const parent = isReply ? data.parent : null
  const comment = data.debatecomment

  // Form state
  const [title, setTitle] = useState(
    isReply
      ? (comment.title.startsWith('re: ') ? comment.title : `re: ${comment.title}`)
      : comment.title
  )
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(isReply ? '' : (comment.doctext || ''))

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: breakTags(isReply ? '' : (comment.doctext || '')),
    editorProps: {
      attributes: {
        class: 'e2-editor-content'
      }
    }
  })

  // Set initial HTML content for HTML mode
  useEffect(() => {
    setHtmlContent(isReply ? '' : (comment.doctext || ''))
  }, [comment.doctext, isReply])

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
    setError(null)
  }, [])

  // Permission denied view
  if (data.permission_denied) {
    return (
      <div className="dc-edit">
        <div className="dc-edit__permission-denied">
          <FaExclamationTriangle className="dc-edit__permission-denied-icon" />
          <h3>Permission Denied</h3>
          <p>You do not have permission to {isReply ? 'reply to' : 'edit'} this discussion.</p>
        </div>
      </div>
    )
  }

  const handleSave = async () => {
    if (!title.trim()) {
      setError('Title is required')
      return
    }

    // Don't save if editor isn't ready in rich mode
    if (editorMode === 'rich' && !editor) {
      setError('Editor is still loading, please wait...')
      return
    }

    setSaving(true)
    setError(null)
    setSuccess(null)

    const doctext = getCurrentDoctext()

    try {
      const endpoint = isReply
        ? `/api/debatecomments/${comment.node_id}/action/reply`
        : `/api/debatecomments/${comment.node_id}/action/save`

      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: title.trim(),
          doctext: doctext
        })
      })

      const result = await response.json()

      if (result.success) {
        setSuccess(isReply ? 'Reply created!' : 'Comment saved!')

        // Redirect after a short delay
        setTimeout(() => {
          if (isReply && result.node_id) {
            // Redirect to the root thread
            window.location.href = `/?node_id=${data.root.node_id}`
          } else {
            // Redirect back to the comment
            window.location.href = `/?node_id=${comment.node_id}`
          }
        }, 1000)
      } else {
        setError(result.error || 'Failed to save')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleCancel = () => {
    window.location.href = `/?node_id=${comment.node_id}`
  }

  return (
    <div className="dc-edit">
      {/* Header */}
      <div className="dc-edit__header">
        {isReply ? (
          <FaReply className="dc-edit__header-icon dc-edit__header-icon--reply" />
        ) : (
          <FaComments className="dc-edit__header-icon dc-edit__header-icon--edit" />
        )}
        <div className="dc-edit__header-info">
          <h1 className="dc-edit__title">
            {isReply ? 'Reply to Discussion' : 'Edit Comment'}
          </h1>
          {data.usergroup && (
            <span className="dc-edit__usergroup-badge">
              <FaUsers className="dc-edit__usergroup-badge-icon" />
              <LinkNode {...data.usergroup} type="usergroup" />
            </span>
          )}
        </div>
      </div>

      {/* Parent comment preview (for replies) */}
      {isReply && parent && (
        <div className="dc-edit__parent-preview">
          <div className="dc-edit__parent-label">Replying to:</div>
          <div className="dc-edit__parent-title">
            <a href={`/?node_id=${parent.node_id}`}>{parent.title}</a>
            {parent.author && (
              <span className="dc-edit__parent-author">
                {' '}by <LinkNode {...parent.author} type="user" />
              </span>
            )}
          </div>
          {parent.doctext && (
            <div
              className="dc-edit__parent-content"
              dangerouslySetInnerHTML={{ __html: parent.doctext }}
            />
          )}
        </div>
      )}

      {/* Messages */}
      {error && (
        <div className="dc-edit__error-message">
          <FaExclamationTriangle className="dc-edit__error-icon" />
          {error}
        </div>
      )}
      {success && (
        <div className="dc-edit__success-message">
          {success}
        </div>
      )}

      {/* Form */}
      <div className="dc-edit__form">
        {/* Title field */}
        <div className="dc-edit__form-group">
          <label className="dc-edit__label">Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="dc-edit__input"
            placeholder="Enter title..."
            disabled={saving}
          />
        </div>

        {/* Content editor with Rich/HTML toggle */}
        <div className="dc-edit__form-group">
          <div className="dc-edit__editor-header">
            <label className="dc-edit__label">Content</label>
            <EditorModeToggle
              mode={editorMode}
              onToggle={handleModeToggle}
              disabled={saving}
            />
          </div>

          {editorMode === 'rich' ? (
            <div className="dc-edit__editor-container">
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper dc-edit__editor-wrapper">
                <EditorContent editor={editor} />
              </div>
            </div>
          ) : (
            <textarea
              value={htmlContent}
              onChange={handleHtmlChange}
              placeholder="Enter HTML content here..."
              aria-label="Content (HTML)"
              className="dc-edit__html-textarea"
              spellCheck={false}
              disabled={saving}
            />
          )}
        </div>

        {/* Action buttons */}
        <div className="dc-edit__actions">
          <button
            onClick={handleSave}
            disabled={saving}
            className="dc-edit__save-btn"
          >
            {saving ? <FaSpinner className="fa-spin dc-edit__save-btn-icon" /> : <FaSave className="dc-edit__save-btn-icon" />}
            {saving ? 'Saving...' : (isReply ? 'Post Reply' : 'Save Changes')}
          </button>
          <button
            onClick={handleCancel}
            disabled={saving}
            className="dc-edit__cancel-btn"
          >
            <FaTimes className="dc-edit__cancel-btn-icon" />
            Cancel
          </button>
        </div>
      </div>

      {/* Thread navigation */}
      {data.root && (
        <div className="dc-edit__thread-nav">
          <a href={`/?node_id=${data.root.node_id}`}>
            &larr; Back to: {data.root.title}
          </a>
        </div>
      )}
    </div>
  )
}

export default DebatecommentEdit

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
      <div style={styles.container}>
        <div style={styles.permissionDenied}>
          <FaExclamationTriangle style={{ fontSize: 48, color: '#dc3545', marginBottom: 16 }} />
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
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        {isReply ? (
          <FaReply style={{ color: '#4060b0', marginRight: 8, fontSize: 24 }} />
        ) : (
          <FaComments style={{ color: '#507898', marginRight: 8, fontSize: 24 }} />
        )}
        <div style={styles.headerInfo}>
          <h1 style={styles.title}>
            {isReply ? 'Reply to Discussion' : 'Edit Comment'}
          </h1>
          {data.usergroup && (
            <span style={styles.usergroupBadge}>
              <FaUsers style={{ marginRight: 4 }} />
              <LinkNode {...data.usergroup} type="usergroup" />
            </span>
          )}
        </div>
      </div>

      {/* Parent comment preview (for replies) */}
      {isReply && parent && (
        <div style={styles.parentPreview}>
          <div style={styles.parentLabel}>Replying to:</div>
          <div style={styles.parentTitle}>
            <a href={`/?node_id=${parent.node_id}`}>{parent.title}</a>
            {parent.author && (
              <span style={styles.parentAuthor}>
                {' '}by <LinkNode {...parent.author} type="user" />
              </span>
            )}
          </div>
          {parent.doctext && (
            <div
              style={styles.parentContent}
              dangerouslySetInnerHTML={{ __html: parent.doctext }}
            />
          )}
        </div>
      )}

      {/* Messages */}
      {error && (
        <div style={styles.errorMessage}>
          <FaExclamationTriangle style={{ marginRight: 8 }} />
          {error}
        </div>
      )}
      {success && (
        <div style={styles.successMessage}>
          {success}
        </div>
      )}

      {/* Form */}
      <div style={styles.form}>
        {/* Title field */}
        <div style={styles.formGroup}>
          <label style={styles.label}>Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            style={styles.input}
            placeholder="Enter title..."
            disabled={saving}
          />
        </div>

        {/* Content editor with Rich/HTML toggle */}
        <div style={styles.formGroup}>
          <div style={styles.editorHeader}>
            <label style={styles.label}>Content</label>
            <EditorModeToggle
              mode={editorMode}
              onToggle={handleModeToggle}
              disabled={saving}
            />
          </div>

          {editorMode === 'rich' ? (
            <div style={styles.editorContainer}>
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper" style={{ padding: '12px', minHeight: 200 }}>
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
              disabled={saving}
            />
          )}
        </div>

        {/* Action buttons */}
        <div style={styles.actions}>
          <button
            onClick={handleSave}
            disabled={saving}
            style={{
              ...styles.saveButton,
              opacity: saving ? 0.6 : 1,
              cursor: saving ? 'not-allowed' : 'pointer'
            }}
          >
            {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
            <span style={{ marginLeft: 6 }}>{saving ? 'Saving...' : (isReply ? 'Post Reply' : 'Save Changes')}</span>
          </button>
          <button
            onClick={handleCancel}
            disabled={saving}
            style={styles.cancelButton}
          >
            <FaTimes style={{ marginRight: 6 }} />
            Cancel
          </button>
        </div>
      </div>

      {/* Thread navigation */}
      {data.root && (
        <div style={styles.threadNav}>
          <a href={`/?node_id=${data.root.node_id}`}>
            &larr; Back to: {data.root.title}
          </a>
        </div>
      )}
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
    marginBottom: 16,
    paddingBottom: 16,
    borderBottom: '2px solid #38495e',
    flexWrap: 'wrap',
    gap: 8
  },
  headerInfo: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    minWidth: 200,
    flexWrap: 'wrap'
  },
  title: {
    margin: 0,
    fontSize: 24,
    fontWeight: 'bold',
    color: '#38495e'
  },
  usergroupBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    fontSize: 12,
    color: '#4060b0',
    backgroundColor: '#e8f4f8',
    padding: '2px 8px',
    borderRadius: 4
  },
  parentPreview: {
    backgroundColor: '#f8f9fa',
    border: '1px solid #e8f4f8',
    borderRadius: 4,
    padding: 16,
    marginBottom: 20
  },
  parentLabel: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#507898',
    marginBottom: 8
  },
  parentTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 8
  },
  parentAuthor: {
    fontWeight: 'normal',
    fontSize: 14,
    color: '#507898'
  },
  parentContent: {
    fontSize: 14,
    color: '#38495e',
    lineHeight: 1.5,
    maxHeight: 150,
    overflow: 'auto',
    paddingTop: 8,
    borderTop: '1px solid #e8f4f8'
  },
  form: {
    marginBottom: 20
  },
  formGroup: {
    marginBottom: 16
  },
  editorHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8
  },
  label: {
    display: 'block',
    marginBottom: 6,
    fontWeight: 'bold',
    color: '#38495e',
    fontSize: 14
  },
  input: {
    width: '100%',
    padding: '10px 12px',
    border: '1px solid #38495e',
    borderRadius: 4,
    fontSize: 14,
    boxSizing: 'border-box',
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
    minHeight: 200,
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
  actions: {
    display: 'flex',
    gap: 12,
    marginTop: 20
  },
  saveButton: {
    display: 'flex',
    alignItems: 'center',
    padding: '10px 20px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: 4,
    fontSize: 14,
    fontWeight: 'bold',
    cursor: 'pointer'
  },
  cancelButton: {
    display: 'flex',
    alignItems: 'center',
    padding: '10px 20px',
    backgroundColor: '#507898',
    color: 'white',
    border: 'none',
    borderRadius: 4,
    fontSize: 14,
    cursor: 'pointer'
  },
  errorMessage: {
    display: 'flex',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#f8d7da',
    border: '1px solid #f5c6cb',
    borderRadius: 4,
    color: '#721c24',
    marginBottom: 16
  },
  successMessage: {
    padding: 12,
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: 4,
    color: '#155724',
    marginBottom: 16
  },
  threadNav: {
    marginTop: 20,
    paddingTop: 16,
    borderTop: '1px solid #e8f4f8',
    fontSize: 14
  },
  permissionDenied: {
    padding: 40,
    textAlign: 'center',
    color: '#507898',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  }
}

export default DebatecommentEdit

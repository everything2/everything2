import React, { useState, useCallback, useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { FaEdit, FaRss } from 'react-icons/fa'
import { renderE2Content, breakTags } from '../Editor/E2HtmlSanitizer'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import PreviewContent from '../Editor/PreviewContent'
import LinkNode from '../LinkNode'
import '../Editor/E2Editor.css'

/**
 * Document Component - Display and edit documents
 *
 * Renders document nodes (nodetype 3) with:
 * - Display mode: Shows sanitized HTML content with E2 link parsing
 * - Edit mode: Tiptap WYSIWYG editor for editing content
 *
 * Data comes from Everything::Page::document
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

const Document = ({ data }) => {
  const { document, can_edit, displaytype: initialDisplaytype, user } = data

  const [isEditing, setIsEditing] = useState(initialDisplaytype === 'edit')
  const [currentDoctext, setCurrentDoctext] = useState(document?.doctext || '')
  const [saveStatus, setSaveStatus] = useState('saved') // 'saved', 'saving', 'error'
  const [errorMessage, setErrorMessage] = useState(null)
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(document?.doctext || '')
  const [showWeblogModal, setShowWeblogModal] = useState(false)

  if (!document) {
    return <div className="error">Document not found</div>
  }

  // Get sanitized HTML for display
  const getSanitizedHtml = (text) => {
    if (!text) return ''
    const { html } = renderE2Content(text)
    return html
  }

  // Handle entering edit mode
  const handleEdit = () => {
    setHtmlContent(currentDoctext)
    setIsEditing(true)
  }

  // Handle cancel editing
  const handleCancel = () => {
    setIsEditing(false)
    setErrorMessage(null)
  }

  // Handle save
  const handleSave = async () => {
    setSaveStatus('saving')
    setErrorMessage(null)

    // Get content from editor
    let contentToSave = htmlContent
    if (editorMode === 'rich' && editorRef.current) {
      contentToSave = convertToE2Syntax(editorRef.current.getHTML())
      contentToSave = convertRawBracketsToEntities(contentToSave)
    }

    try {
      const response = await fetch(`/api/documents/${document.node_id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          doctext: contentToSave,
        }),
      })

      const result = await response.json()

      if (result.success) {
        setCurrentDoctext(contentToSave)
        setSaveStatus('saved')
        setIsEditing(false)
      } else {
        setSaveStatus('error')
        setErrorMessage(result.error || 'Failed to save document')
      }
    } catch (err) {
      setSaveStatus('error')
      setErrorMessage(err.message || 'Failed to save document')
    }
  }

  // Editor reference for getting content
  const editorRef = React.useRef(null)

  // Display mode
  if (!isEditing) {
    return (
      <div className="document-page">
        {/* Action icons for those who can edit or logged-in users */}
        {(Boolean(can_edit) || (user && !user.is_guest)) && (
          <div style={styles.actionBar}>
            {/* Weblog button - show for logged-in users */}
            {user && !user.is_guest && (
              <button
                onClick={() => setShowWeblogModal(true)}
                title="Add to weblog"
                style={styles.iconButton}
              >
                <FaRss />
              </button>
            )}
            {/* Edit button for those who can edit */}
            {Boolean(can_edit) && (
              <button
                onClick={handleEdit}
                title="Edit this document"
                style={styles.iconButton}
              >
                <FaEdit />
              </button>
            )}
          </div>
        )}

        {/* Document content */}
        <div
          className="content"
          dangerouslySetInnerHTML={{ __html: getSanitizedHtml(currentDoctext) }}
        />

        {/* Document metadata */}
        {document.author && (
          <div style={{ marginTop: '20px', fontSize: '0.9em', color: '#666', borderTop: '1px solid #eee', paddingTop: '10px' }}>
            Maintained by: <LinkNode nodeId={document.author.node_id} title={document.author.title} type="user" />
          </div>
        )}

        {/* Weblog Modal */}
        {showWeblogModal && (
          <WeblogModal
            nodeId={document.node_id}
            nodeTitle={document.title}
            onClose={() => setShowWeblogModal(false)}
          />
        )}
      </div>
    )
  }

  // Edit mode
  return (
    <DocumentEditor
      document={document}
      initialContent={htmlContent}
      editorMode={editorMode}
      setEditorMode={setEditorMode}
      onSave={handleSave}
      onCancel={handleCancel}
      saveStatus={saveStatus}
      errorMessage={errorMessage}
      editorRef={editorRef}
      htmlContent={htmlContent}
      setHtmlContent={setHtmlContent}
    />
  )
}

/**
 * WeblogModal - Standalone dialog for adding document to weblog
 */
const WeblogModal = ({ nodeId, nodeTitle, onClose }) => {
  const [availableGroups, setAvailableGroups] = useState([])
  const [isLoading, setIsLoading] = useState(true)
  const [selectedGroup, setSelectedGroup] = useState('')
  const [isPosting, setIsPosting] = useState(false)
  const [actionStatus, setActionStatus] = useState(null)

  // Fetch available groups on mount
  useEffect(() => {
    const fetchGroups = async () => {
      try {
        const response = await fetch('/api/weblog/available', {
          credentials: 'include'
        })
        const data = await response.json()
        if (data.success && data.groups) {
          setAvailableGroups(data.groups)
        }
      } catch (error) {
        console.error('Failed to fetch available groups:', error)
        setActionStatus({ type: 'error', message: 'Failed to load usergroups' })
      } finally {
        setIsLoading(false)
      }
    }

    fetchGroups()
  }, [])

  // Close on backdrop click
  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  // Handle post to usergroup
  const handlePostToGroup = async () => {
    if (!selectedGroup) {
      setActionStatus({ type: 'error', message: 'Please select a usergroup' })
      return
    }

    setIsPosting(true)

    try {
      const groupName = availableGroups.find(g => String(g.node_id) === String(selectedGroup))?.title || 'usergroup'

      const response = await fetch(`/api/weblog/${selectedGroup}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ to_node: nodeId })
      })
      const data = await response.json()

      if (data.success) {
        setActionStatus({ type: 'success', message: `Posted to ${groupName}` })
        setSelectedGroup('')
        // Close modal after brief delay to show success message
        setTimeout(() => onClose(), 1500)
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Failed to post' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    } finally {
      setIsPosting(false)
    }
  }

  return (
    <div onClick={handleBackdropClick} style={modalStyles.backdrop}>
      <div style={modalStyles.modal}>
        <div style={modalStyles.header}>
          <h3 style={modalStyles.title}>Add to Weblog</h3>
          <button onClick={onClose} style={modalStyles.closeButton}>&times;</button>
        </div>

        <div style={modalStyles.content}>
          {/* Status message */}
          {actionStatus && (
            <div style={{
              ...modalStyles.status,
              backgroundColor: actionStatus.type === 'error' ? '#fee' : '#efe',
              color: actionStatus.type === 'error' ? '#c00' : '#060'
            }}>
              {actionStatus.message}
            </div>
          )}

          {/* Document info */}
          <div style={modalStyles.info}>
            <strong>{nodeTitle}</strong>
          </div>

          {isLoading ? (
            <p style={modalStyles.helpText}>Loading available groups...</p>
          ) : availableGroups.length === 0 ? (
            <p style={modalStyles.helpText}>
              You don't have permission to post to any usergroup weblogs.
            </p>
          ) : (
            <>
              <select
                value={selectedGroup}
                onChange={(e) => setSelectedGroup(e.target.value)}
                style={modalStyles.input}
                disabled={isPosting}
              >
                <option value="">Select a usergroup...</option>
                {availableGroups.map((group) => (
                  <option key={group.node_id} value={group.node_id}>
                    {group.ify_display
                      ? `${group.ify_display} (${group.title})`
                      : group.title}
                  </option>
                ))}
              </select>

              <button
                onClick={handlePostToGroup}
                disabled={!selectedGroup || isPosting}
                style={{
                  ...modalStyles.actionButton,
                  ...(!selectedGroup || isPosting ? modalStyles.buttonDisabled : {})
                }}
              >
                {isPosting ? 'Posting...' : 'Post to usergroup'}
              </button>

              <p style={modalStyles.helpText}>
                Share this document to a usergroup weblog.
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

/**
 * DocumentEditor - Tiptap-based editor for documents
 */
const DocumentEditor = ({
  document,
  initialContent,
  editorMode,
  setEditorMode,
  onSave,
  onCancel,
  saveStatus,
  errorMessage,
  editorRef,
  htmlContent,
  setHtmlContent,
}) => {
  const [previewTrigger, setPreviewTrigger] = useState(0)

  // Initialize Tiptap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: convertEntitiesToRawBrackets(initialContent),
    onUpdate: ({ editor }) => {
      // Keep htmlContent in sync for HTML mode switching
      const html = convertToE2Syntax(editor.getHTML())
      setHtmlContent(convertRawBracketsToEntities(html))
      // Trigger preview update
      setPreviewTrigger(prev => prev + 1)
    },
  })

  // Store editor reference
  React.useEffect(() => {
    editorRef.current = editor
  }, [editor, editorRef])

  // Handle mode toggle
  const handleModeToggle = () => {
    const newMode = editorMode === 'rich' ? 'html' : 'rich'

    if (newMode === 'html' && editor) {
      // Switching to HTML mode - get content from Tiptap
      const html = convertToE2Syntax(editor.getHTML())
      setHtmlContent(convertRawBracketsToEntities(html))
    } else if (newMode === 'rich' && editor) {
      // Switching to Rich mode - update Tiptap with HTML content
      // First apply breakTags to convert plain-text newlines to proper HTML paragraphs
      const withBreaks = breakTags(htmlContent)
      editor.commands.setContent(convertEntitiesToRawBrackets(withBreaks))
    }

    setEditorMode(newMode)

    // Save preference to localStorage
    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // Ignore localStorage errors
    }

    // Save preference to server
    fetch('/api/preferences/set', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ tiptap_editor_raw: newMode === 'html' ? 1 : 0 })
    }).catch(err => console.error('Failed to save editor mode preference:', err))
  }

  return (
    <div className="document-editor e2-editor" style={editorStyles.container}>
      {/* Header with title and mode toggle */}
      <div style={editorStyles.header}>
        <h3 style={editorStyles.title}>Editing: {document.title}</h3>
        <EditorModeToggle
          mode={editorMode}
          onToggle={handleModeToggle}
          disabled={false}
        />
      </div>

      {/* Error message */}
      {errorMessage && (
        <div style={editorStyles.errorBox}>
          Error: {errorMessage}
        </div>
      )}

      {/* Editor */}
      {editorMode === 'rich' ? (
        <div style={editorStyles.editorContainer}>
          <MenuBar editor={editor} />
          <div className="e2-editor-wrapper" style={{ padding: '12px' }}>
            <EditorContent editor={editor} />
          </div>
        </div>
      ) : (
        <textarea
          value={htmlContent}
          onChange={(e) => {
            setHtmlContent(e.target.value)
            setPreviewTrigger(prev => prev + 1)
          }}
          style={editorStyles.textarea}
          spellCheck={false}
        />
      )}

      {/* Action buttons */}
      <div style={editorStyles.actionRow}>
        <button
          onClick={onCancel}
          disabled={saveStatus === 'saving'}
          style={editorStyles.cancelButton}
        >
          Cancel
        </button>
        <button
          onClick={onSave}
          disabled={saveStatus === 'saving'}
          style={{
            ...editorStyles.saveButton,
            ...(saveStatus === 'saving' ? editorStyles.buttonDisabled : {})
          }}
        >
          {saveStatus === 'saving' ? 'Saving...' : 'Save'}
        </button>
      </div>

      {/* Preview Section */}
      <div style={editorStyles.previewSection}>
        <h4 style={editorStyles.previewTitle}>Preview</h4>
        <PreviewContent
          editor={editor}
          editorMode={editorMode}
          htmlContent={htmlContent}
          previewTrigger={previewTrigger}
        />
      </div>
    </div>
  )
}

// Document page styles
const styles = {
  actionBar: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '8px',
    marginBottom: '8px',
  },
  iconButton: {
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    fontSize: '16px',
    color: '#507898',
    padding: '2px 4px',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
}

// Editor styles
const editorStyles = {
  container: {
    border: '1px solid #ccc',
    borderRadius: '4px',
    padding: '12px',
    backgroundColor: '#f9f9f9',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '12px',
  },
  title: {
    margin: 0,
    fontSize: '16px',
    fontWeight: '600',
    color: '#38495e',
  },
  errorBox: {
    color: '#dc3545',
    marginBottom: '10px',
    padding: '10px',
    backgroundColor: '#f8d7da',
    borderRadius: '4px',
    fontSize: '13px',
  },
  editorContainer: {
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: '#fff',
  },
  textarea: {
    width: '100%',
    minHeight: '300px',
    fontFamily: 'monospace',
    fontSize: '13px',
    padding: '12px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: '#fff',
    color: '#333',
    lineHeight: '1.5',
    resize: 'vertical',
    boxSizing: 'border-box',
  },
  actionRow: {
    marginTop: '12px',
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '8px',
  },
  saveButton: {
    padding: '8px 16px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontWeight: '500',
    fontSize: '13px',
  },
  cancelButton: {
    padding: '8px 16px',
    backgroundColor: '#fff',
    color: '#4060b0',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    cursor: 'pointer',
    fontWeight: '500',
    fontSize: '13px',
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
    cursor: 'not-allowed',
  },
  previewSection: {
    marginTop: '16px',
    borderTop: '1px solid #ddd',
    paddingTop: '12px',
  },
  previewTitle: {
    margin: '0 0 8px 0',
    fontSize: '14px',
    color: '#666',
    fontWeight: '500',
  },
}

// Modal styles - matching AdminModal Kernel Blue theme
const modalStyles = {
  backdrop: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  },
  modal: {
    backgroundColor: '#fff',
    border: '1px solid #38495e',
    maxWidth: '350px',
    width: '90%',
    maxHeight: '80vh',
    overflow: 'auto',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif',
    fontSize: '12px',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '5px 10px',
    backgroundColor: '#38495e',
    color: '#f9fafa',
  },
  title: {
    margin: 0,
    fontSize: '13px',
    fontWeight: 'bold',
  },
  closeButton: {
    background: 'none',
    border: 'none',
    fontSize: '18px',
    cursor: 'pointer',
    color: '#f9fafa',
    padding: '0 4px',
    lineHeight: 1,
  },
  content: {
    padding: '10px',
  },
  status: {
    padding: '5px 8px',
    marginBottom: '10px',
    fontSize: '11px',
    border: '1px solid',
  },
  info: {
    marginBottom: '10px',
    paddingBottom: '10px',
    borderBottom: '1px dotted #333',
  },
  input: {
    width: '100%',
    padding: '4px',
    marginBottom: '6px',
    border: '1px solid #d3d3d3',
    fontSize: '12px',
    boxSizing: 'border-box',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif',
  },
  actionButton: {
    display: 'block',
    width: '100%',
    padding: '4px 8px',
    marginBottom: '4px',
    border: '1px solid #d3d3d3',
    backgroundColor: '#f8f9f9',
    cursor: 'pointer',
    fontSize: '12px',
    textAlign: 'left',
    color: '#4060b0',
    textDecoration: 'none',
  },
  buttonDisabled: {
    backgroundColor: '#f0f0f0',
    color: '#999',
    borderColor: '#ccc',
    cursor: 'not-allowed',
    opacity: 0.6,
  },
  helpText: {
    fontSize: '11px',
    color: '#507898',
    margin: '4px 0 0 0',
  },
}

export default Document

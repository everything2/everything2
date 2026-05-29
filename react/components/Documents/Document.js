import React, { useState, useCallback, useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { FaEdit, FaRss } from 'react-icons/fa'
import { renderE2Content, normalizeEditorHtml } from '../Editor/E2HtmlSanitizer'
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
 * Styles in CSS: .document-page__*, .document-editor__*, .document-modal__*
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
          <div className="document-page__action-bar">
            {/* Weblog button - show for logged-in users */}
            {user && !user.is_guest && (
              <button
                onClick={() => setShowWeblogModal(true)}
                title="Add to weblog"
                className="document-page__icon-button"
              >
                <FaRss />
              </button>
            )}
            {/* Edit button for those who can edit */}
            {Boolean(can_edit) && (
              <button
                onClick={handleEdit}
                title="Edit this document"
                className="document-page__icon-button"
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
          <div className="document-page__metadata">
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
    <div onClick={handleBackdropClick} className="document-modal__backdrop">
      <div className="document-modal">
        <div className="document-modal__header">
          <h3 className="document-modal__title">Add to Weblog</h3>
          <button onClick={onClose} className="document-modal__close-button">&times;</button>
        </div>

        <div className="document-modal__content">
          {/* Status message */}
          {actionStatus && (
            <div className={`document-modal__status document-modal__status--${actionStatus.type}`}>
              {actionStatus.message}
            </div>
          )}

          {/* Document info */}
          <div className="document-modal__info">
            <strong>{nodeTitle}</strong>
          </div>

          {isLoading ? (
            <p className="document-modal__help-text">Loading available groups...</p>
          ) : availableGroups.length === 0 ? (
            <p className="document-modal__help-text">
              You don't have permission to post to any usergroup weblogs.
            </p>
          ) : (
            <>
              <select
                value={selectedGroup}
                onChange={(e) => setSelectedGroup(e.target.value)}
                className="document-modal__input"
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
                className={`document-modal__action-button${(!selectedGroup || isPosting) ? ' document-modal__action-button--disabled' : ''}`}
              >
                {isPosting ? 'Posting...' : 'Post to usergroup'}
              </button>

              <p className="document-modal__help-text">
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
      const withBreaks = normalizeEditorHtml(htmlContent)
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
    <div className="document-editor e2-editor document-editor__container">
      {/* Header with title and mode toggle */}
      <div className="document-editor__header">
        <h3 className="document-editor__title">Editing: {document.title}</h3>
        <EditorModeToggle
          mode={editorMode}
          onToggle={handleModeToggle}
          disabled={false}
        />
      </div>

      {/* Error message */}
      {errorMessage && (
        <div className="document-editor__error-box">
          Error: {errorMessage}
        </div>
      )}

      {/* Editor */}
      {editorMode === 'rich' ? (
        <div className="document-editor__editor-container">
          <MenuBar editor={editor} />
          <div className="e2-editor-wrapper e2-editor-wrapper--padded">
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
          className="document-editor__textarea"
          spellCheck={false}
        />
      )}

      {/* Action buttons */}
      <div className="document-editor__action-row">
        <button
          onClick={onCancel}
          disabled={saveStatus === 'saving'}
          className="document-editor__cancel-button"
        >
          Cancel
        </button>
        <button
          onClick={onSave}
          disabled={saveStatus === 'saving'}
          className={`document-editor__save-button${saveStatus === 'saving' ? ' document-editor__button--disabled' : ''}`}
        >
          {saveStatus === 'saving' ? 'Saving...' : 'Save'}
        </button>
      </div>

      {/* Preview Section */}
      <div className="document-editor__preview-section">
        <h4 className="document-editor__preview-title">Preview</h4>
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

export default Document

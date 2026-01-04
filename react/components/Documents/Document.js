import React, { useState, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { FaEdit } from 'react-icons/fa'
import { renderE2Content, breakTags } from '../Editor/E2HtmlSanitizer'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import MenuBar from '../Editor/MenuBar'
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
  const { document, can_edit, displaytype: initialDisplaytype } = data

  const [isEditing, setIsEditing] = useState(initialDisplaytype === 'edit')
  const [currentDoctext, setCurrentDoctext] = useState(document?.doctext || '')
  const [saveStatus, setSaveStatus] = useState('saved') // 'saved', 'saving', 'error'
  const [errorMessage, setErrorMessage] = useState(null)
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(document?.doctext || '')

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
        {/* Edit button for those who can edit */}
        {Boolean(can_edit) && (
          <div style={{ textAlign: 'right', marginBottom: '8px' }}>
            <button
              onClick={handleEdit}
              title="Edit this document"
              style={{
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                fontSize: '16px',
                color: '#507898',
                padding: '2px 4px',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <FaEdit />
            </button>
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
  // Initialize Tiptap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: convertEntitiesToRawBrackets(initialContent),
    onUpdate: ({ editor }) => {
      // Keep htmlContent in sync for HTML mode switching
      const html = convertToE2Syntax(editor.getHTML())
      setHtmlContent(convertRawBracketsToEntities(html))
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

    // Save preference
    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // Ignore localStorage errors
    }
  }

  return (
    <div className="document-editor e2-editor">
      {/* Error message */}
      {errorMessage && (
        <div style={{ color: '#dc3545', marginBottom: '10px', padding: '10px', backgroundColor: '#f8d7da', borderRadius: '4px' }}>
          Error: {errorMessage}
        </div>
      )}

      {/* Mode toggle */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '8px' }}>
        <button
          onClick={handleModeToggle}
          style={{
            padding: '4px 8px',
            fontSize: '12px',
            cursor: 'pointer',
            backgroundColor: '#f5f5f5',
            border: '1px solid #ddd',
            borderRadius: '3px',
          }}
        >
          {editorMode === 'rich' ? 'Switch to HTML' : 'Switch to Rich Editor'}
        </button>
      </div>

      {/* Editor */}
      {editorMode === 'rich' ? (
        <div className="tiptap-editor-container">
          <MenuBar editor={editor} />
          <EditorContent editor={editor} className="tiptap-editor" />
        </div>
      ) : (
        <textarea
          value={htmlContent}
          onChange={(e) => setHtmlContent(e.target.value)}
          style={{
            width: '100%',
            minHeight: '400px',
            fontFamily: 'monospace',
            fontSize: '14px',
            padding: '10px',
            border: '1px solid #ddd',
            borderRadius: '4px',
          }}
        />
      )}

      {/* Action buttons */}
      <div style={{ marginTop: '15px', display: 'flex', gap: '10px' }}>
        <button
          onClick={onSave}
          disabled={saveStatus === 'saving'}
          style={{
            padding: '8px 16px',
            backgroundColor: '#28a745',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: saveStatus === 'saving' ? 'wait' : 'pointer',
            opacity: saveStatus === 'saving' ? 0.7 : 1,
          }}
        >
          {saveStatus === 'saving' ? 'Saving...' : 'Save'}
        </button>
        <button
          onClick={onCancel}
          disabled={saveStatus === 'saving'}
          style={{
            padding: '8px 16px',
            backgroundColor: '#6c757d',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
          }}
        >
          Cancel
        </button>
      </div>
    </div>
  )
}

export default Document

import React, { useState, useCallback, useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from './Editor/useE2Editor'
import { convertToE2Syntax } from './Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from './Editor/RawBracketExtension'
import { breakTags } from './Editor/E2HtmlSanitizer'
import MenuBar from './Editor/MenuBar'
import EditorModeToggle from './Editor/EditorModeToggle'
import './Editor/E2Editor.css'

/**
 * UsergroupDescriptionEditor - Inline editor for usergroup descriptions
 *
 * Features:
 * - TipTap WYSIWYG editor (Rich mode)
 * - HTML/Rich mode toggle with sticky preference
 * - Save/Cancel buttons (no autosave)
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

const UsergroupDescriptionEditor = ({
  usergroupId,
  initialContent = '',
  onSave,
  onCancel
}) => {
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(initialContent)
  const [saveStatus, setSaveStatus] = useState('idle') // 'idle', 'saving', 'saved', 'error'
  const [errorMessage, setErrorMessage] = useState(null)

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: breakTags(initialContent),
    editorProps: {
      attributes: {
        class: 'e2-editor-content'
      }
    }
  })

  // Set initial HTML content for HTML mode
  useEffect(() => {
    setHtmlContent(initialContent)
  }, [initialContent])

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

  // Get current content
  const getCurrentContent = useCallback(() => {
    if (editorMode === 'html') {
      return htmlContent
    }
    if (editor) {
      const html = editor.getHTML()
      const withEntities = convertRawBracketsToEntities(html)
      return convertToE2Syntax(withEntities)
    }
    return ''
  }, [editor, editorMode, htmlContent])

  // Handle HTML textarea change
  const handleHtmlChange = useCallback((e) => {
    setHtmlContent(e.target.value)
  }, [])

  // Handle save
  const handleSave = async () => {
    setSaveStatus('saving')
    setErrorMessage(null)

    const content = getCurrentContent()

    try {
      const response = await fetch(`/api/usergroups/${usergroupId}/action/description`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ doctext: content })
      })

      const result = await response.json()

      if (result.success) {
        setSaveStatus('saved')
        if (onSave) {
          onSave(content)
        }
      } else {
        setSaveStatus('error')
        setErrorMessage(result.error || 'Failed to save description')
      }
    } catch (error) {
      setSaveStatus('error')
      setErrorMessage('An error occurred: ' + error.message)
    }
  }

  // Handle cancel
  const handleCancel = () => {
    if (onCancel) {
      onCancel()
    }
  }

  return (
    <div className="usergroup-description-editor" style={{
      backgroundColor: '#f8f9fa',
      border: '1px solid #dee2e6',
      borderRadius: '8px',
      padding: '16px',
      marginBottom: '20px'
    }}>
      {/* Header with title and mode toggle */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '12px'
      }}>
        <h4 style={{ margin: 0, fontSize: '14px', fontWeight: '600', color: '#495057' }}>
          Edit Group Description
        </h4>
        <EditorModeToggle
          mode={editorMode}
          onToggle={handleModeToggle}
          disabled={saveStatus === 'saving'}
        />
      </div>

      {/* Error message */}
      {errorMessage && (
        <div style={{
          padding: '8px 12px',
          marginBottom: '12px',
          backgroundColor: '#f8d7da',
          border: '1px solid #f5c6cb',
          borderRadius: '4px',
          color: '#721c24',
          fontSize: '13px'
        }}>
          {errorMessage}
        </div>
      )}

      {/* Editor content */}
      {editorMode === 'rich' ? (
        <div style={{
          border: '1px solid #ced4da',
          borderRadius: '4px',
          backgroundColor: '#fff',
          overflow: 'hidden'
        }}>
          <MenuBar editor={editor} />
          <div className="e2-editor-wrapper" style={{ padding: '12px' }}>
            <EditorContent editor={editor} />
          </div>
        </div>
      ) : (
        <textarea
          value={htmlContent}
          onChange={handleHtmlChange}
          placeholder="Enter HTML content here..."
          aria-label="Description content (HTML)"
          style={{
            width: '100%',
            minHeight: '150px',
            fontFamily: 'monospace',
            fontSize: '13px',
            padding: '12px',
            border: '1px solid #ced4da',
            borderRadius: '4px',
            backgroundColor: '#fff',
            color: '#212529',
            lineHeight: '1.5',
            resize: 'vertical',
            boxSizing: 'border-box'
          }}
          spellCheck={false}
        />
      )}

      {/* Footer with buttons */}
      <div style={{
        display: 'flex',
        justifyContent: 'flex-end',
        alignItems: 'center',
        gap: '10px',
        marginTop: '12px'
      }}>
        {saveStatus === 'saving' && (
          <span style={{ fontSize: '12px', color: '#6c757d' }}>Saving...</span>
        )}
        <button
          onClick={handleCancel}
          disabled={saveStatus === 'saving'}
          style={{
            padding: '8px 16px',
            fontSize: '13px',
            border: '1px solid #6c757d',
            borderRadius: '4px',
            backgroundColor: '#fff',
            color: '#6c757d',
            cursor: saveStatus === 'saving' ? 'not-allowed' : 'pointer',
            opacity: saveStatus === 'saving' ? 0.6 : 1
          }}
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          disabled={saveStatus === 'saving'}
          style={{
            padding: '8px 16px',
            fontSize: '13px',
            border: '1px solid #28a745',
            borderRadius: '4px',
            backgroundColor: '#28a745',
            color: '#fff',
            cursor: saveStatus === 'saving' ? 'not-allowed' : 'pointer',
            opacity: saveStatus === 'saving' ? 0.6 : 1,
            fontWeight: '500'
          }}
        >
          {saveStatus === 'saving' ? 'Saving...' : 'Save Description'}
        </button>
      </div>
    </div>
  )
}

export default UsergroupDescriptionEditor

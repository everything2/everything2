import React, { useState, useCallback, useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from './Editor/useE2Editor'
import { convertToE2Syntax } from './Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from './Editor/RawBracketExtension'
import { normalizeEditorHtml } from './Editor/E2HtmlSanitizer'
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
    content: normalizeEditorHtml(initialContent),
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
        editor.commands.setContent(normalizeEditorHtml(htmlContent))
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
    <div className="usergroup-description-editor">
      {/* Header with title and mode toggle */}
      <div className="usergroup-description-editor__header">
        <h4 className="usergroup-description-editor__title">
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
        <div className="usergroup-description-editor__error">
          {errorMessage}
        </div>
      )}

      {/* Editor content */}
      {editorMode === 'rich' ? (
        <div className="usergroup-description-editor__rich-wrapper">
          <MenuBar editor={editor} />
          <div className="e2-editor-wrapper usergroup-description-editor__rich-content">
            <EditorContent editor={editor} />
          </div>
        </div>
      ) : (
        <textarea
          value={htmlContent}
          onChange={handleHtmlChange}
          placeholder="Enter HTML content here..."
          aria-label="Description content (HTML)"
          className="usergroup-description-editor__textarea"
          spellCheck={false}
        />
      )}

      {/* Footer with buttons */}
      <div className="usergroup-description-editor__footer">
        {saveStatus === 'saving' && (
          <span className="usergroup-description-editor__status">Saving...</span>
        )}
        <button
          onClick={handleCancel}
          disabled={saveStatus === 'saving'}
          className="usergroup-description-editor__cancel-btn"
        >
          Cancel
        </button>
        <button
          onClick={handleSave}
          disabled={saveStatus === 'saving'}
          className="usergroup-description-editor__save-btn"
        >
          {saveStatus === 'saving' ? 'Saving...' : 'Save Description'}
        </button>
      </div>
    </div>
  )
}

export default UsergroupDescriptionEditor

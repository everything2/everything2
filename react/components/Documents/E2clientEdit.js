import React, { useState, useCallback, useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import { FaCode, FaSave, FaSpinner } from 'react-icons/fa'
import '../Editor/E2Editor.css'

/**
 * E2clientEdit - Edit e2client (API client application) information
 *
 * Allows editing:
 * - Title
 * - Version
 * - Home URL
 * - Download URL
 * - Client string (user agent identifier)
 * - Description (doctext) with TipTap rich editor or HTML mode
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

const E2clientEdit = ({ data }) => {
  const { e2client } = data

  const [formData, setFormData] = useState({
    title: e2client.title || '',
    version: e2client.version || '',
    homeurl: e2client.homeurl || '',
    dlurl: e2client.dlurl || '',
    clientstr: e2client.clientstr || ''
  })
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState(e2client.doctext || '')

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: breakTags(e2client.doctext || ''),
    editorProps: {
      attributes: {
        class: 'e2-editor-content'
      }
    }
  })

  // Set initial HTML content for HTML mode
  useEffect(() => {
    setHtmlContent(e2client.doctext || '')
  }, [e2client.doctext])

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }))
    setMessage(null)
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

  // Get current doctext content - called at save time, no memoization needed
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
      const response = await fetch(`/api/e2clients/${e2client.node_id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ ...formData, doctext })
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: 'E2client saved successfully!' })
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to save' })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setSaving(false)
    }
  }

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaCode style={{ color: '#507898', marginRight: 8, fontSize: 20 }} />
        <span style={styles.headerTitle}>Edit E2 Client</span>
        <a href={`/node/${e2client.node_id}`} style={styles.displayLink}>
          display
        </a>
      </div>

      {/* Message */}
      {message && (
        <div style={{
          ...styles.message,
          backgroundColor: message.type === 'error' ? '#fee' : '#efe',
          borderColor: message.type === 'error' ? '#fcc' : '#cec',
          color: message.type === 'error' ? '#c00' : '#060'
        }}>
          {message.text}
        </div>
      )}

      {/* Form */}
      <div style={styles.form}>
        <div style={styles.field}>
          <label style={styles.label}>Client Name:</label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => handleChange('title', e.target.value)}
            style={styles.input}
            maxLength={240}
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Version:</label>
          <input
            type="text"
            value={formData.version}
            onChange={(e) => handleChange('version', e.target.value)}
            style={styles.input}
            maxLength={255}
            placeholder="e.g., 1.0.0"
          />
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Home URL:</label>
          <input
            type="text"
            value={formData.homeurl}
            onChange={(e) => handleChange('homeurl', e.target.value)}
            style={styles.input}
            maxLength={255}
            placeholder="https://..."
          />
          <div style={styles.hint}>
            Project homepage or documentation URL
          </div>
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Download URL:</label>
          <input
            type="text"
            value={formData.dlurl}
            onChange={(e) => handleChange('dlurl', e.target.value)}
            style={styles.input}
            maxLength={255}
            placeholder="https://..."
          />
          <div style={styles.hint}>
            Direct download link for the client
          </div>
        </div>

        <div style={styles.field}>
          <label style={styles.label}>Client String:</label>
          <input
            type="text"
            value={formData.clientstr}
            onChange={(e) => handleChange('clientstr', e.target.value)}
            style={styles.input}
            maxLength={255}
            placeholder="e.g., MyClient/1.0"
          />
          <div style={styles.hint}>
            User agent string or identifier used when connecting to E2 API
          </div>
        </div>

        <div style={styles.field}>
          <div style={styles.descriptionHeader}>
            <label style={styles.label}>Description:</label>
            <EditorModeToggle
              mode={editorMode}
              onToggle={handleModeToggle}
              disabled={saving}
            />
          </div>

          {editorMode === 'rich' ? (
            <div style={styles.editorContainer}>
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
              style={styles.htmlTextarea}
              spellCheck={false}
            />
          )}

          <div style={styles.hint}>
            Describe what your client does, features, requirements, etc.
          </div>
        </div>

        <div style={styles.buttonRow}>
          <button
            onClick={handleSave}
            disabled={saving}
            style={styles.saveButton}
          >
            {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
            <span style={{ marginLeft: 6 }}>{saving ? 'Saving...' : 'Save Changes'}</span>
          </button>
        </div>
      </div>
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
    fontSize: 18,
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: 16,
    paddingBottom: 12,
    borderBottom: '2px solid #38495e'
  },
  headerTitle: {
    flex: 1
  },
  displayLink: {
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  message: {
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
    border: '1px solid'
  },
  form: {
    marginBottom: 24
  },
  field: {
    marginBottom: 16
  },
  label: {
    display: 'block',
    fontWeight: 'bold',
    marginBottom: 4,
    color: '#38495e'
  },
  input: {
    width: '100%',
    padding: '8px 10px',
    fontSize: 14,
    border: '1px solid #ccc',
    borderRadius: 4,
    boxSizing: 'border-box'
  },
  descriptionHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8
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
  hint: {
    marginTop: 4,
    fontSize: 12,
    color: '#666'
  },
  buttonRow: {
    marginTop: 24
  },
  saveButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '10px 20px',
    backgroundColor: '#4060b0',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    cursor: 'pointer',
    fontSize: 14,
    fontWeight: 'bold'
  }
}

export default E2clientEdit

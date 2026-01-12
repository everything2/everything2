import React, { useState, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import PreviewContent from '../Editor/PreviewContent'
import LinkNode from '../LinkNode'
import { useIsMobile } from '../../hooks/useMediaQuery'
import '../Editor/E2Editor.css'

/**
 * Create Category - Form for creating new categories
 *
 * Allows users to create categories maintained by themselves, any noder,
 * or any usergroup they belong to.
 *
 * Uses TipTap editor for the description with Rich/HTML mode toggle.
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

const CreateCategory = ({ data }) => {
  const {
    error,
    mustLogin,
    forbidden,
    user_id,
    user_title,
    usergroups = [],
    category_type_id,
    guest_user_id,
    low_level_warning
  } = data

  const isMobile = useIsMobile()
  const [categoryName, setCategoryName] = useState('')
  const [maintainer, setMaintainer] = useState(user_id || '')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Editor state
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState('')
  const [showPreview, setShowPreview] = useState(true)
  const [previewTrigger, setPreviewTrigger] = useState(0)

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: '',
    editable: true,
    onUpdate: ({ editor }) => {
      const newContent = editor.getHTML()
      if (editorMode === 'rich') {
        setHtmlContent(newContent)
      }
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

  // Handle HTML textarea changes
  const handleHtmlChange = (e) => {
    setHtmlContent(e.target.value)
    setPreviewTrigger(prev => prev + 1)
  }

  // Show error states
  if (mustLogin) {
    return (
      <div style={styles.container}>
        <h3 style={styles.heading}>Create Category</h3>
        <p>
          You must be <LinkNode nodeId={null} title="logged in" url="/login" /> to create a category.
        </p>
      </div>
    )
  }

  if (forbidden) {
    return (
      <div style={styles.container}>
        <h3 style={styles.heading}>Create Category</h3>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  if (error) {
    return (
      <div style={styles.container}>
        <h3 style={styles.heading}>Create Category</h3>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!categoryName.trim()) {
      alert('Please enter a category name.')
      return
    }

    const description = getCurrentContent()
    if (!description.trim() || description === '<p></p>') {
      alert('Please enter a category description.')
      return
    }

    setIsSubmitting(true)

    try {
      // Submit to new category creation (op=new)
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = window.location.pathname

      const fields = {
        node: categoryName,
        maintainer: maintainer,
        category_doctext: description,
        op: 'new',
        type: category_type_id
      }

      Object.entries(fields).forEach(([name, value]) => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = name
        input.value = value
        form.appendChild(input)
      })

      document.body.appendChild(form)
      form.submit()
    } catch (err) {
      console.error('Error creating category:', err)
      alert('Error creating category. Please try again.')
      setIsSubmitting(false)
    }
  }

  // Responsive styles
  const containerStyle = {
    ...styles.container,
    padding: isMobile ? '12px' : '20px'
  }

  const selectStyle = {
    ...styles.select,
    minWidth: isMobile ? 'auto' : '300px',
    width: isMobile ? '100%' : 'auto',
    maxWidth: '100%'
  }

  return (
    <div style={containerStyle}>
      <p style={styles.breadcrumb}>
        <strong>
          <LinkNode nodeId={null} title="Everything2 Help" url="/title/Everything2+Help" />
          {' > '}
          <LinkNode nodeId={null} title="Everything2 Categories" url="/title/Everything2+Categories" />
        </strong>
      </p>

      <p>
        A <LinkNode nodeId={null} title="category" url="/title/category" /> is a way to group
        a list of related nodes. You can create a category that only you can edit, a category
        that anyone can edit, or a category that can be maintained by any{' '}
        <LinkNode nodeId={null} title="usergroup" url="/title/Everything2+Usergroups" /> you
        are a member of.
      </p>

      <p>The scope of categories is limitless. Some examples might include:</p>

      <ul>
        <li>{user_title}'s Favorite Movies</li>
        <li>The Definitive Guide To Star Trek</li>
        <li>Everything2 Memes</li>
        <li>Funny Node Titles</li>
        <li>The Best Books of All Time</li>
        <li>Albums {user_title} Owns</li>
        <li>Writeups About Love</li>
        <li>Angsty Poetry</li>
        <li>Human Diseases</li>
        <li>... the list could go on and on</li>
      </ul>

      <p>
        Before you create your own category you might want to visit the{' '}
        <LinkNode nodeId={null} title="category display page" url="/title/Display+Categories" />{' '}
        to see if you can contribute to an existing category.
      </p>

      {low_level_warning === 1 && (
        <div style={styles.warningBox}>
          Note that until you are at least Level 2, you can only add your own writeups to categories.
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <div style={styles.formGroup}>
          <label style={styles.label}>
            <strong>Category Name:</strong>
          </label>
          <input
            type="text"
            value={categoryName}
            onChange={(e) => setCategoryName(e.target.value)}
            maxLength={255}
            size={50}
            style={styles.textInput}
            disabled={isSubmitting}
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>
            <strong>Maintainer:</strong>
          </label>
          <select
            value={maintainer}
            onChange={(e) => setMaintainer(e.target.value)}
            style={selectStyle}
            disabled={isSubmitting}
          >
            <option value={user_id}>Me ({user_title})</option>
            <option value={guest_user_id}>Any Noder</option>
            {usergroups.map((ug) => (
              <option key={ug.node_id} value={ug.node_id}>
                {ug.title} (usergroup)
              </option>
            ))}
          </select>
        </div>

        <fieldset style={styles.fieldset}>
          <legend style={styles.legend}>Category Description</legend>

          {/* Mode toggle - right aligned */}
          <div style={styles.modeToggleRow}>
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

          {/* Rich text editor */}
          {editorMode === 'rich' && editor && (
            <div style={styles.editorWrapper}>
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper" style={{ padding: '12px', minHeight: '150px' }}>
                <EditorContent editor={editor} />
              </div>
            </div>
          )}

          {/* HTML textarea */}
          {editorMode === 'html' && (
            <textarea
              value={htmlContent}
              onChange={handleHtmlChange}
              style={styles.htmlTextarea}
              placeholder="Enter HTML content..."
              spellCheck={false}
              disabled={isSubmitting}
            />
          )}

          {/* Preview section */}
          <div style={styles.previewSection}>
            <div style={styles.previewHeader}>
              <h4 style={styles.previewTitle}>Preview</h4>
              <button
                type="button"
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
            <strong>Tip:</strong> You can use{' '}
            <a className="externalLink" href="/title/E2+Link+Syntax" rel="nofollow" title="/title/E2+Link+Syntax" style={{ fontSize: 'inherit' }}>E2 link syntax</a>{' '}
            like <code>[node title]</code> or <code>[display text|node title]</code> to create links.
          </div>
        </fieldset>

        <div style={styles.formGroup}>
          <button
            type="submit"
            style={styles.submitButton}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Creating...' : 'Create It!'}
          </button>
        </div>
      </form>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    padding: '20px'
  },
  breadcrumb: {
    marginBottom: '15px',
    fontSize: '14px'
  },
  heading: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '15px'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginBottom: '20px'
  },
  warningBox: {
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    color: '#856404',
    marginBottom: '20px'
  },
  formGroup: {
    marginBottom: '20px'
  },
  label: {
    display: 'block',
    marginBottom: '8px'
  },
  textInput: {
    width: '100%',
    maxWidth: '600px',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontFamily: 'inherit',
    boxSizing: 'border-box'
  },
  select: {
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: 'white',
    minWidth: '300px'
  },
  fieldset: {
    border: '1px solid #38495e',
    borderRadius: '4px',
    padding: '15px',
    marginBottom: '20px'
  },
  legend: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#38495e',
    padding: '0 10px'
  },
  modeToggleRow: {
    display: 'flex',
    justifyContent: 'flex-end',
    marginBottom: '10px'
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
    marginTop: '12px',
    padding: '10px',
    backgroundColor: '#e3f2fd',
    border: '1px solid #90caf9',
    borderRadius: '4px',
    fontSize: '12px',
    color: '#1565c0'
  },
  submitButton: {
    padding: '10px 20px',
    fontSize: '13px',
    fontWeight: 'bold',
    color: 'white',
    backgroundColor: '#4060b0',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer'
  }
}

export default CreateCategory

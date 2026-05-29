import React, { useState, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import EditorModeToggle from '../Editor/EditorModeToggle'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from '../Editor/RawBracketExtension'
import { normalizeEditorHtml } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import PreviewContent from '../Editor/PreviewContent'
import LinkNode from '../LinkNode'
import { useIsMobile } from '../../hooks/useMediaQuery'
import '../Editor/E2Editor.css'

/**
 * Create Category - Form for creating new categories
 * Styles in CSS: .create-category__*
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
      const withBreaks = normalizeEditorHtml(htmlContent)
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
      <div className={`create-category${isMobile ? ' create-category--mobile' : ''}`}>
        <h3 className="create-category__heading">Create Category</h3>
        <p>
          You must be <LinkNode nodeId={null} title="logged in" url="/login" /> to create a category.
        </p>
      </div>
    )
  }

  if (forbidden) {
    return (
      <div className={`create-category${isMobile ? ' create-category--mobile' : ''}`}>
        <h3 className="create-category__heading">Create Category</h3>
        <div className="create-category__error-box">{error}</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className={`create-category${isMobile ? ' create-category--mobile' : ''}`}>
        <h3 className="create-category__heading">Create Category</h3>
        <div className="create-category__error-box">{error}</div>
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

  return (
    <div className={`create-category${isMobile ? ' create-category--mobile' : ''}`}>
      <p className="create-category__breadcrumb">
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
        <div className="create-category__warning-box">
          Note that until you are at least Level 2, you can only add your own writeups to categories.
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <div className="create-category__form-group">
          <label className="create-category__label">
            <strong>Category Name:</strong>
          </label>
          <input
            type="text"
            value={categoryName}
            onChange={(e) => setCategoryName(e.target.value)}
            maxLength={255}
            size={50}
            className="create-category__text-input"
            disabled={isSubmitting}
          />
        </div>

        <div className="create-category__form-group">
          <label className="create-category__label">
            <strong>Maintainer:</strong>
          </label>
          <select
            value={maintainer}
            onChange={(e) => setMaintainer(e.target.value)}
            className={`create-category__select${isMobile ? ' create-category__select--mobile' : ''}`}
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

        <fieldset className="create-category__fieldset">
          <legend className="create-category__legend">Category Description</legend>

          {/* Mode toggle - right aligned */}
          <div className="create-category__mode-toggle-row">
            <EditorModeToggle mode={editorMode} onToggle={handleModeToggle} />
          </div>

          {/* Rich text editor */}
          {editorMode === 'rich' && editor && (
            <div className="create-category__editor-wrapper">
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper create-category__editor-padded">
                <EditorContent editor={editor} />
              </div>
            </div>
          )}

          {/* HTML textarea */}
          {editorMode === 'html' && (
            <textarea
              value={htmlContent}
              onChange={handleHtmlChange}
              className="create-category__html-textarea"
              placeholder="Enter HTML content..."
              spellCheck={false}
              disabled={isSubmitting}
            />
          )}

          {/* Preview section */}
          <div className="create-category__preview-section">
            <div className="create-category__preview-header">
              <h4 className="create-category__preview-title">Preview</h4>
              <button
                type="button"
                onClick={() => setShowPreview(!showPreview)}
                className="create-category__preview-toggle-button"
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
          <div className="create-category__help-text">
            <strong>Tip:</strong> You can use{' '}
            <a className="externalLink create-category__help-link" href="/title/E2+Link+Syntax" rel="nofollow" title="/title/E2+Link+Syntax">E2 link syntax</a>{' '}
            like <code>[node title]</code> or <code>[display text|node title]</code> to create links.
          </div>
        </fieldset>

        <div className="create-category__form-group">
          <button
            type="submit"
            className="create-category__submit-button"
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Creating...' : 'Create It!'}
          </button>
        </div>
      </form>
    </div>
  )
}

export default CreateCategory

import { useState, useCallback } from 'react'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import Subscript from '@tiptap/extension-subscript'
import Superscript from '@tiptap/extension-superscript'
import Table from '@tiptap/extension-table'
import TableRow from '@tiptap/extension-table-row'
import TableCell from '@tiptap/extension-table-cell'
import TableHeader from '@tiptap/extension-table-header'
import { E2Link, convertToE2Syntax } from './E2LinkExtension'
import { E2TextAlign } from './E2TextAlignExtension'
import { RawBracket, convertRawBracketsToEntities } from './RawBracketExtension'

/**
 * Shared TipTap editor configuration for Everything2
 *
 * This module provides:
 * - getE2EditorExtensions(): Standard TipTap extension configuration
 * - useEditorMode(): Hook for managing Rich/HTML mode toggle
 * - getEditorContent(): Utility to get content in E2 syntax format
 */

/**
 * Get the standard E2 TipTap editor extensions
 *
 * @param {Object} options - Configuration options
 * @param {Object} options.starterKit - StarterKit configuration overrides
 * @param {Object} options.table - Table extension configuration overrides
 * @param {Object} options.textAlign - E2TextAlign configuration overrides
 * @returns {Array} Array of configured TipTap extensions
 */
export const getE2EditorExtensions = (options = {}) => {
  const {
    starterKit = {},
    table = { resizable: true },
    textAlign = { types: ['heading', 'paragraph'], alignments: ['left', 'center', 'right'] }
  } = options

  return [
    StarterKit.configure(starterKit),
    Underline,
    Subscript,
    Superscript,
    Table.configure(table),
    TableRow,
    TableCell,
    TableHeader,
    E2Link,
    E2TextAlign.configure(textAlign),
    RawBracket
  ]
}

/**
 * Get the initial editor mode from localStorage
 * @returns {'rich' | 'html'} The initial editor mode
 */
const getInitialEditorMode = () => {
  try {
    const stored = localStorage.getItem('e2_editor_mode')
    if (stored === 'html') return 'html'
  } catch (e) {
    // localStorage may not be available
  }
  return 'rich'
}

/**
 * Hook for managing editor mode (Rich/HTML) with preference persistence
 *
 * @param {Object} options - Configuration options
 * @param {'rich' | 'html'} options.initialMode - Initial mode override (default: from localStorage)
 * @param {boolean} options.persistToServer - Whether to save preference to server API
 * @param {Object} options.editor - TipTap editor instance (needed for mode switching)
 * @returns {Object} Mode state and handlers
 */
export const useEditorMode = ({
  initialMode,
  persistToServer = false,
  editor = null
} = {}) => {
  const [editorMode, setEditorMode] = useState(
    initialMode || getInitialEditorMode
  )
  const [htmlContent, setHtmlContent] = useState('')

  /**
   * Toggle between Rich and HTML modes
   * Handles content conversion between modes
   */
  const toggleMode = useCallback(() => {
    const newMode = editorMode === 'rich' ? 'html' : 'rich'

    if (editor) {
      if (editorMode === 'rich') {
        // Switching to HTML mode - capture current rich content
        const html = editor.getHTML()
        const withEntities = convertRawBracketsToEntities(html)
        setHtmlContent(convertToE2Syntax(withEntities))
      } else {
        // Switching to rich mode - load HTML content into editor
        editor.commands.setContent(htmlContent)
      }
    }

    setEditorMode(newMode)

    // Save to localStorage
    try {
      localStorage.setItem('e2_editor_mode', newMode)
    } catch (e) {
      // localStorage may not be available
    }

    // Optionally persist to server
    if (persistToServer) {
      fetch('/api/preferences/set', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tiptap_editor_raw: newMode === 'html' ? 1 : 0 })
      }).catch(err => console.error('Failed to save editor mode preference:', err))
    }
  }, [editor, editorMode, htmlContent, persistToServer])

  /**
   * Get the current content in E2 syntax format
   * Handles both rich and HTML modes
   */
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

  /**
   * Handle changes to HTML content in HTML mode
   */
  const handleHtmlChange = useCallback((e) => {
    setHtmlContent(e.target.value)
  }, [])

  /**
   * Set HTML content directly (useful for loading initial content)
   */
  const setHtmlContentDirect = useCallback((content) => {
    setHtmlContent(content)
  }, [])

  return {
    editorMode,
    setEditorMode,
    htmlContent,
    setHtmlContent: setHtmlContentDirect,
    handleHtmlChange,
    toggleMode,
    getCurrentContent
  }
}

export default {
  getE2EditorExtensions,
  useEditorMode
}

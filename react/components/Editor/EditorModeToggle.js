import React from 'react'

/**
 * EditorModeToggle - Rich/HTML mode toggle component for E2 editors
 *
 * A pill-style toggle switch for switching between rich text (WYSIWYG)
 * and raw HTML editing modes.
 *
 * Props:
 * - mode: 'rich' | 'html' - Current editing mode
 * - onToggle: () => void - Callback when toggle is clicked
 * - disabled: boolean - Whether the toggle is disabled
 */
const EditorModeToggle = ({ mode, onToggle, disabled = false }) => {
  return (
    <div
      className="e2-mode-toggle"
      onClick={disabled ? undefined : onToggle}
      title={mode === 'rich' ? 'Switch to raw HTML editing' : 'Switch to rich text editing'}
      style={{ opacity: disabled ? 0.5 : 1, cursor: disabled ? 'not-allowed' : 'pointer' }}
    >
      <div className={`e2-mode-toggle-option ${mode === 'rich' ? 'active' : ''}`}>
        Rich
      </div>
      <div className={`e2-mode-toggle-option ${mode === 'html' ? 'active' : ''}`}>
        HTML
      </div>
      <div
        className="e2-mode-toggle-slider"
        style={{
          left: mode === 'rich' ? '3px' : '50%',
          width: 'calc(50% - 3px)'
        }}
      />
    </div>
  )
}

export default EditorModeToggle

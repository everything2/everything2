import React, { useState, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities } from '../Editor/RawBracketExtension'
import { breakTags } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import LinkNode from '../LinkNode'
import { FaComments, FaSpinner, FaBullhorn } from 'react-icons/fa'
import '../Editor/E2Editor.css'

/**
 * UsergroupDiscussions - View and manage usergroup discussions.
 * Allows users to browse and create threaded discussions within their usergroups.
 */
const UsergroupDiscussions = ({ data }) => {
  const {
    is_guest,
    no_usergroups,
    access_denied,
    message,
    usergroups,
    selected_usergroup,
    discussions,
    total_discussions,
    offset,
    limit,
    node_id
  } = data

  if (is_guest) {
    return (
      <div className="ug-discussions">
        <p className="ug-discussions__see-also">
          See also <LinkNode title="usergroup message archive" />
        </p>
        <p>{message}</p>
      </div>
    )
  }

  if (no_usergroups) {
    return (
      <div className="ug-discussions">
        <p className="ug-discussions__see-also">
          See also <LinkNode title="usergroup message archive" />
        </p>
        <p>{message}</p>
      </div>
    )
  }

  if (access_denied) {
    return (
      <div className="ug-discussions">
        <p className="ug-discussions__see-also">
          See also <LinkNode title="usergroup message archive" />
        </p>
        <UsergroupSelector
          usergroups={usergroups}
          selectedUsergroup={selected_usergroup}
          nodeId={node_id}
        />
        <p className="ug-discussions__error">{message}</p>
      </div>
    )
  }

  const hasMore = offset + discussions.length < total_discussions
  const hasPrev = offset > 0

  return (
    <div className="ug-discussions">
      <p className="ug-discussions__see-also">
        See also <LinkNode title="usergroup message archive" />
      </p>

      <UsergroupSelector
        usergroups={usergroups}
        selectedUsergroup={selected_usergroup}
        nodeId={node_id}
      />

      {discussions.length === 0 ? (
        <p className="ug-discussions__no-discussions">There are no discussions!</p>
      ) : (
        <>
          <table className="ug-discussions__table">
            <thead>
              <tr className="ug-discussions__header-row">
                <th className="ug-discussions__th" colSpan="2">title</th>
                <th className="ug-discussions__th">usergroup</th>
                <th className="ug-discussions__th">author</th>
                <th className="ug-discussions__th">replies</th>
                <th className="ug-discussions__th">new</th>
                <th className="ug-discussions__th">last updated</th>
              </tr>
            </thead>
            <tbody>
              {discussions.map((disc) => (
                <tr key={disc.node_id}>
                  <td className="ug-discussions__td">
                    <LinkNode nodeId={disc.node_id} title={disc.title} />
                  </td>
                  <td className="ug-discussions__td--small">
                    (<a
                      href={`?node_id=${disc.node_id}&displaytype=compact`}
                      className="ug-discussions__link"
                    >
                      compact
                    </a>)
                  </td>
                  <td className="ug-discussions__td--small">
                    <LinkNode nodeId={disc.usergroup_id} title={disc.usergroup_title} />
                  </td>
                  <td className="ug-discussions__td">
                    <LinkNode nodeId={disc.author_id} title={disc.author_title} />
                  </td>
                  <td className="ug-discussions__td">{disc.reply_count}</td>
                  <td className="ug-discussions__td">{disc.unread ? '\u00D7' : ''}</td>
                  <td className="ug-discussions__td">{disc.last_updated}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <p className="ug-discussions__total-count">
            There are {total_discussions} discussions total
          </p>

          {(hasPrev || hasMore) && (
            <div className="ug-discussions__pagination">
              {hasPrev && (
                <a
                  href={`?node_id=${node_id}&show_ug=${selected_usergroup}&offset=${offset - limit}`}
                  className="ug-discussions__link"
                >
                  prev {offset - limit + 1} &ndash; {offset}
                </a>
              )}
              {hasPrev && hasMore && ' | '}
              <span>Now: {offset + 1} &ndash; {offset + discussions.length}</span>
              {hasMore && ' | '}
              {hasMore && (
                <a
                  href={`?node_id=${node_id}&show_ug=${selected_usergroup}&offset=${offset + limit}`}
                  className="ug-discussions__link"
                >
                  next {offset + limit + 1} &ndash; {Math.min(offset + 2 * limit, total_discussions)}
                </a>
              )}
            </div>
          )}
        </>
      )}

      <NewDiscussionForm
        usergroups={usergroups}
        selectedUsergroup={selected_usergroup}
      />
    </div>
  )
}

const UsergroupSelector = ({ usergroups, selectedUsergroup, nodeId }) => (
  <div className="ug-discussions__selector">
    <p>Choose the usergroup to filter by:</p>
    <div className="ug-discussions__usergroup-grid">
      {usergroups.map((ug) => (
        <a
          key={ug.node_id}
          href={`?node_id=${nodeId}&show_ug=${ug.node_id}`}
          className={`ug-discussions__usergroup-link${selectedUsergroup === ug.node_id ? ' ug-discussions__usergroup-link--active' : ''}`}
        >
          {ug.title}
        </a>
      ))}
    </div>
    <p className="ug-discussions__show-all">
      Or{' '}
      <a
        href={`?node_id=${nodeId}&show_ug=0`}
        className={`ug-discussions__link${selectedUsergroup === 0 ? ' ug-discussions__link--active' : ''}`}
      >
        show discussions from all usergroups.
      </a>
    </p>
  </div>
)

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

const NewDiscussionForm = ({ usergroups, selectedUsergroup }) => {
  const [title, setTitle] = useState('')
  const [usergroup, setUsergroup] = useState(selectedUsergroup || (usergroups[0]?.node_id || ''))
  const [announce, setAnnounce] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [editorMode, setEditorMode] = useState(getInitialEditorMode)
  const [htmlContent, setHtmlContent] = useState('')

  // Initialize TipTap editor
  const editor = useEditor({
    extensions: getE2EditorExtensions(),
    content: '',
    editorProps: {
      attributes: {
        class: 'e2-editor-content'
      }
    }
  })

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

  // Get current doctext content
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
    setError(null)
  }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!title.trim()) {
      setError('Title is required')
      return
    }

    if (!usergroup) {
      setError('Please select a usergroup')
      return
    }

    // Don't save if editor isn't ready in rich mode
    if (editorMode === 'rich' && !editor) {
      setError('Editor is still loading, please wait...')
      return
    }

    setSaving(true)
    setError(null)
    setSuccess(null)

    const doctext = getCurrentDoctext()

    try {
      const response = await fetch('/api/debatecomments/action/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: title.trim(),
          doctext: doctext,
          restricted: parseInt(usergroup, 10),
          announce: announce
        })
      })

      const result = await response.json()

      if (result.success) {
        setSuccess('Discussion created!')

        // Redirect to the new discussion
        setTimeout(() => {
          window.location.href = `/?node_id=${result.node_id}`
        }, 1000)
      } else {
        setError(result.error || 'Failed to create discussion')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="ug-discussions__new-discussion">
      <hr className="ug-discussions__hr" />

      <div className="ug-discussions__form-header">
        <FaComments className="ug-discussions__form-header-icon" />
        <h3 className="ug-discussions__form-title">Start a New Discussion</h3>
      </div>

      {/* Messages */}
      {error && (
        <div className="ug-discussions__error-message">
          {error}
        </div>
      )}
      {success && (
        <div className="ug-discussions__success-message">
          {success}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        {/* Title */}
        <div className="ug-discussions__form-group">
          <label className="ug-discussions__label">Discussion Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={64}
            className="ug-discussions__title-input"
            placeholder="Enter a title for your discussion..."
            disabled={saving}
          />
        </div>

        {/* Usergroup selection */}
        <div className="ug-discussions__form-group">
          <label className="ug-discussions__label">Usergroup</label>
          <select
            value={usergroup}
            onChange={(e) => setUsergroup(e.target.value)}
            className="ug-discussions__select"
            disabled={saving}
          >
            {usergroups.map((ug) => (
              <option key={ug.node_id} value={ug.node_id}>
                {ug.title}
              </option>
            ))}
          </select>
        </div>

        {/* Announce checkbox */}
        <div className="ug-discussions__form-group">
          <label className="ug-discussions__checkbox-label">
            <input
              type="checkbox"
              checked={announce}
              onChange={(e) => setAnnounce(e.target.checked)}
              disabled={saving}
              className="ug-discussions__checkbox"
            />
            <FaBullhorn className="ug-discussions__announce-icon" />
            Announce new discussion to usergroup
          </label>
        </div>

        {/* Content editor with Rich/HTML toggle */}
        <div className="ug-discussions__form-group">
          <div className="ug-discussions__editor-header">
            <label className="ug-discussions__label">First Post</label>
            <EditorModeToggle
              mode={editorMode}
              onToggle={handleModeToggle}
              disabled={saving}
            />
          </div>

          {editorMode === 'rich' ? (
            <div className="ug-discussions__editor-container">
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper ug-discussions__editor-wrapper">
                <EditorContent editor={editor} />
              </div>
            </div>
          ) : (
            <textarea
              value={htmlContent}
              onChange={handleHtmlChange}
              placeholder="Enter HTML content here..."
              aria-label="Content (HTML)"
              className="ug-discussions__html-textarea"
              spellCheck={false}
              disabled={saving}
            />
          )}
        </div>

        {/* Submit button */}
        <button
          type="submit"
          disabled={saving}
          className="ug-discussions__submit-btn"
        >
          {saving ? (
            <>
              <FaSpinner className="fa-spin ug-discussions__submit-btn-icon" />
              Creating...
            </>
          ) : (
            <>
              <FaComments className="ug-discussions__submit-btn-icon" />
              Start New Discussion
            </>
          )}
        </button>
      </form>
    </div>
  )
}

export default UsergroupDiscussions

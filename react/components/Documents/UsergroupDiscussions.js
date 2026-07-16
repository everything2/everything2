import React, { useState, useEffect, useCallback } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import { getE2EditorExtensions } from '../Editor/useE2Editor'
import { convertToE2Syntax } from '../Editor/E2LinkExtension'
import { convertRawBracketsToEntities } from '../Editor/RawBracketExtension'
import { normalizeEditorHtml } from '../Editor/E2HtmlSanitizer'
import MenuBar from '../Editor/MenuBar'
import EditorModeToggle from '../Editor/EditorModeToggle'
import LinkNode from '../LinkNode'
import { FaComments, FaSpinner, FaBullhorn } from 'react-icons/fa'
import '../Editor/E2Editor.css'

/**
 * UsergroupDiscussions - View and manage usergroup discussions.
 *
 * Fully client-resolved (#4541): the Page is a pure gate. Fetches GET /api/usergroup_discussions on
 * mount, reading show_ug/offset off the URL; the usergroup selector + pagination refetch IN PLACE
 * (no reload) via history.pushState. Creating a discussion still POSTs to
 * /api/debatecomments/action/create (unchanged) and navigates to the new node.
 */
const GUEST_COPY = 'If you logged in, you would be able to strike up long-winded conversations with your buddies'
const NO_UG_COPY = 'You have no usergroups! Find some friends first, and then start a discussion with them.'
const ACCESS_DENIED_COPY = 'You are not a member of the selected usergroup.'

const paramsFromUrl = () => {
  const qs = new URLSearchParams(window.location.search)
  return { show_ug: qs.get('show_ug') || '', offset: qs.get('offset') || '' }
}

const UsergroupDiscussions = ({ user }) => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = useCallback((params, { push } = {}) => {
    const api = new URLSearchParams()
    if (params.show_ug) api.set('show_ug', String(params.show_ug))
    if (params.offset) api.set('offset', String(params.offset))

    if (push) {
      const url = new URL(window.location.href)
      for (const k of ['show_ug', 'offset']) {
        if (params[k] !== undefined && params[k] !== '' && String(params[k]) !== '0') url.searchParams.set(k, String(params[k]))
        else url.searchParams.delete(k)
      }
      // show_ug=0 (all groups) is meaningful; keep it explicit
      if (String(params.show_ug) === '0') url.searchParams.set('show_ug', '0')
      window.history.pushState({}, '', url.pathname + url.search)
    }

    setLoading(true)
    return fetch(`/api/usergroup_discussions?${api}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { setData(j); setLoading(false) })
      .catch(() => setLoading(false))
  }, [])

  useEffect(() => {
    load(paramsFromUrl())
    const onPop = () => load(paramsFromUrl())
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [load])

  if (loading && !data) {
    return <div className="ug-discussions"><p>Loading...</p></div>
  }

  const { state, usergroups = [], selected_usergroup, discussions = [], total_discussions = 0, offset = 0, limit = 50 } = data || {}

  const selectGroup = (ugId) => load({ show_ug: ugId }, { push: true })
  const paginate = (newOffset) => load({ show_ug: selected_usergroup, offset: newOffset }, { push: true })

  const seeAlso = (
    <p className="ug-discussions__see-also">See also <LinkNode title="usergroup message archive" /></p>
  )

  if (state === 'guest') {
    return <div className="ug-discussions">{seeAlso}<p>{GUEST_COPY}</p></div>
  }
  if (state === 'no_usergroups') {
    return <div className="ug-discussions">{seeAlso}<p>{NO_UG_COPY}</p></div>
  }
  if (state === 'access_denied') {
    return (
      <div className="ug-discussions">
        {seeAlso}
        <UsergroupSelector usergroups={usergroups} selectedUsergroup={selected_usergroup} onSelect={selectGroup} />
        <p className="ug-discussions__error">{ACCESS_DENIED_COPY}</p>
      </div>
    )
  }

  const hasMore = offset + discussions.length < total_discussions
  const hasPrev = offset > 0

  return (
    <div className="ug-discussions">
      {seeAlso}

      <UsergroupSelector usergroups={usergroups} selectedUsergroup={selected_usergroup} onSelect={selectGroup} />

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
                    (<a href={`?node_id=${disc.node_id}&displaytype=compact`} className="ug-discussions__link">compact</a>)
                  </td>
                  <td className="ug-discussions__td--small">
                    <LinkNode nodeId={disc.usergroup_id} title={disc.usergroup_title} />
                  </td>
                  <td className="ug-discussions__td">
                    <LinkNode nodeId={disc.author_id} title={disc.author_title} />
                  </td>
                  <td className="ug-discussions__td">{disc.reply_count}</td>
                  <td className="ug-discussions__td">{disc.unread ? '×' : ''}</td>
                  <td className="ug-discussions__td">{disc.last_updated}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <p className="ug-discussions__total-count">There are {total_discussions} discussions total</p>

          {(hasPrev || hasMore) && (
            <div className="ug-discussions__pagination">
              {hasPrev && (
                <a href="#" className="ug-discussions__link" onClick={(e) => { e.preventDefault(); paginate(offset - limit) }}>
                  prev {offset - limit + 1} &ndash; {offset}
                </a>
              )}
              {hasPrev && hasMore && ' | '}
              <span>Now: {offset + 1} &ndash; {offset + discussions.length}</span>
              {hasMore && ' | '}
              {hasMore && (
                <a href="#" className="ug-discussions__link" onClick={(e) => { e.preventDefault(); paginate(offset + limit) }}>
                  next {offset + limit + 1} &ndash; {Math.min(offset + 2 * limit, total_discussions)}
                </a>
              )}
            </div>
          )}
        </>
      )}

      <NewDiscussionForm usergroups={usergroups} selectedUsergroup={selected_usergroup} />
    </div>
  )
}

const UsergroupSelector = ({ usergroups, selectedUsergroup, onSelect }) => (
  <div className="ug-discussions__selector">
    <p>Choose the usergroup to filter by:</p>
    <div className="ug-discussions__usergroup-grid">
      {usergroups.map((ug) => (
        <a
          key={ug.node_id}
          href={`?show_ug=${ug.node_id}`}
          onClick={(e) => { e.preventDefault(); onSelect(ug.node_id) }}
          className={`ug-discussions__usergroup-link${Number(selectedUsergroup) === ug.node_id ? ' ug-discussions__usergroup-link--active' : ''}`}
        >
          {ug.title}
        </a>
      ))}
    </div>
    <p className="ug-discussions__show-all">
      Or{' '}
      <a
        href="?show_ug=0"
        onClick={(e) => { e.preventDefault(); onSelect(0) }}
        className={`ug-discussions__link${Number(selectedUsergroup) === 0 ? ' ug-discussions__link--active' : ''}`}
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

        // Keep the button disabled (saving stays true) through the redirect so it
        // doesn't flash back to its active state before the page navigates away.
        setTimeout(() => {
          window.location.href = `/?node_id=${result.node_id}`
        }, 1000)
      } else {
        setError(result.error || 'Failed to create discussion')
        setSaving(false)
      }
    } catch (err) {
      setError('Network error: ' + err.message)
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

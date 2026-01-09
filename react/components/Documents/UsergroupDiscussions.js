import React, { useState, useCallback, useEffect } from 'react'
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
      <div style={styles.container}>
        <p style={styles.seeAlso}>
          See also <LinkNode title="usergroup message archive" />
        </p>
        <p>{message}</p>
      </div>
    )
  }

  if (no_usergroups) {
    return (
      <div style={styles.container}>
        <p style={styles.seeAlso}>
          See also <LinkNode title="usergroup message archive" />
        </p>
        <p>{message}</p>
      </div>
    )
  }

  if (access_denied) {
    return (
      <div style={styles.container}>
        <p style={styles.seeAlso}>
          See also <LinkNode title="usergroup message archive" />
        </p>
        <UsergroupSelector
          usergroups={usergroups}
          selectedUsergroup={selected_usergroup}
          nodeId={node_id}
        />
        <p style={styles.error}>{message}</p>
      </div>
    )
  }

  const hasMore = offset + discussions.length < total_discussions
  const hasPrev = offset > 0

  return (
    <div style={styles.container}>
      <p style={styles.seeAlso}>
        See also <LinkNode title="usergroup message archive" />
      </p>

      <UsergroupSelector
        usergroups={usergroups}
        selectedUsergroup={selected_usergroup}
        nodeId={node_id}
      />

      {discussions.length === 0 ? (
        <p style={styles.noDiscussions}>There are no discussions!</p>
      ) : (
        <>
          <table style={styles.table}>
            <thead>
              <tr style={styles.headerRow}>
                <th style={styles.th} colSpan="2">title</th>
                <th style={styles.th}>usergroup</th>
                <th style={styles.th}>author</th>
                <th style={styles.th}>replies</th>
                <th style={styles.th}>new</th>
                <th style={styles.th}>last updated</th>
              </tr>
            </thead>
            <tbody>
              {discussions.map((disc) => (
                <tr key={disc.node_id}>
                  <td style={styles.td}>
                    <LinkNode nodeId={disc.node_id} title={disc.title} />
                  </td>
                  <td style={styles.tdSmall}>
                    (<a
                      href={`?node_id=${disc.node_id}&displaytype=compact`}
                      style={styles.link}
                    >
                      compact
                    </a>)
                  </td>
                  <td style={styles.tdSmall}>
                    <LinkNode nodeId={disc.usergroup_id} title={disc.usergroup_title} />
                  </td>
                  <td style={styles.td}>
                    <LinkNode nodeId={disc.author_id} title={disc.author_title} />
                  </td>
                  <td style={styles.td}>{disc.reply_count}</td>
                  <td style={styles.td}>{disc.unread ? '\u00D7' : ''}</td>
                  <td style={styles.td}>{disc.last_updated}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <p style={styles.totalCount}>
            There are {total_discussions} discussions total
          </p>

          {(hasPrev || hasMore) && (
            <div style={styles.pagination}>
              {hasPrev && (
                <a
                  href={`?node_id=${node_id}&show_ug=${selected_usergroup}&offset=${offset - limit}`}
                  style={styles.link}
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
                  style={styles.link}
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
  <div style={styles.selector}>
    <p>Choose the usergroup to filter by:</p>
    <div style={styles.usergroupGrid}>
      {usergroups.map((ug) => (
        <a
          key={ug.node_id}
          href={`?node_id=${nodeId}&show_ug=${ug.node_id}`}
          style={{
            ...styles.usergroupLink,
            fontWeight: selectedUsergroup === ug.node_id ? 'bold' : 'normal'
          }}
        >
          {ug.title}
        </a>
      ))}
    </div>
    <p style={styles.showAll}>
      Or{' '}
      <a
        href={`?node_id=${nodeId}&show_ug=0`}
        style={{
          ...styles.link,
          fontWeight: selectedUsergroup === 0 ? 'bold' : 'normal'
        }}
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
    <div style={styles.newDiscussion}>
      <hr style={styles.hr} />

      <div style={styles.formHeader}>
        <FaComments style={{ color: '#38495e', marginRight: 8, fontSize: 20 }} />
        <h3 style={styles.formTitle}>Start a New Discussion</h3>
      </div>

      {/* Messages */}
      {error && (
        <div style={styles.errorMessage}>
          {error}
        </div>
      )}
      {success && (
        <div style={styles.successMessage}>
          {success}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        {/* Title */}
        <div style={styles.formGroup}>
          <label style={styles.label}>Discussion Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={64}
            style={styles.titleInput}
            placeholder="Enter a title for your discussion..."
            disabled={saving}
          />
        </div>

        {/* Usergroup selection */}
        <div style={styles.formGroup}>
          <label style={styles.label}>Usergroup</label>
          <select
            value={usergroup}
            onChange={(e) => setUsergroup(e.target.value)}
            style={styles.select}
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
        <div style={styles.formGroup}>
          <label style={styles.checkboxLabel}>
            <input
              type="checkbox"
              checked={announce}
              onChange={(e) => setAnnounce(e.target.checked)}
              disabled={saving}
              style={styles.checkbox}
            />
            <FaBullhorn style={{ marginRight: 6, color: '#507898' }} />
            Announce new discussion to usergroup
          </label>
        </div>

        {/* Content editor with Rich/HTML toggle */}
        <div style={styles.formGroup}>
          <div style={styles.editorHeader}>
            <label style={styles.label}>First Post</label>
            <EditorModeToggle
              mode={editorMode}
              onToggle={handleModeToggle}
              disabled={saving}
            />
          </div>

          {editorMode === 'rich' ? (
            <div style={styles.editorContainer}>
              <MenuBar editor={editor} />
              <div className="e2-editor-wrapper" style={{ padding: '12px', minHeight: 200 }}>
                <EditorContent editor={editor} />
              </div>
            </div>
          ) : (
            <textarea
              value={htmlContent}
              onChange={handleHtmlChange}
              placeholder="Enter HTML content here..."
              aria-label="Content (HTML)"
              style={styles.htmlTextarea}
              spellCheck={false}
              disabled={saving}
            />
          )}
        </div>

        {/* Submit button */}
        <button
          type="submit"
          disabled={saving}
          style={{
            ...styles.button,
            opacity: saving ? 0.6 : 1,
            cursor: saving ? 'not-allowed' : 'pointer'
          }}
        >
          {saving ? (
            <>
              <FaSpinner className="fa-spin" style={{ marginRight: 8 }} />
              Creating...
            </>
          ) : (
            <>
              <FaComments style={{ marginRight: 8 }} />
              Start New Discussion
            </>
          )}
        </button>
      </form>
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#38495e'
  },
  seeAlso: {
    textAlign: 'right',
    fontSize: '12px',
    marginBottom: '15px',
    color: '#507898'
  },
  selector: {
    marginBottom: '20px'
  },
  usergroupGrid: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '10px',
    justifyContent: 'center',
    marginTop: '10px'
  },
  usergroupLink: {
    color: '#4060b0',
    textDecoration: 'none',
    padding: '4px 8px'
  },
  showAll: {
    textAlign: 'center',
    marginTop: '10px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px'
  },
  headerRow: {
    backgroundColor: '#e8f4f8'
  },
  th: {
    textAlign: 'left',
    padding: '8px 10px',
    fontWeight: 'bold',
    color: '#38495e',
    borderBottom: '2px solid #38495e'
  },
  td: {
    padding: '8px 10px',
    borderBottom: '1px solid #e8f4f8',
    color: '#38495e'
  },
  tdSmall: {
    padding: '8px 10px',
    borderBottom: '1px solid #e8f4f8',
    fontSize: '11px',
    color: '#507898'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  totalCount: {
    textAlign: 'right',
    marginTop: '10px',
    color: '#507898'
  },
  pagination: {
    textAlign: 'right',
    marginTop: '10px',
    color: '#507898'
  },
  noDiscussions: {
    textAlign: 'center',
    padding: '20px',
    color: '#507898'
  },
  error: {
    color: '#c62828'
  },
  newDiscussion: {
    marginTop: '30px'
  },
  hr: {
    border: 'none',
    borderTop: '2px solid #38495e',
    margin: '20px 0'
  },
  formHeader: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: '20px'
  },
  formTitle: {
    margin: 0,
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e'
  },
  formGroup: {
    marginBottom: '16px'
  },
  label: {
    display: 'block',
    marginBottom: '6px',
    fontWeight: 'bold',
    color: '#38495e',
    fontSize: '14px'
  },
  titleInput: {
    width: '100%',
    maxWidth: '500px',
    padding: '10px 12px',
    fontSize: '14px',
    border: '1px solid #38495e',
    borderRadius: '4px',
    boxSizing: 'border-box',
    color: '#38495e'
  },
  select: {
    padding: '10px 12px',
    fontSize: '14px',
    border: '1px solid #38495e',
    borderRadius: '4px',
    color: '#38495e',
    backgroundColor: '#fff'
  },
  checkboxLabel: {
    display: 'inline-flex',
    alignItems: 'center',
    cursor: 'pointer',
    color: '#38495e',
    fontSize: '14px'
  },
  checkbox: {
    marginRight: '8px',
    width: '16px',
    height: '16px'
  },
  editorHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '8px'
  },
  editorContainer: {
    border: '1px solid #ced4da',
    borderRadius: '4px',
    backgroundColor: '#fff',
    overflow: 'hidden'
  },
  htmlTextarea: {
    width: '100%',
    minHeight: '200px',
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
  },
  button: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '12px 24px',
    backgroundColor: '#4060b0',
    color: '#ffffff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  errorMessage: {
    padding: '12px',
    backgroundColor: '#f8d7da',
    border: '1px solid #f5c6cb',
    borderRadius: '4px',
    color: '#721c24',
    marginBottom: '16px'
  },
  successMessage: {
    padding: '12px',
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '4px',
    color: '#155724',
    marginBottom: '16px'
  }
}

export default UsergroupDiscussions

import React, { useState, useEffect } from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything Publication Directory - E2 Publications debate discussions
 * Styles in CSS: .e2-pub-directory__*
 *
 * Shows debates for E2 Publications, sorted by most recent comment.
 *
 * Fetch-driven (#4557): the Page is a pure gate; this fetches
 * GET /api/everything_publication_directory, which is the real gate -- thepub usergroup or admin.
 * Non-members get success:0/state:'permission'.
 */
const EverythingPublicationDirectory = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [title, setTitle] = useState('')

  useEffect(() => {
    let cancelled = false
    fetch('/api/everything_publication_directory', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  // Reaching success:1 means the API let this viewer in (thepub or admin), which is exactly
  // the group that may open a debate -- so the create form is gated on that, not on a
  // hardcoded can_create flag the server used to ship.
  const { success = 0, state, debates = [] } = data || {}

  if (loading) {
    return <div className="e2-pub-directory"><p>Loading...</p></div>
  }

  if (!success) {
    return (
      <div className="e2-pub-directory">
        <p className="e2-pub-directory__error">
          {state === 'guest'
            ? 'Please log in first.'
            : 'Access denied. This page is restricted to thepub usergroup members and admins.'}
        </p>
      </div>
    )
  }

  // Create the debate via the generic node API (was op=new). #4340.
  const handleCreateDebate = async (e) => {
    e.preventDefault()
    const trimmed = title.trim()
    if (!trimmed) {
      alert('Please enter a title for the new discussion')
      return
    }

    const res = await fetch('/api/node/create', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ type: 'debate', title: trimmed }),
    })
    const result = res.ok ? await res.json() : null
    if (result && result.success && result.node_id) {
      window.location.href = `/node/${result.node_id}`
      return
    }
    alert((result && result.error) || 'Could not create the discussion')
  }

  return (
    <div className="e2-pub-directory">
      <p>Discussions on E2 Publications, most recently commented listed first.</p>

      <p>The "restricted" column shows who may view/add to a discussion.</p>

      <table className="e2-pub-directory__table">
        <thead>
          <tr className="e2-pub-directory__header-row">
            <th className="e2-pub-directory__th e2-pub-directory__th--title" colSpan="2">Title</th>
            <th className="e2-pub-directory__th e2-pub-directory__th--restricted">Restricted</th>
            <th className="e2-pub-directory__th e2-pub-directory__th--author">Author</th>
            <th className="e2-pub-directory__th e2-pub-directory__th--date">Created</th>
            <th className="e2-pub-directory__th e2-pub-directory__th--date">Last Updated</th>
          </tr>
        </thead>
        <tbody>
          {debates.length === 0 ? (
            <tr>
              <td colSpan="6" className="e2-pub-directory__empty-state">
                No discussions found.
              </td>
            </tr>
          ) : (
            debates.map((debate) => (
              <tr key={debate.node_id} className="e2-pub-directory__row">
                <td className="e2-pub-directory__td">
                  <LinkNode nodeId={debate.node_id} title={debate.title} />
                </td>
                <td className="e2-pub-directory__td">
                  <small>
                    (
                    <LinkNode
                      nodeId={debate.node_id}
                      title="compact"
                      params={{ displaytype: 'compact' }}
                    />
                    )
                  </small>
                </td>
                <td className="e2-pub-directory__td">
                  <small>
                    <LinkNode nodeId={debate.restricted_id} title={debate.restricted_title} />
                  </small>
                </td>
                <td className="e2-pub-directory__td">
                  <LinkNode nodeId={debate.author_id} title={debate.author_title} />
                </td>
                <td className="e2-pub-directory__td">{debate.created}</td>
                <td className="e2-pub-directory__td">{debate.latest_time}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div className="e2-pub-directory__create-form">
        <p className="e2-pub-directory__create-heading">
          <strong>Create a New Discussion:</strong>
        </p>

        <form onSubmit={handleCreateDebate}>
          <div className="e2-pub-directory__form-group">
            <input
              type="text"
              name="node"
              size="50"
              maxLength="64"
              placeholder="Enter discussion title..."
              className="e2-pub-directory__input"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
            <br />
            <input
              type="submit"
              value="Create Debate"
              className="e2-pub-directory__submit-button"
            />
          </div>
        </form>
      </div>
    </div>
  )
}

export default EverythingPublicationDirectory

import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything Publication Directory - E2 Publications debate discussions
 * Styles in CSS: .e2-pub-directory__*
 *
 * Shows debates for E2 Publications, sorted by most recent comment.
 * Restricted to thepub usergroup members.
 */
const EverythingPublicationDirectory = ({ data }) => {
  const { error, debates = [], can_create = false } = data

  if (error) {
    return (
      <div className="e2-pub-directory">
        <p className="e2-pub-directory__error">{error}</p>
      </div>
    )
  }

  const handleCreateDebate = (e) => {
    e.preventDefault()
    const title = e.target.elements.node.value.trim()
    if (!title) {
      alert('Please enter a title for the new discussion')
      return
    }

    // Submit the form to create a new debate
    e.target.submit()
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

      {can_create && (
        <div className="e2-pub-directory__create-form">
          <p className="e2-pub-directory__create-heading">
            <strong>Create a New Discussion:</strong>
          </p>

          <form method="post" onSubmit={handleCreateDebate}>
            <input type="hidden" name="op" value="new" />
            <input type="hidden" name="type" value="debate" />
            <input type="hidden" name="displaytype" value="edit" />
            <input type="hidden" name="debate_parent_debatecomment" value="0" />

            <div className="e2-pub-directory__form-group">
              <input
                type="text"
                name="node"
                size="50"
                maxLength="64"
                placeholder="Enter discussion title..."
                className="e2-pub-directory__input"
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
      )}
    </div>
  )
}

export default EverythingPublicationDirectory

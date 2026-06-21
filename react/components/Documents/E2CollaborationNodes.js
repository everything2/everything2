import React, { useState } from 'react'

/**
 * E2CollaborationNodes - Collaboration node management
 * Styles in CSS: .e2-collab__*
 *
 * Allows users to search and create collaboration nodes.
 */
const E2CollaborationNodes = ({ data }) => {
  const [searchNode, setSearchNode] = useState('')
  const [createNode, setCreateNode] = useState('')
  const [soundex, setSoundex] = useState(false)
  const [matchAll, setMatchAll] = useState(false)

  // Create a collaboration via the generic node API (was op=new). #4340 Phase 2.
  const handleCreateCollab = async (e) => {
    e.preventDefault()
    if (!createNode.trim()) return
    try {
      const res = await fetch('/api/node/create', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ type: 'collaboration', title: createNode }),
      })
      const data = res.ok ? await res.json() : null
      if (data && data.success && data.node_id) {
        window.location.href = `/node/${data.node_id}`
      }
    } catch (err) {
      // leave the form in place on failure
    }
  }

  return (
    <div className="e2-collab">
      <div className="e2-collab__instructions">
        <p><strong>Here's how these puppies operate:</strong></p>

        <dl className="e2-collab__dl">
          <dt className="e2-collab__dt">Access</dt>
          <dd className="e2-collab__dd">
            <p>Any CE or god can view or edit any collaboration node. A regular
            user can't, unless one of us explicitly grants access. You grant
            access by editing the node and adding the user's name to the
            "Allowed Users" list for that node (just type it into the box; it
            should be clear). You can also add a user<em>group</em> to the
            list: In that case, every user who belongs to that group will have
            access (<em>full</em> access) to the node.</p>
          </dd>

          <dt className="e2-collab__dt">Locking</dt>
          <dd className="e2-collab__dd">
            <p>The only difficulty with this is the fact that two different
            users will, inevitably, end up trying to edit the same node at the
            same time. They'll step on each other's changes. We handle this
            problem the way everybody does: When somebody begins editing a
            collaboration node, it is automatically "locked". CEs and gods can
            forcibly unlock a collaboration node, but don't do it too casually
            because, once again, you may step on the user's changes. Any user
            can voluntarily release his or her <em>own</em> lock on a
            collaboration node (but they'll forget which is why you can do it
            yourself). Finally, all "locks" on these nodes expire after fifteen
            idle minutes, or maybe it's twenty. I can't remember.{' '}
            <strong>Use it or lose it.</strong></p>

            <p>The "locking" feature may be a bit perplexing at first, but
            it's necessary if the feature is to be useful in practice.</p>
          </dd>
        </dl>

        <p>The HTML "rules" here are the same as for writeups, except
        that you can also use the mysterious and powerful &lt;highlight&gt; tag.</p>
      </div>

      <hr />

      {/* Search Form */}
      <div className="e2-collab__form">
        <div className="e2-collab__form-title">Search for a collaboration node:</div>
        <form method="post" encType="application/x-www-form-urlencoded">
          <div>
            <input
              type="text"
              name="node"
              value={searchNode}
              onChange={(e) => setSearchNode(e.target.value)}
              className="e2-collab__input"
              placeholder="Node title"
              maxLength={64}
            />
            <input type="hidden" name="type" value="collaboration" />
            <button type="submit" name="searchy" className="e2-collab__button">
              search
            </button>
          </div>
          <div className="e2-collab__checkbox-group">
            <label className="e2-collab__checkbox-label">
              <input
                type="checkbox"
                name="soundex"
                value="1"
                checked={soundex}
                onChange={(e) => setSoundex(e.target.checked)}
              />
              {' '}Near Matches
            </label>
            <label className="e2-collab__checkbox-label">
              <input
                type="checkbox"
                name="match_all"
                value="1"
                checked={matchAll}
                onChange={(e) => setMatchAll(e.target.checked)}
              />
              {' '}Ignore Exact
            </label>
          </div>
        </form>
      </div>

      <hr />

      {/* Create Form */}
      <div className="e2-collab__form">
        <div className="e2-collab__form-title">Create a new collaboration node:</div>
        <form onSubmit={handleCreateCollab}>
          <input
            type="text"
            name="node"
            value={createNode}
            onChange={(e) => setCreateNode(e.target.value)}
            className="e2-collab__input"
            placeholder="New node title"
            maxLength={64}
          />
          <button type="submit" className="e2-collab__button">
            create
          </button>
        </form>
      </div>
    </div>
  )
}

export default E2CollaborationNodes

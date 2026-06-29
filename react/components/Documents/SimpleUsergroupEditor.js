import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * SimpleUsergroupEditor - Editor for usergroup membership.
 * Styles in CSS: .simple-usergroup-editor__*
 *
 * Add/remove drive the existing usergroups API (#4412) rather than a POST form
 * that mutated membership inside the page controller:
 *   - remove: POST /api/usergroups/:id/action/removeuser  (member node_ids)
 *   - add:    resolve each username via /api/nodes/lookup/user/:title, then
 *             POST /api/usergroups/:id/action/adduser      (resolved node_ids)
 * The member list is updated optimistically; a message reports added / removed /
 * not-found, matching the old controller's behaviour.
 */
const SimpleUsergroupEditor = ({ data }) => {
  const {
    no_access,
    usergroups,
    selected_usergroup,
    members: initialMembers = [],
    ignoring_users = []
  } = data

  const [members, setMembers] = useState(initialMembers)
  const [removeIds, setRemoveIds] = useState(() => new Set())
  const [addPeople, setAddPeople] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState(null)
  const [error, setError] = useState(null)

  if (no_access) {
    return (
      <div className="simple-usergroup-editor">
        <p>You have nothing to edit here.</p>
      </div>
    )
  }

  const nodeId = window.e2?.node_id || ''

  const toggleRemove = (id) => {
    setRemoveIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    setMessage(null)
    const gid = selected_usergroup.node_id

    try {
      const removeArr = [...removeIds]
      const removedNames = members.filter((m) => removeIds.has(m.node_id)).map((m) => m.title)

      // Resolve add usernames -> node_ids
      const names = addPeople.split(/[\r\n]+/).map((s) => s.trim()).filter(Boolean)
      const addIds = []
      const addedNames = []
      const notFound = []
      for (const name of names) {
        const res = await fetch(`/api/nodes/lookup/user/${encodeURIComponent(name)}`, {
          credentials: 'same-origin',
          headers: { Accept: 'application/json' },
        })
        if (res.ok) {
          const n = await res.json()
          if (n && n.node_id) {
            addIds.push(n.node_id)
            addedNames.push(n.title || name)
            continue
          }
        }
        notFound.push(name)
      }

      if (removeArr.length) {
        const r = await fetch(`/api/usergroups/${gid}/action/removeuser`, {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
          body: JSON.stringify(removeArr),
        })
        const body = r.ok ? await r.json() : null
        if (!body || body.success === 0) throw new Error((body && body.error) || 'Failed to remove members')
      }

      if (addIds.length) {
        const r = await fetch(`/api/usergroups/${gid}/action/adduser`, {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
          body: JSON.stringify(addIds),
        })
        const body = r.ok ? await r.json() : null
        if (!body || body.success === 0) throw new Error((body && body.error) || 'Failed to add members')
      }

      // Optimistically update the member list
      setMembers((prev) => {
        const kept = prev.filter((m) => !removeIds.has(m.node_id))
        const existing = new Set(kept.map((m) => m.node_id))
        const additions = addIds
          .map((id, i) => ({ node_id: id, title: addedNames[i] }))
          .filter((a) => !existing.has(a.node_id))
        return [...kept, ...additions]
      })

      const parts = []
      if (addedNames.length) parts.push(`Added: ${addedNames.join(', ')}`)
      if (removedNames.length) parts.push(`Removed: ${removedNames.join(', ')}`)
      if (notFound.length) parts.push(`Not found: ${notFound.join(', ')}`)
      setMessage(parts.length ? `${parts.join('. ')}.` : 'No changes made.')
      setAddPeople('')
      setRemoveIds(new Set())
    } catch (err) {
      setError(err.message || 'Update failed')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="simple-usergroup-editor">
      <table className="simple-usergroup-editor__layout">
        <tbody>
          <tr>
            {/* Left column: usergroup list */}
            <td className="simple-usergroup-editor__left-column">
              <strong>Choose a usergroup to edit:</strong>
              <ul className="simple-usergroup-editor__list">
                {usergroups.map((ug) => (
                  <li key={ug.node_id}>
                    <a
                      href={`?node_id=${nodeId}&for_usergroup=${ug.node_id}`}
                      className={
                        selected_usergroup && selected_usergroup.node_id === ug.node_id
                          ? 'simple-usergroup-editor__link--selected'
                          : 'simple-usergroup-editor__link'
                      }
                    >
                      {ug.title}
                    </a>
                  </li>
                ))}
              </ul>
            </td>

            {/* Right column: selected usergroup editor */}
            {selected_usergroup && (
              <td className="simple-usergroup-editor__right-column">
                <h3 className="simple-usergroup-editor__subtitle">
                  Editing <LinkNode id={selected_usergroup.node_id} display={selected_usergroup.title} />
                </h3>

                {message && (
                  <div className="simple-usergroup-editor__message">{message}</div>
                )}
                {error && (
                  <div className="simple-usergroup-editor__error">{error}</div>
                )}

                <form onSubmit={handleSubmit}>
                  {/* Current members */}
                  <table className="simple-usergroup-editor__member-table">
                    <thead>
                      <tr>
                        <th className="simple-usergroup-editor__th">Remove?</th>
                        <th className="simple-usergroup-editor__th">User</th>
                      </tr>
                    </thead>
                    <tbody>
                      {members.length > 0 ? (
                        members.map((member) => (
                          <tr key={member.node_id}>
                            <td className="simple-usergroup-editor__td">
                              <input
                                type="checkbox"
                                checked={removeIds.has(member.node_id)}
                                onChange={() => toggleRemove(member.node_id)}
                                disabled={busy}
                              />
                            </td>
                            <td className="simple-usergroup-editor__td">
                              <LinkNode id={member.node_id} display={member.title} />
                              {member.lasttime && (
                                <small className="simple-usergroup-editor__last-seen"> (last seen: {member.lasttime})</small>
                              )}
                            </td>
                          </tr>
                        ))
                      ) : (
                        <tr>
                          <td colSpan={2} className="simple-usergroup-editor__td">
                            <em>No members in this group.</em>
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>

                  {/* Add people */}
                  <div className="simple-usergroup-editor__add-section">
                    <label>
                      Add people (one per line):
                      <br />
                      <textarea
                        value={addPeople}
                        onChange={(e) => setAddPeople(e.target.value)}
                        rows={10}
                        cols={30}
                        className="simple-usergroup-editor__textarea"
                        disabled={busy}
                      />
                    </label>
                  </div>

                  <button type="submit" className="simple-usergroup-editor__button" disabled={busy}>
                    {busy ? 'Updating…' : 'Update group'}
                  </button>
                </form>

                {/* Users ignoring this group */}
                {ignoring_users.length > 0 && (
                  <div className="simple-usergroup-editor__ignoring-section">
                    <p>
                      <strong>Users Ignoring This Group</strong> (includes ex-members)
                    </p>
                    <ul className="simple-usergroup-editor__ignoring-list">
                      {ignoring_users.map((user) => (
                        <li key={user.node_id}>
                          <LinkNode id={user.node_id} display={user.title} />
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </td>
            )}
          </tr>
        </tbody>
      </table>
    </div>
  )
}

export default SimpleUsergroupEditor

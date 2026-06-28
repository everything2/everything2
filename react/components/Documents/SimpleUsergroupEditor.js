import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * SimpleUsergroupEditor - Editor for usergroup membership.
 * Styles in CSS: .simple-usergroup-editor__*
 *
 * Allows adding/removing users from usergroups.
 */
const SimpleUsergroupEditor = ({ data }) => {
  const {
    no_access,
    usergroups,
    selected_usergroup,
    members,
    ignoring_users,
    message
  } = data

  const [addPeople, setAddPeople] = useState('')

  if (no_access) {
    return (
      <div className="simple-usergroup-editor">
        <p>You have nothing to edit here.</p>
      </div>
    )
  }

  const nodeId = window.e2?.node_id || ''

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
                  <div className="simple-usergroup-editor__message">
                    {message}
                  </div>
                )}

                <form method="POST">
                  <input type="hidden" name="node_id" value={nodeId} />
                  <input type="hidden" name="for_usergroup" value={selected_usergroup.node_id} />

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
                              <input type="checkbox" name={`rem_${member.node_id}`} />
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
                        name="addperson"
                        value={addPeople}
                        onChange={(e) => setAddPeople(e.target.value)}
                        rows={10}
                        cols={30}
                        className="simple-usergroup-editor__textarea"
                      />
                    </label>
                  </div>

                  <button type="submit" name="submit" value="Update group" className="simple-usergroup-editor__button">
                    Update group
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

import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * SimpleUsergroupEditor - Editor for usergroup membership.
 * Allows adding/removing users from usergroups.
 */
const SimpleUsergroupEditor = ({ data }) => {
  const {
    no_access,
    usergroups,
    selected_usergroup,
    members,
    ignoring_users,
    is_admin,
    is_editor,
    message
  } = data

  const [addPeople, setAddPeople] = useState('')

  if (no_access) {
    return (
      <div style={styles.container}>
        <p>You have nothing to edit here.</p>
      </div>
    )
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div style={styles.container}>
      <table style={styles.layout}>
        <tbody>
          <tr>
            {/* Left column: usergroup list */}
            <td style={styles.leftColumn}>
              <strong>Choose a usergroup to edit:</strong>
              <ul style={styles.usergroupList}>
                {usergroups.map((ug) => (
                  <li key={ug.node_id}>
                    <a
                      href={`?node_id=${nodeId}&for_usergroup=${ug.node_id}`}
                      style={
                        selected_usergroup && selected_usergroup.node_id === ug.node_id
                          ? styles.selectedLink
                          : styles.link
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
              <td style={styles.rightColumn}>
                <h3 style={styles.subtitle}>
                  Editing <LinkNode id={selected_usergroup.node_id} display={selected_usergroup.title} />
                </h3>

                {message && (
                  <div style={styles.message}>
                    {message}
                  </div>
                )}

                <form method="POST">
                  <input type="hidden" name="node_id" value={nodeId} />
                  <input type="hidden" name="for_usergroup" value={selected_usergroup.node_id} />

                  {/* Current members */}
                  <table style={styles.memberTable}>
                    <thead>
                      <tr>
                        <th style={styles.th}>Remove?</th>
                        <th style={styles.th}>User</th>
                      </tr>
                    </thead>
                    <tbody>
                      {members.length > 0 ? (
                        members.map((member) => (
                          <tr key={member.node_id}>
                            <td style={styles.td}>
                              <input type="checkbox" name={`rem_${member.node_id}`} />
                            </td>
                            <td style={styles.td}>
                              <LinkNode id={member.node_id} display={member.title} />
                              {member.lasttime && (
                                <small style={styles.lastSeen}> (last seen: {member.lasttime})</small>
                              )}
                            </td>
                          </tr>
                        ))
                      ) : (
                        <tr>
                          <td colSpan={2} style={styles.td}>
                            <em>No members in this group.</em>
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>

                  {/* Add people */}
                  <div style={styles.addSection}>
                    <label>
                      Add people (one per line):
                      <br />
                      <textarea
                        name="addperson"
                        value={addPeople}
                        onChange={(e) => setAddPeople(e.target.value)}
                        rows={10}
                        cols={30}
                        style={styles.textarea}
                      />
                    </label>
                  </div>

                  <button type="submit" name="submit" value="Update group" style={styles.button}>
                    Update group
                  </button>
                </form>

                {/* Users ignoring this group */}
                {ignoring_users.length > 0 && (
                  <div style={styles.ignoringSection}>
                    <p>
                      <strong>Users Ignoring This Group</strong> (includes ex-members)
                    </p>
                    <ul style={styles.ignoringList}>
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

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  layout: {
    width: '100%',
    borderCollapse: 'collapse'
  },
  leftColumn: {
    width: '200px',
    verticalAlign: 'top',
    paddingRight: '20px',
    borderRight: '1px solid #d3d3d3'
  },
  rightColumn: {
    verticalAlign: 'top',
    paddingLeft: '20px'
  },
  usergroupList: {
    margin: '10px 0',
    paddingLeft: '20px',
    listStyleType: 'disc'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  selectedLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: 'bold'
  },
  subtitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    margin: '0 0 15px 0',
    color: '#38495e'
  },
  memberTable: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '15px'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px',
    textAlign: 'left'
  },
  td: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0'
  },
  lastSeen: {
    color: '#507898'
  },
  addSection: {
    marginBottom: '15px'
  },
  textarea: {
    width: '100%',
    maxWidth: '300px',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontFamily: 'monospace',
    marginTop: '5px'
  },
  button: {
    padding: '8px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  ignoringSection: {
    marginTop: '20px',
    padding: '10px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px'
  },
  ignoringList: {
    margin: '10px 0',
    paddingLeft: '20px'
  },
  message: {
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '4px',
    padding: '10px 15px',
    marginBottom: '15px',
    color: '#155724'
  }
}

export default SimpleUsergroupEditor

import React from 'react'
import LinkNode from '../LinkNode'

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

const NewDiscussionForm = ({ usergroups, selectedUsergroup }) => (
  <div style={styles.newDiscussion}>
    <hr style={styles.hr} />
    <p><strong>Choose a title for a new discussion:</strong></p>
    <form method="post">
      <input type="hidden" name="op" value="new" />
      <input type="hidden" name="type" value="debate" />
      <input type="hidden" name="displaytype" value="edit" />
      <input type="hidden" name="debate_parent_debatecomment" value="0" />

      <input
        type="text"
        name="node"
        size="50"
        maxLength="64"
        style={styles.input}
      />
      <br /><br />

      <label>
        Choose the usergroup it&apos;s for:
        <br />
        <select name="debatecomment_restricted" defaultValue={selectedUsergroup || ''} style={styles.select}>
          {usergroups.map((ug) => (
            <option key={ug.node_id} value={ug.node_id}>
              {ug.title}
            </option>
          ))}
        </select>
      </label>
      <br />

      <label style={styles.checkbox}>
        <input type="checkbox" name="announce_to_ug" value="yup" defaultChecked />
        Announce new discussion to usergroup
      </label>
      <br /><br />

      <label>
        Write the first discussion post:
        <br />
        <textarea
          name="newdebate_text"
          id="newdebate_text"
          rows="20"
          cols="80"
          style={styles.textarea}
        />
      </label>
      <br />

      <button type="submit" name="sexisgood" value="1" style={styles.button}>
        Start new discussion!
      </button>
    </form>
  </div>
)

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  seeAlso: {
    textAlign: 'right',
    fontSize: '12px',
    marginBottom: '15px'
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
    backgroundColor: '#dddddd'
  },
  th: {
    textAlign: 'left',
    padding: '6px 8px',
    fontWeight: 'bold'
  },
  td: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0'
  },
  tdSmall: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0',
    fontSize: '11px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  totalCount: {
    textAlign: 'right',
    marginTop: '10px'
  },
  pagination: {
    textAlign: 'right',
    marginTop: '10px'
  },
  noDiscussions: {
    textAlign: 'center',
    padding: '20px'
  },
  error: {
    color: '#c62828'
  },
  newDiscussion: {
    marginTop: '20px'
  },
  hr: {
    border: 'none',
    borderTop: '1px solid #d3d3d3',
    margin: '20px 0'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '400px'
  },
  select: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    marginTop: '5px'
  },
  checkbox: {
    marginTop: '10px',
    display: 'inline-block'
  },
  textarea: {
    width: '100%',
    maxWidth: '600px',
    padding: '8px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    fontFamily: 'inherit',
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
  }
}

export default UsergroupDiscussions

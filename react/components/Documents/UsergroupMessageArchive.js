import React from 'react'
import LinkNode from '../LinkNode'

/**
 * UsergroupMessageArchive - View archived messages sent to usergroups.
 * Allows copying messages to personal inbox.
 */
const UsergroupMessageArchive = ({ data }) => {
  const {
    is_guest,
    is_admin,
    archive_groups,
    node_id,
    selected_group,
    messages,
    total_messages,
    show_start,
    max_show,
    num_show,
    copied_count,
    reset_time,
    error
  } = data

  if (is_guest) {
    return (
      <div style={styles.container}>
        <p style={styles.seeAlso}>
          See also <LinkNode title="Usergroup discussions" />
        </p>
        <p>If you are a member of one of these groups, you can view messages sent to the group.</p>
        <p>{data.message}</p>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <p style={styles.seeAlso}>
        See also <LinkNode title="Usergroup discussions" />
      </p>

      <p>If you are a member of one of these groups, you can view messages sent to the group.</p>

      {is_admin && (
        <p>
          You can edit the usergroups that have messages archived at{' '}
          <a
            href="?node=usergroup+message+archive+manager&type=restricted_superdoc"
            style={styles.link}
          >
            usergroup message archive manager
          </a>.
        </p>
      )}

      <p>
        To view messages sent to a group, choose one of the following groups.
        You can only see the messages if the group has the feature enabled, and you&apos;re a member of the group.
        <br />
        Choose from:{' '}
        {archive_groups.map((g, idx) => (
          <span key={g.node_id}>
            {idx > 0 && ', '}
            <a href={`?node_id=${node_id}&viewgroup=${encodeURIComponent(g.title)}`} style={styles.link}>
              {g.title}
            </a>
          </span>
        ))}
      </p>

      {error && <p style={styles.error}>{error}</p>}

      {selected_group && !error && messages && (
        <MessageDisplay
          selectedGroup={selected_group}
          messages={messages}
          totalMessages={total_messages}
          showStart={show_start}
          maxShow={max_show}
          numShow={num_show}
          copiedCount={copied_count}
          resetTime={reset_time}
          nodeId={node_id}
        />
      )}
    </div>
  )
}

const MessageDisplay = ({
  selectedGroup,
  messages,
  totalMessages,
  showStart,
  maxShow,
  numShow,
  copiedCount,
  resetTime,
  nodeId
}) => {
  const startDefault = Math.max(0, totalMessages - maxShow)

  // Generate pagination links
  const genPaginationData = () => {
    const links = []

    // First
    if (showStart !== 0) {
      const limitU = Math.min(maxShow, totalMessages)
      links.push({
        label: `first ${maxShow} (1-${limitU})`,
        startnum: 0,
        active: false
      })
    } else {
      links.push({ label: `first ${maxShow}`, active: true })
    }

    // Previous
    if (showStart > 0) {
      const limitL = Math.max(1, showStart - maxShow)
      const limitU = Math.min(limitL + maxShow, totalMessages)
      links.push({
        label: `previous (${limitL}-${limitU - 1})`,
        startnum: showStart - maxShow,
        active: false
      })
    } else {
      links.push({ label: 'previous', active: true })
    }

    // Current
    links.push({
      label: `current (${showStart + 1}-${showStart + numShow})`,
      active: true,
      current: true
    })

    // Next
    if (showStart < startDefault) {
      let limitU = showStart + maxShow + maxShow
      limitU = Math.min(limitU, totalMessages)
      let limitL = limitU - maxShow + 1
      limitL = Math.max(1, limitL)
      limitL = Math.min(limitL, startDefault + 1)
      links.push({
        label: `next (${limitL}-${limitU})`,
        startnum: limitL - 1,
        active: false
      })
    } else {
      links.push({ label: 'next', active: true })
    }

    // Last
    if (showStart < startDefault) {
      links.push({
        label: `last ${maxShow} (${startDefault + 1}-${totalMessages})`,
        startnum: startDefault,
        active: false
      })
    } else {
      links.push({ label: `last ${maxShow}`, active: true })
    }

    return links
  }

  const paginationLinks = totalMessages > messages.length ? genPaginationData() : []

  return (
    <form method="post">
      <input type="hidden" name="node_id" value={nodeId} />
      <input type="hidden" name="viewgroup" value={selectedGroup.title} />
      <input type="hidden" name="startnum" value={showStart} />

      <p>
        Viewing messages for group <LinkNode id={selectedGroup.node_id} display={selectedGroup.title} />:
      </p>

      <label style={styles.checkbox}>
        <input
          type="checkbox"
          name="ugma_resettime"
          value="1"
          defaultChecked={resetTime}
        />
        Keep original send date (instead of using &quot;now&quot; time)
      </label>
      <br />

      {copiedCount > 0 && (
        <p style={styles.copiedMsg}>
          (Copied {copiedCount} group message{copiedCount === 1 ? '' : 's'} to self.)
        </p>
      )}

      {numShow > 0 && (
        <p>
          Showing {numShow} message{numShow === 1 ? '' : 's'} (number {showStart + 1} to {showStart + numShow}) out of a total of {totalMessages}.
        </p>
      )}

      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.thCp}>cp</th>
            <th style={styles.thNum}>#</th>
            <th style={styles.th}>author</th>
            <th style={styles.th}>time</th>
            <th style={styles.th}>message</th>
          </tr>
        </thead>
        <tbody>
          {messages.map((msg) => (
            <tr key={msg.message_id}>
              <td style={styles.tdCp}>
                <input type="checkbox" name={`cpgroupmsg_${msg.message_id}`} value="copy" />
              </td>
              <td style={styles.tdNum}>
                ({msg.number})
              </td>
              <td style={styles.tdSmall}>
                {msg.author_id ? (
                  <LinkNode id={msg.author_id} display={msg.author_title} />
                ) : (
                  '?'
                )}
              </td>
              <td style={styles.tdTime}>{msg.timestamp}</td>
              <td style={styles.td} dangerouslySetInnerHTML={{ __html: msg.text }} />
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan="5" style={styles.td}>
              Checking the box in the &quot;cp&quot; column will <strong>c</strong>o<strong>p</strong>y the message[s] to your private message box
            </td>
          </tr>
        </tfoot>
      </table>

      {paginationLinks.length > 0 && (
        <div style={styles.pagination}>
          {paginationLinks.map((link, idx) => (
            <span key={idx}>
              {idx > 0 && ' \u00A0 '}
              [ {link.active ? (
                <span style={link.current ? styles.currentLink : undefined}>{link.label}</span>
              ) : (
                <a
                  href={`?node_id=${nodeId}&viewgroup=${encodeURIComponent(selectedGroup.title)}&startnum=${link.startnum}`}
                  style={styles.link}
                >
                  {link.label}
                </a>
              )} ]
            </span>
          ))}
        </div>
      )}

      <div style={styles.submitSection}>
        <button type="submit" style={styles.button}>Copy selected messages</button>
      </div>
    </form>
  )
}

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
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  error: {
    color: '#c62828',
    padding: '10px',
    backgroundColor: '#ffebee',
    borderRadius: '4px'
  },
  checkbox: {
    display: 'inline-block',
    marginBottom: '10px'
  },
  copiedMsg: {
    color: '#2e7d32',
    fontWeight: 'bold'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '10px'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '6px 8px',
    textAlign: 'left'
  },
  thCp: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '6px 8px',
    textAlign: 'center',
    width: '30px'
  },
  thNum: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '6px 8px',
    textAlign: 'center',
    width: '40px'
  },
  td: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0',
    verticalAlign: 'top'
  },
  tdCp: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0',
    verticalAlign: 'top',
    textAlign: 'center'
  },
  tdNum: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0',
    verticalAlign: 'top',
    textAlign: 'center',
    color: '#507898',
    fontSize: '12px'
  },
  tdSmall: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0',
    verticalAlign: 'top',
    fontSize: '12px'
  },
  tdTime: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0',
    verticalAlign: 'top',
    fontFamily: 'monospace',
    fontSize: '12px',
    whiteSpace: 'nowrap'
  },
  pagination: {
    marginTop: '15px',
    textAlign: 'center'
  },
  currentLink: {
    fontWeight: 'bold'
  },
  submitSection: {
    marginTop: '15px'
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

export default UsergroupMessageArchive

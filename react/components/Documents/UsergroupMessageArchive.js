import React from 'react'
import LinkNode from '../LinkNode'

/**
 * UsergroupMessageArchive - View archived messages sent to usergroups.
 * Styles in CSS: .usergroup-archive__*
 *
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
      <div className="usergroup-archive">
        <p className="usergroup-archive__see-also">
          See also <LinkNode title="Usergroup discussions" />
        </p>
        <p>If you are a member of one of these groups, you can view messages sent to the group.</p>
        <p>{data.message}</p>
      </div>
    )
  }

  return (
    <div className="usergroup-archive">
      <p className="usergroup-archive__see-also">
        See also <LinkNode title="Usergroup discussions" />
      </p>

      <p>If you are a member of one of these groups, you can view messages sent to the group.</p>

      {!!is_admin && (
        <p>
          You can edit the usergroups that have messages archived at{' '}
          <a
            href="?node=usergroup+message+archive+manager&type=restricted_superdoc"
            className="usergroup-archive__link"
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
            <a href={`?node_id=${node_id}&viewgroup=${encodeURIComponent(g.title)}`} className="usergroup-archive__link">
              {g.title}
            </a>
          </span>
        ))}
      </p>

      {error && <p className="usergroup-archive__error">{error}</p>}

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

      <label className="usergroup-archive__checkbox">
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
        <p className="usergroup-archive__copied-msg">
          (Copied {copiedCount} group message{copiedCount === 1 ? '' : 's'} to self.)
        </p>
      )}

      {numShow > 0 && (
        <p>
          Showing {numShow} message{numShow === 1 ? '' : 's'} (number {showStart + 1} to {showStart + numShow}) out of a total of {totalMessages}.
        </p>
      )}

      <table className="usergroup-archive__table">
        <thead>
          <tr>
            <th className="usergroup-archive__th--cp">cp</th>
            <th className="usergroup-archive__th--num">#</th>
            <th className="usergroup-archive__th">author</th>
            <th className="usergroup-archive__th">time</th>
            <th className="usergroup-archive__th">message</th>
          </tr>
        </thead>
        <tbody>
          {messages.map((msg) => (
            <tr key={msg.message_id}>
              <td className="usergroup-archive__td--cp">
                <input type="checkbox" name={`cpgroupmsg_${msg.message_id}`} value="copy" />
              </td>
              <td className="usergroup-archive__td--num">
                ({msg.number})
              </td>
              <td className="usergroup-archive__td--small">
                {msg.author_id ? (
                  <LinkNode id={msg.author_id} display={msg.author_title} />
                ) : (
                  '?'
                )}
              </td>
              <td className="usergroup-archive__td--time">{msg.timestamp}</td>
              <td className="usergroup-archive__td" dangerouslySetInnerHTML={{ __html: msg.text }} />
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan="5" className="usergroup-archive__td">
              Checking the box in the &quot;cp&quot; column will <strong>c</strong>o<strong>p</strong>y the message[s] to your private message box
            </td>
          </tr>
        </tfoot>
      </table>

      {paginationLinks.length > 0 && (
        <div className="usergroup-archive__pagination">
          {paginationLinks.map((link, idx) => (
            <span key={idx}>
              {idx > 0 && ' \u00A0 '}
              [ {link.active ? (
                <span className={link.current ? 'usergroup-archive__current-link' : undefined}>{link.label}</span>
              ) : (
                <a
                  href={`?node_id=${nodeId}&viewgroup=${encodeURIComponent(selectedGroup.title)}&startnum=${link.startnum}`}
                  className="usergroup-archive__link"
                >
                  {link.label}
                </a>
              )} ]
            </span>
          ))}
        </div>
      )}

      <div className="usergroup-archive__submit-section">
        <button type="submit" className="usergroup-archive__button">Copy selected messages</button>
      </div>
    </form>
  )
}

export default UsergroupMessageArchive

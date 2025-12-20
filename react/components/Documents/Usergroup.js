import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import { FaEnvelope, FaSignOutAlt } from 'react-icons/fa'

/**
 * Usergroup - Display page for usergroup nodes
 *
 * Migrated from Everything::Delegation::htmlpage::usergroup_display_page
 * Shows usergroup members, messaging interface, and management tools
 */
const Usergroup = ({ data, user, e2 }) => {
  const [message, setMessage] = useState(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  if (!data || !data.usergroup) return null

  const {
    usergroup,
    user: userData,
    is_in_group,
    discussions_node_id,
    weblog_setting,
    message_count,
    owner_index
  } = data

  const { group = [], owner, doctext } = usergroup
  const hasMembers = group.length > 0
  const isGuest = userData.is_guest

  // Handle leave group
  const handleLeaveGroup = async (e) => {
    e.preventDefault()
    if (!confirm('Are you sure you want to leave this usergroup?')) {
      return
    }

    setIsSubmitting(true)
    setMessage(null)

    try {
      // Submit leave group request
      const formData = new FormData(e.target)
      const response = await fetch(window.location.href, {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        // Reload page to show updated state
        window.location.reload()
      } else {
        setMessage({ type: 'error', text: 'Failed to leave group' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle owner change
  const handleOwnerChange = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    try {
      const formData = new FormData(e.target)
      const response = await fetch(window.location.href, {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        window.location.reload()
      } else {
        setMessage({ type: 'error', text: 'Failed to change owner' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle weblog/ify settings
  const handleWeblogSettings = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    try {
      const formData = new FormData(e.target)
      const response = await fetch(window.location.href, {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        window.location.reload()
      } else {
        setMessage({ type: 'error', text: 'Failed to update weblog settings' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred' })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="usergroup-display">
      {message && (
        <div className={`message message-${message.type}`}>
          {message.text}
        </div>
      )}

      {/* Editor tools for gods */}
      {userData.is_god && (
        <div className="usergroup-admin-tools">
          <p>
            {/* Weblog/ify settings */}
            {weblog_setting ? (
              <span>Already has ify - <strong>{weblog_setting}</strong></span>
            ) : (
              <form onSubmit={handleWeblogSettings} style={{ display: 'inline' }}>
                Value to Display (e.g. <strong>Edevify</strong>):{' '}
                <input type="text" name="ify_display" />
                <input type="hidden" name="op" value="weblogify" />
                <button type="submit" disabled={isSubmitting}>
                  add ify!
                </button>
              </form>
            )}
          </p>
        </div>
      )}

      {/* Owner management for editors */}
      {userData.is_editor && (
        <div className="usergroup-owner-management">
          <form onSubmit={handleOwnerChange}>
            {owner && (
              <p>
                Owner is <strong><LinkNode nodeId={owner.node_id} title={owner.title} /></strong>
              </p>
            )}
            <p>
              New Owner:{' '}
              <input type="text" name="new_leader" />
              <input type="hidden" name="op" value="leadusergroup" />
              <button type="submit" disabled={isSubmitting}>
                make owner
              </button>
            </p>
            <p>
              <small>Note that the user must be a member of the group <em>before</em> they can be set as the owner.</small>
            </p>
          </form>
        </div>
      )}

      {/* Discussions link for group members */}
      {is_in_group && discussions_node_id && (
        <p style={{ textAlign: 'right' }}>
          <LinkNode
            nodeId={discussions_node_id}
            title={`Discussions for ${usergroup.title}`}
            queryParams={{ show_ug: usergroup.node_id }}
          />
        </p>
      )}

      {/* Usergroup description (doctext) */}
      {doctext && (
        <div className="usergroup-description">
          <table border="0">
            <tbody>
              <tr>
                <td dangerouslySetInnerHTML={{ __html: doctext }} />
              </tr>
            </tbody>
          </table>
        </div>
      )}

      {/* Member list */}
      <div className="usergroup-members">
        <h2>Venerable members of this group:</h2>

        {hasMembers ? (
          <div>
            <p>
              {group.map((member, index) => {
                let displayName = (
                  <LinkNode
                    key={member.node_id}
                    nodeId={member.node_id}
                    title={member.title}
                  />
                )

                // Wrap in emphasis if owner
                if (member.is_owner) {
                  displayName = <em key={member.node_id}>{displayName}</em>
                }

                // Wrap in strong if current user
                if (member.is_current) {
                  displayName = <strong key={member.node_id}>{displayName}</strong>
                }

                // Add flags
                const flagDisplay = member.flags ? (
                  <small>
                    <small>{member.flags}</small>
                  </small>
                ) : null

                return (
                  <React.Fragment key={member.node_id}>
                    {index > 0 && ', '}
                    {displayName}
                    {flagDisplay}
                  </React.Fragment>
                )
              })}
            </p>
            <p>
              This group of {group.length} member{group.length === 1 ? '' : 's'} is led by{' '}
              {hasMembers && owner_index !== undefined ? (
                <LinkNode
                  nodeId={group[0].node_id}
                  title={group[0].title}
                />
              ) : (
                'unknown'
              )}
            </p>
          </div>
        ) : (
          <p><em>This usergroup is lonely.</em></p>
        )}
      </div>

      {/* Leave group button for members */}
      {!isGuest && is_in_group && (
        <div className="usergroup-leave">
          <form onSubmit={handleLeaveGroup}>
            <input type="hidden" name="notanop" value="leavegroup" />
            <input type="hidden" name="confirmop" value="1" />
            <button
              type="submit"
              disabled={isSubmitting}
              title="leave this usergroup"
            >
              <FaSignOutAlt /> Leave group
            </button>
          </form>
        </div>
      )}

      {/* Messaging interface */}
      {!isGuest && (
        <div className="usergroup-messaging" style={{ border: 'solid black 1px', padding: '2px' }}>
          {hasMembers && (
            <>
              {/* Message to owner */}
              {owner && owner_index !== undefined && (
                <div className="msg-owner">
                  <FaEnvelope /> /msg the group "owner",{' '}
                  <LinkNode nodeId={owner.node_id} title={owner.title} />
                  {!is_in_group && ' (they can add you to the group)'}
                  <MessageField
                    fieldName={`msggrpowner${owner.node_id},,${usergroup.node_id},${owner.node_id}`}
                  />
                  <br />
                </div>
              )}

              {/* Message to leader */}
              {group[0] && (
                <div className="msg-leader">
                  <FaEnvelope /> /msg the group leader,{' '}
                  <LinkNode nodeId={group[0].node_id} title={group[0].title} />
                  :{' '}
                  <MessageField
                    fieldName={`msggrpleader${group[0].node_id},,${usergroup.node_id},${group[0].node_id}`}
                  />
                  <br />
                </div>
              )}
            </>
          )}

          {/* Message to usergroup (members and admins only) */}
          {(is_in_group || userData.is_admin) && (
            <div className="msg-usergroup">
              {!is_in_group && userData.is_admin && (
                <p>
                  (You aren't in this group, but may talk to it anyway, since you're an administrator.
                  If you want a copy of your /msg, check the "CC" box.)
                  <br />
                </p>
              )}
              <FaEnvelope /> /msg the usergroup:{' '}
              <MessageField fieldName={`ug${usergroup.node_id},,,,${usergroup.node_id}`} />
              <br />

              {/* Message count */}
              {message_count > 0 && (
                <p>
                  <LinkNode
                    nodeId={e2.message_inbox_id || 956209}
                    title={`you have ${message_count} message${message_count === 1 ? '' : 's'} from this usergroup`}
                    queryParams={{ fromgroup: usergroup.title }}
                  />
                </p>
              )}
            </div>
          )}

          {/* Other messages field */}
          <div className="msg-other">
            other /msgs: <MessageField fieldName="0" />
            <br />
          </div>
        </div>
      )}

      {/* Weblog display - placeholder for legacy htmlcode('weblog') */}
      {/* TODO: Migrate weblog display to React */}
    </div>
  )
}

/**
 * MessageField - Renders a message input field
 * Placeholder for legacy htmlcode('msgField', fieldName)
 */
const MessageField = ({ fieldName }) => {
  return (
    <span className="msg-field">
      <input
        type="text"
        name={`message_${fieldName}`}
        placeholder="message..."
        size="30"
      />
      <button type="button">send</button>
    </span>
  )
}

export default Usergroup

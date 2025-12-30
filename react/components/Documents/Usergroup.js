import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import MessageBox from '../MessageBox'
import ConfirmModal from '../ConfirmModal'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
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
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false)

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

  // Handle leave group - called after user confirms in modal
  const handleLeaveGroup = async () => {
    setShowLeaveConfirm(false)
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/leave`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin'
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message })
        // Reload page after a brief delay to show the success message
        setTimeout(() => window.location.reload(), 1000)
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to leave group' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred: ' + error.message })
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
        <div
          className="usergroup-description content"
          dangerouslySetInnerHTML={{ __html: renderE2Content(doctext).html }}
        />
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
          <button
            type="button"
            onClick={() => setShowLeaveConfirm(true)}
            disabled={isSubmitting}
            title="leave this usergroup"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              padding: '8px 16px',
              fontSize: '13px',
              border: '1px solid #dc3545',
              borderRadius: '4px',
              backgroundColor: '#fff',
              color: '#dc3545',
              cursor: isSubmitting ? 'not-allowed' : 'pointer',
              opacity: isSubmitting ? 0.6 : 1
            }}
          >
            <FaSignOutAlt /> {isSubmitting ? 'Leaving...' : 'Leave group'}
          </button>
        </div>
      )}

      {/* Leave group confirmation modal */}
      <ConfirmModal
        isOpen={showLeaveConfirm}
        onClose={() => setShowLeaveConfirm(false)}
        onConfirm={handleLeaveGroup}
        title="Leave Usergroup"
        message={`Are you sure you want to leave ${usergroup.title}? You will no longer receive messages from this group.`}
        confirmText="Leave Group"
        cancelText="Cancel"
        confirmColor="#dc3545"
      />

      {/* Messaging interface */}
      {!isGuest && (
        <div className="usergroup-messaging">
          {hasMembers && (
            <>
              {/* Message to owner */}
              {owner && owner_index !== undefined && (
                <div className="msg-owner" style={{ marginBottom: '8px' }}>
                  <FaEnvelope style={{ marginRight: '6px' }} />
                  Message the group owner,{' '}
                  <LinkNode nodeId={owner.node_id} title={owner.title} />
                  {!is_in_group && <em> (they can add you to the group)</em>}
                  :{' '}
                  <MessageBox
                    recipientId={owner.node_id}
                    recipientTitle={owner.title}
                  />
                </div>
              )}

              {/* Message to leader (only if different from owner) */}
              {group[0] && (!owner || group[0].node_id !== owner.node_id) && (
                <div className="msg-leader" style={{ marginBottom: '8px' }}>
                  <FaEnvelope style={{ marginRight: '6px' }} />
                  Message the group leader,{' '}
                  <LinkNode nodeId={group[0].node_id} title={group[0].title} />
                  :{' '}
                  <MessageBox
                    recipientId={group[0].node_id}
                    recipientTitle={group[0].title}
                  />
                </div>
              )}
            </>
          )}

          {/* Message to usergroup (members and admins only) */}
          {(is_in_group || userData.is_admin) && (
            <div className="msg-usergroup" style={{ marginBottom: '8px' }}>
              {!is_in_group && userData.is_admin && (
                <p style={{ fontStyle: 'italic', fontSize: '12px', color: '#666' }}>
                  (You aren't in this group, but may message it as an administrator.)
                </p>
              )}
              <FaEnvelope style={{ marginRight: '6px' }} />
              Message the usergroup:{' '}
              <MessageBox
                recipientId={usergroup.node_id}
                recipientTitle={usergroup.title}
              />

              {/* Message count */}
              {message_count > 0 && (
                <p style={{ marginTop: '8px' }}>
                  <LinkNode
                    nodeId={e2.message_inbox_id || 956209}
                    title={`You have ${message_count} message${message_count === 1 ? '' : 's'} from this usergroup`}
                    queryParams={{ fromgroup: usergroup.title }}
                  />
                </p>
              )}
            </div>
          )}
        </div>
      )}

      {/* Weblog display - placeholder for legacy htmlcode('weblog') */}
      {/* TODO: Migrate weblog display to React */}
    </div>
  )
}

export default Usergroup

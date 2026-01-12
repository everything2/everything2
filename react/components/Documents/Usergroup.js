import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import MessageBox from '../MessageBox'
import ConfirmModal from '../ConfirmModal'
import Weblog from '../Weblog'
import UsergroupEditor from '../UsergroupEditor'
import UsergroupDescriptionEditor from '../UsergroupDescriptionEditor'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import { FaEnvelope, FaSignOutAlt, FaEdit, FaUsers, FaCog, FaComments } from 'react-icons/fa'

/**
 * Usergroup - Display page for usergroup nodes
 *
 * Modernized layout with:
 * - Clean card-based sections
 * - Inline description editor for owners/admins
 * - Member management via modal
 * - Improved messaging interface
 */
const Usergroup = ({ data, user, e2 }) => {
  const [message, setMessage] = useState(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [showLeaveConfirm, setShowLeaveConfirm] = useState(false)
  const [showMemberEditor, setShowMemberEditor] = useState(false)
  const [showDescriptionEditor, setShowDescriptionEditor] = useState(false)
  const [members, setMembers] = useState(null)
  const [currentDoctext, setCurrentDoctext] = useState(null)
  const [currentOwner, setCurrentOwner] = useState(null)

  if (!data || !data.usergroup) return null

  const {
    usergroup,
    user: userData,
    is_in_group,
    discussions_node_id,
    weblog_setting,
    message_count,
    owner_index,
    can_edit_members,
    weblog
  } = data

  // Use local members state if updated, otherwise use data from server
  const group = members || usergroup.group || []
  // Use local owner state if updated, otherwise use data from server
  const owner = currentOwner !== null ? currentOwner : usergroup.owner
  const doctext = currentDoctext !== null ? currentDoctext : usergroup.doctext
  const hasMembers = group.length > 0
  const isGuest = userData.is_guest

  // Handle member editor updates
  const handleMemberUpdate = (updatedData) => {
    if (updatedData?.group) {
      setMembers(updatedData.group)
    }
  }

  // Handle description save
  const handleDescriptionSave = (newDoctext) => {
    setCurrentDoctext(newDoctext)
    setShowDescriptionEditor(false)
    setMessage({ type: 'success', text: 'Description updated successfully' })
    setTimeout(() => setMessage(null), 3000)
  }

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

  // Handle owner change (editors only)
  const handleOwnerChange = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    const newLeader = e.target.new_leader.value.trim()
    if (!newLeader) {
      setMessage({ type: 'error', text: 'Please enter a username' })
      setIsSubmitting(false)
      return
    }

    try {
      // First, look up the user by username to get their node_id
      const lookupResponse = await fetch(`/api/users/lookup?username=${encodeURIComponent(newLeader)}`, {
        method: 'GET',
        credentials: 'same-origin'
      })
      const lookupResult = await lookupResponse.json()

      if (!lookupResult.success || !lookupResult.user_id) {
        setMessage({ type: 'error', text: lookupResult.error || `User "${newLeader}" not found` })
        setIsSubmitting(false)
        return
      }

      // Now call the transfer_ownership API
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/transfer_ownership`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ new_owner_id: lookupResult.user_id })
      })

      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message || 'Ownership transferred successfully' })
        // Update members list if returned (includes updated is_owner flags)
        if (result.group) {
          setMembers(result.group)
          // Find the new owner from the group and update owner state
          const newOwnerMember = result.group.find(m => m.is_owner)
          if (newOwnerMember) {
            setCurrentOwner({
              node_id: newOwnerMember.node_id,
              title: newOwnerMember.title
            })
          }
        }
        // Clear the form field
        e.target.new_leader.value = ''
        setTimeout(() => setMessage(null), 3000)
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to transfer ownership' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred: ' + error.message })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Handle weblog/ify settings (admins only)
  const [weblogSetting, setWeblogSetting] = useState(weblog_setting)
  const [isEditingIfy, setIsEditingIfy] = useState(false)

  const handleWeblogSettings = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    const ifyDisplay = e.target.ify_display.value.trim()
    if (!ifyDisplay) {
      setMessage({ type: 'error', text: 'Please enter a display name' })
      setIsSubmitting(false)
      return
    }

    try {
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/weblogify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ ify_display: ifyDisplay })
      })

      const result = await response.json()

      if (result.success) {
        setWeblogSetting(result.ify_display)
        setIsEditingIfy(false)
        setMessage({ type: 'success', text: result.message })
        setTimeout(() => setMessage(null), 3000)
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to update weblog settings' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred: ' + error.message })
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleRemoveIfy = async () => {
    if (!confirm('Are you sure you want to remove the weblog ify setting? This will clear the can_weblog flag from all members.')) {
      return
    }

    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/weblogify`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin'
      })

      const result = await response.json()

      if (result.success) {
        setWeblogSetting(null)
        setMessage({ type: 'success', text: result.message || 'Weblog ify setting removed' })
        setTimeout(() => setMessage(null), 3000)
      } else {
        setMessage({ type: 'error', text: result.error || 'Failed to remove weblog setting' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An error occurred: ' + error.message })
    } finally {
      setIsSubmitting(false)
    }
  }


  return (
    <div className="usergroup-container">
      {/* Status messages */}
      {message && (
        <div className={`usergroup-message usergroup-message--${message.type}`}>
          {message.text}
        </div>
      )}

      {/* Admin tools panel */}
      {!!userData.is_admin && (
        <div className="usergroup-admin-panel">
          <strong className="usergroup-admin-label"><FaCog /> Admin Tools:</strong>
          {weblogSetting && !isEditingIfy ? (
            <span>
              Weblog ify: <strong>{weblogSetting}</strong>
              <button
                type="button"
                onClick={() => setIsEditingIfy(true)}
                disabled={isSubmitting}
                className="usergroup-admin-btn"
              >
                Edit
              </button>
              <button
                type="button"
                onClick={handleRemoveIfy}
                disabled={isSubmitting}
                className="usergroup-admin-btn usergroup-admin-btn--danger"
              >
                Remove
              </button>
            </span>
          ) : (
            <form onSubmit={handleWeblogSettings} className="usergroup-admin-form">
              <span className="usergroup-admin-label">{weblogSetting ? 'Change' : 'Add'} weblog ify:</span>
              <input
                type="text"
                name="ify_display"
                placeholder="e.g. Edevify"
                defaultValue={isEditingIfy ? weblogSetting : ''}
                className="usergroup-admin-input"
              />
              <button type="submit" disabled={isSubmitting} className="usergroup-admin-submit">
                {weblogSetting ? 'Update' : 'Add'}
              </button>
              {isEditingIfy && (
                <button
                  type="button"
                  onClick={() => setIsEditingIfy(false)}
                  className="usergroup-admin-submit"
                >
                  Cancel
                </button>
              )}
            </form>
          )}
        </div>
      )}

      {/* Editor tools - owner change */}
      {!!userData.is_editor && (
        <div className="usergroup-admin-panel usergroup-admin-panel--editor">
          <form onSubmit={handleOwnerChange} className="usergroup-editor-form">
            <span>
              <strong>Owner:</strong>{' '}
              {owner ? <LinkNode id={owner.node_id} title={owner.title} /> : 'None'}
            </span>
            <span className="usergroup-editor-separator">|</span>
            <span>
              Change to:{' '}
              <input
                type="text"
                name="new_leader"
                placeholder="Username"
                className="usergroup-admin-input usergroup-admin-input--narrow"
              />
              <button type="submit" disabled={isSubmitting} className="usergroup-admin-submit">
                Set Owner
              </button>
            </span>
            <small className="usergroup-editor-note">
              Note: User must be a member before being set as owner.
            </small>
          </form>
        </div>
      )}

      {/* Description section */}
      <div className="usergroup-card">
        <div className="usergroup-card-header">
          <h3 className="usergroup-card-title">
            About this Group
          </h3>
          <div className="usergroup-header-actions">
            {/* Discussions link for members */}
            {!!is_in_group && !!discussions_node_id && (
              <LinkNode
                id={discussions_node_id}
                title="Discussions"
                params={{ show_ug: usergroup.node_id }}
              />
            )}
            {!!can_edit_members && !showDescriptionEditor && (
              <button
                type="button"
                onClick={() => setShowDescriptionEditor(true)}
                className="usergroup-edit-btn"
              >
                <FaEdit /> Edit
              </button>
            )}
          </div>
        </div>
        <div className="usergroup-card-body">
          {showDescriptionEditor ? (
            <UsergroupDescriptionEditor
              usergroupId={usergroup.node_id}
              initialContent={doctext || ''}
              onSave={handleDescriptionSave}
              onCancel={() => setShowDescriptionEditor(false)}
            />
          ) : (
            doctext ? (
              <div
                className="content"
                dangerouslySetInnerHTML={{ __html: renderE2Content(doctext).html }}
              />
            ) : (
              <p className="usergroup-empty">
                No description yet.
                {!!can_edit_members && ' Click Edit to add one.'}
              </p>
            )
          )}
        </div>
      </div>

      {/* Members section */}
      <div className="usergroup-card">
        <div className="usergroup-card-header">
          <h3 className="usergroup-card-title">
            <FaUsers /> Members ({group.length})
          </h3>
          {!!can_edit_members && (
            <button
              type="button"
              onClick={() => setShowMemberEditor(true)}
              className="usergroup-edit-btn"
            >
              <FaEdit /> Manage
            </button>
          )}
        </div>
        <div className="usergroup-card-body">
          {hasMembers ? (
            <>
              <div className="usergroup-member-list">
                {group.map((member, index) => {
                  let displayName = (
                    <LinkNode
                      key={member.node_id}
                      id={member.node_id}
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
                    <small className="usergroup-member-flags">
                      {member.flags}
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
              </div>
              <p className="usergroup-member-count">
                Led by{' '}
                {group[0] ? (
                  <strong><LinkNode id={group[0].node_id} title={group[0].title} /></strong>
                ) : (
                  'unknown'
                )}
                {owner && group[0] && owner.node_id !== group[0].node_id && (
                  <span> • Owned by <LinkNode id={owner.node_id} title={owner.title} /></span>
                )}
              </p>
            </>
          ) : (
            <p className="usergroup-empty">
              This group has no members yet.
            </p>
          )}
        </div>
      </div>

      {/* Actions section for members */}
      {!isGuest && is_in_group && (
        <div className="usergroup-actions">
          <button
            type="button"
            onClick={() => setShowLeaveConfirm(true)}
            disabled={isSubmitting}
            className="usergroup-danger-btn"
          >
            <FaSignOutAlt /> {isSubmitting ? 'Leaving...' : 'Leave Group'}
          </button>
        </div>
      )}

      {/* Messaging section */}
      {!isGuest && (
        <div className="usergroup-card">
          <div className="usergroup-card-header">
            <h3 className="usergroup-card-title">
              <FaComments /> Messaging
            </h3>
            {/* Message count badge */}
            {message_count > 0 && (
              <LinkNode
                id={e2.message_inbox_id || 956209}
                title={`${message_count} message${message_count === 1 ? '' : 's'}`}
                params={{ fromgroup: usergroup.title }}
              />
            )}
          </div>
          <div className="usergroup-card-body">
            {!is_in_group && userData.is_admin && (
              <p className="usergroup-empty" style={{ marginBottom: '12px' }}>
                You aren't in this group, but may message it as an administrator.
              </p>
            )}

            {/* Message the group */}
            {(is_in_group || userData.is_admin) && (
              <div className="usergroup-messaging-row">
                <FaEnvelope className="usergroup-messaging-icon" />
                <span>Message the group:</span>
                <MessageBox
                  recipientId={usergroup.node_id}
                  recipientTitle={usergroup.title}
                />
              </div>
            )}

            {/* Message the owner */}
            {hasMembers && owner && (
              <div className="usergroup-messaging-row">
                <FaEnvelope className="usergroup-messaging-icon" />
                <span>
                  Message the owner (<LinkNode id={owner.node_id} title={owner.title} />)
                  {!is_in_group && <em className="usergroup-empty"> — they can add you</em>}:
                </span>
                <MessageBox
                  recipientId={owner.node_id}
                  recipientTitle={owner.title}
                />
              </div>
            )}

            {/* Message the leader if different from owner */}
            {hasMembers && group[0] && (!owner || group[0].node_id !== owner.node_id) && (
              <div className="usergroup-messaging-row">
                <FaEnvelope className="usergroup-messaging-icon" />
                <span>
                  Message the leader (<LinkNode id={group[0].node_id} title={group[0].title} />):
                </span>
                <MessageBox
                  recipientId={group[0].node_id}
                  recipientTitle={group[0].title}
                />
              </div>
            )}
          </div>
        </div>
      )}

      {/* Weblog section */}
      {weblog && weblog.entries && weblog.entries.length > 0 && (
        <div className="usergroup-card">
          <div className="usergroup-card-header">
            <h3 className="usergroup-card-title">
              Recent Activity
            </h3>
          </div>
          <div className="usergroup-card-body">
            <Weblog weblog={weblog} />
          </div>
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

      {/* Member editor modal */}
      {!!can_edit_members && (
        <UsergroupEditor
          isOpen={showMemberEditor}
          onClose={() => setShowMemberEditor(false)}
          usergroup={{ ...usergroup, group }}
          onUpdate={handleMemberUpdate}
          currentUserId={userData.node_id}
        />
      )}
    </div>
  )
}

export default Usergroup

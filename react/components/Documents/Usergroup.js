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

  // Styles
  const styles = {
    container: {
      maxWidth: '900px',
      margin: '0 auto'
    },
    message: {
      padding: '12px 16px',
      borderRadius: '6px',
      marginBottom: '16px',
      fontSize: '14px'
    },
    messageSuccess: {
      backgroundColor: '#d4edda',
      border: '1px solid #c3e6cb',
      color: '#155724'
    },
    messageError: {
      backgroundColor: '#f8d7da',
      border: '1px solid #f5c6cb',
      color: '#721c24'
    },
    card: {
      backgroundColor: '#fff',
      border: '1px solid #dee2e6',
      borderRadius: '8px',
      marginBottom: '20px',
      overflow: 'hidden'
    },
    cardHeader: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      padding: '12px 16px',
      backgroundColor: '#f8f9fa',
      borderBottom: '1px solid #dee2e6'
    },
    cardTitle: {
      margin: 0,
      fontSize: '15px',
      fontWeight: '600',
      color: '#495057',
      display: 'flex',
      alignItems: 'center',
      gap: '8px'
    },
    cardBody: {
      padding: '16px'
    },
    editButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '4px',
      padding: '4px 10px',
      fontSize: '12px',
      border: '1px solid #6c757d',
      borderRadius: '4px',
      backgroundColor: '#fff',
      color: '#6c757d',
      cursor: 'pointer'
    },
    primaryButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      fontSize: '13px',
      border: '1px solid #007bff',
      borderRadius: '4px',
      backgroundColor: '#007bff',
      color: '#fff',
      cursor: 'pointer',
      fontWeight: '500'
    },
    dangerButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      fontSize: '13px',
      border: '1px solid #dc3545',
      borderRadius: '4px',
      backgroundColor: '#fff',
      color: '#dc3545',
      cursor: 'pointer'
    },
    memberList: {
      lineHeight: '1.8'
    },
    memberCount: {
      fontSize: '13px',
      color: '#6c757d',
      marginTop: '12px'
    },
    messagingRow: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      padding: '10px 0',
      borderBottom: '1px solid #eee'
    },
    adminPanel: {
      backgroundColor: '#fff3cd',
      border: '1px solid #ffeeba',
      borderRadius: '6px',
      padding: '12px 16px',
      marginBottom: '16px',
      fontSize: '13px'
    }
  }

  return (
    <div style={styles.container}>
      {/* Status messages */}
      {message && (
        <div style={{
          ...styles.message,
          ...(message.type === 'success' ? styles.messageSuccess : styles.messageError)
        }}>
          {message.text}
        </div>
      )}

      {/* Admin tools panel */}
      {!!userData.is_admin && (
        <div style={styles.adminPanel}>
          <strong style={{ marginRight: '8px' }}><FaCog /> Admin Tools:</strong>
          {weblogSetting && !isEditingIfy ? (
            <span>
              Weblog ify: <strong>{weblogSetting}</strong>
              <button
                type="button"
                onClick={() => setIsEditingIfy(true)}
                disabled={isSubmitting}
                style={{ padding: '2px 8px', fontSize: '11px', marginLeft: '8px' }}
              >
                Edit
              </button>
              <button
                type="button"
                onClick={handleRemoveIfy}
                disabled={isSubmitting}
                style={{ padding: '2px 8px', fontSize: '11px', marginLeft: '4px', color: '#dc3545' }}
              >
                Remove
              </button>
            </span>
          ) : (
            <form onSubmit={handleWeblogSettings} style={{ display: 'inline' }}>
              <span style={{ marginRight: '8px' }}>{weblogSetting ? 'Change' : 'Add'} weblog ify:</span>
              <input
                type="text"
                name="ify_display"
                placeholder="e.g. Edevify"
                defaultValue={isEditingIfy ? weblogSetting : ''}
                style={{ padding: '4px 8px', fontSize: '12px', borderRadius: '4px', border: '1px solid #ccc', marginRight: '8px' }}
              />
              <button type="submit" disabled={isSubmitting} style={{ padding: '4px 12px', fontSize: '12px' }}>
                {weblogSetting ? 'Update' : 'Add'}
              </button>
              {isEditingIfy && (
                <button
                  type="button"
                  onClick={() => setIsEditingIfy(false)}
                  style={{ padding: '4px 12px', fontSize: '12px', marginLeft: '4px' }}
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
        <div style={{ ...styles.adminPanel, backgroundColor: '#e7f3ff', borderColor: '#b8daff' }}>
          <form onSubmit={handleOwnerChange} style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
            <span>
              <strong>Owner:</strong>{' '}
              {owner ? <LinkNode id={owner.node_id} title={owner.title} /> : 'None'}
            </span>
            <span style={{ color: '#6c757d' }}>|</span>
            <span>
              Change to:{' '}
              <input
                type="text"
                name="new_leader"
                placeholder="Username"
                style={{ padding: '4px 8px', fontSize: '12px', borderRadius: '4px', border: '1px solid #ccc', width: '120px' }}
              />
              <button type="submit" disabled={isSubmitting} style={{ padding: '4px 12px', fontSize: '12px', marginLeft: '8px' }}>
                Set Owner
              </button>
            </span>
            <small style={{ color: '#6c757d', width: '100%' }}>
              Note: User must be a member before being set as owner.
            </small>
          </form>
        </div>
      )}

      {/* Description section */}
      <div style={styles.card}>
        <div style={styles.cardHeader}>
          <h3 style={styles.cardTitle}>
            About this Group
          </h3>
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
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
                style={styles.editButton}
              >
                <FaEdit /> Edit
              </button>
            )}
          </div>
        </div>
        <div style={styles.cardBody}>
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
              <p style={{ color: '#6c757d', fontStyle: 'italic', margin: 0 }}>
                No description yet.
                {!!can_edit_members && ' Click Edit to add one.'}
              </p>
            )
          )}
        </div>
      </div>

      {/* Members section */}
      <div style={styles.card}>
        <div style={styles.cardHeader}>
          <h3 style={styles.cardTitle}>
            <FaUsers /> Members ({group.length})
          </h3>
          {!!can_edit_members && (
            <button
              type="button"
              onClick={() => setShowMemberEditor(true)}
              style={styles.editButton}
            >
              <FaEdit /> Manage
            </button>
          )}
        </div>
        <div style={styles.cardBody}>
          {hasMembers ? (
            <>
              <div style={styles.memberList}>
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
                    <small style={{ color: '#6c757d', marginLeft: '2px' }}>
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
              <p style={styles.memberCount}>
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
            <p style={{ color: '#6c757d', fontStyle: 'italic', margin: 0 }}>
              This group has no members yet.
            </p>
          )}
        </div>
      </div>

      {/* Actions section for members */}
      {!isGuest && is_in_group && (
        <div style={{ marginBottom: '20px' }}>
          <button
            type="button"
            onClick={() => setShowLeaveConfirm(true)}
            disabled={isSubmitting}
            style={{
              ...styles.dangerButton,
              opacity: isSubmitting ? 0.6 : 1,
              cursor: isSubmitting ? 'not-allowed' : 'pointer'
            }}
          >
            <FaSignOutAlt /> {isSubmitting ? 'Leaving...' : 'Leave Group'}
          </button>
        </div>
      )}

      {/* Messaging section */}
      {!isGuest && (
        <div style={styles.card}>
          <div style={styles.cardHeader}>
            <h3 style={styles.cardTitle}>
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
          <div style={styles.cardBody}>
            {!is_in_group && userData.is_admin && (
              <p style={{ fontStyle: 'italic', fontSize: '12px', color: '#6c757d', marginBottom: '12px' }}>
                You aren't in this group, but may message it as an administrator.
              </p>
            )}

            {/* Message the group */}
            {(is_in_group || userData.is_admin) && (
              <div style={{ ...styles.messagingRow, borderBottom: hasMembers && owner ? '1px solid #eee' : 'none' }}>
                <FaEnvelope style={{ color: '#6c757d' }} />
                <span>Message the group:</span>
                <MessageBox
                  recipientId={usergroup.node_id}
                  recipientTitle={usergroup.title}
                />
              </div>
            )}

            {/* Message the owner */}
            {hasMembers && owner && (
              <div style={{ ...styles.messagingRow, borderBottom: 'none' }}>
                <FaEnvelope style={{ color: '#6c757d' }} />
                <span>
                  Message the owner (<LinkNode id={owner.node_id} title={owner.title} />)
                  {!is_in_group && <em style={{ fontSize: '12px', color: '#6c757d' }}> — they can add you</em>}:
                </span>
                <MessageBox
                  recipientId={owner.node_id}
                  recipientTitle={owner.title}
                />
              </div>
            )}

            {/* Message the leader if different from owner */}
            {hasMembers && group[0] && (!owner || group[0].node_id !== owner.node_id) && (
              <div style={{ ...styles.messagingRow, borderBottom: 'none' }}>
                <FaEnvelope style={{ color: '#6c757d' }} />
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
        <div style={styles.card}>
          <div style={styles.cardHeader}>
            <h3 style={styles.cardTitle}>
              Recent Activity
            </h3>
          </div>
          <div style={styles.cardBody}>
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

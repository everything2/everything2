import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import { FaUsers, FaLock, FaLockOpen, FaEdit, FaTrash, FaGlobe, FaShieldAlt, FaUser } from 'react-icons/fa'
import ConfirmActionModal from '../ConfirmActionModal'

/**
 * Collaboration - Display page for collaboration nodes
 *
 * Collaborations are private group documents with:
 * - Access control (admins, CEs, crtleads, and approved users/groups)
 * - Edit locking (15-minute auto-expire)
 * - Public/private toggle
 * Styles are in CSS classes (collab__*)
 */
const Collaboration = ({ data }) => {
  const [showDeleteModal, setShowDeleteModal] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)

  if (!data) return null

  const {
    collaboration,
    members,
    lockedby,
    can_access,
    can_edit,
    is_locked,
    is_locked_by_me,
    is_public,
    unlock_msg,
    user
  } = data

  const handleDelete = async () => {
    setIsDeleting(true)
    // Delete via the collaborations API (was op=nuke). #4335 Phase 2.
    try {
      const res = await fetch(`/api/collaborations/${collaboration.node_id}/action/delete`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Accept': 'application/json' },
      })
      const data = res.ok ? await res.json() : null
      if (data && data.success) {
        // Back to the collaboration index (E2 Collaboration Nodes superdoc)
        window.location.href = '/node/1256403'
        return
      }
    } catch (err) {
      // fall through to re-enable the control
    }
    setIsDeleting(false)
  }

  // Permission denied view
  if (!can_access && !is_public) {
    return (
      <div className="collab">
        <div className="collab__header">
          <FaShieldAlt className="collab__header-icon collab__header-icon--denied" />
          <h1 className="collab__title">{collaboration.title}</h1>
        </div>
        <div className="collab__permission-denied">
          <FaLock className="collab__permission-denied-icon" />
          <h3>Permission Denied</h3>
          <p>You do not have access to view this collaboration.</p>
          <p className="collab__permission-denied-help">
            Only administrators, content editors, crtleads members, and approved users can view this document.
          </p>
        </div>
      </div>
    )
  }

  // Public-only view (can see content but not members or edit)
  const showPublicOnly = !can_access && is_public

  const lockStatusClass = is_locked_by_me
    ? 'collab__lock-status collab__lock-status--mine'
    : 'collab__lock-status collab__lock-status--other'

  const lockIconClass = is_locked_by_me
    ? 'collab__lock-icon--mine'
    : 'collab__lock-icon--other'

  const lockTextClass = is_locked_by_me
    ? 'collab__lock-text--mine'
    : 'collab__lock-text--other'

  return (
    <div className="collab">
      {/* Header */}
      <div className="collab__header">
        <FaUsers className="collab__header-icon" />
        <div className="collab__header-info">
          <h1 className="collab__title">{collaboration.title}</h1>
          {is_public ? (
            <span className="collab__public-badge">
              <FaGlobe className="collab__icon-mr" />
              Public
            </span>
          ) : null}
        </div>
        {can_edit ? (
          <div className="collab__actions">
            <a
              href={`/?node_id=${collaboration.node_id}&displaytype=useredit`}
              className="collab__edit-link"
            >
              <FaEdit className="collab__icon-mr" />
              edit
            </a>
            {is_locked && is_locked_by_me ? (
              <a
                href={`/?node_id=${collaboration.node_id}&unlock=true`}
                className="collab__unlock-link"
              >
                <FaLockOpen className="collab__icon-mr" />
                unlock
              </a>
            ) : null}
            {user.is_admin ? (
              <button
                onClick={() => setShowDeleteModal(true)}
                className="collab__delete-btn"
              >
                <FaTrash className="collab__icon-mr" />
                delete
              </button>
            ) : null}
          </div>
        ) : null}
      </div>

      {/* Unlock message */}
      {unlock_msg && (
        <div className="collab__unlock-message">
          {unlock_msg}
        </div>
      )}

      {/* Lock status */}
      {is_locked && can_access ? (
        <div className={lockStatusClass}>
          <FaLock className={lockIconClass} />
          <span className={lockTextClass}>
            {is_locked_by_me ? (
              <>Locked by you</>
            ) : (
              <>Locked by <LinkNode {...lockedby} type="user" /></>
            )}
          </span>
          {!is_locked_by_me && (user.is_admin || user.is_editor) ? (
            <a
              href={`/?node_id=${collaboration.node_id}&displaytype=useredit`}
              className="collab__force-edit"
            >
              (force edit - will take over lock)
            </a>
          ) : null}
        </div>
      ) : null}

      {/* Author info */}
      {collaboration.author && (
        <div className="collab__meta">
          <FaUser className="collab__meta-icon" />
          Created by: <LinkNode {...collaboration.author} type="user" />
          {collaboration.createtime && (
            <span className="collab__createtime"> on {collaboration.createtime}</span>
          )}
        </div>
      )}

      {/* Members section - only shown to those with access */}
      {!showPublicOnly && members && members.length > 0 && (
        <div className="collab__members-section">
          <h3 className="collab__section-title">
            <FaUsers className="collab__icon-mr-lg" />
            Allowed Users/Groups
          </h3>
          <div className="collab__members-list">
            {members.map(member => (
              <span key={member.node_id} className="collab__member-chip">
                <LinkNode {...member} type={member.type} />
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Content */}
      {collaboration.doctext ? (
        <div className="collab__content">
          <div
            className="collab__doctext"
            dangerouslySetInnerHTML={{ __html: renderE2Content(collaboration.doctext).html }}
          />
        </div>
      ) : (
        <div className="collab__empty-content">
          <p>This collaboration has no content yet.</p>
          {can_edit ? (
            <a href={`/?node_id=${collaboration.node_id}&displaytype=useredit`}>
              Add content
            </a>
          ) : null}
        </div>
      )}

      {/* Delete confirmation modal */}
      <ConfirmActionModal
        isOpen={showDeleteModal}
        onClose={() => setShowDeleteModal(false)}
        onConfirm={handleDelete}
        title="Delete Collaboration"
        message={`Do you really want to delete this collaboration "${collaboration.title}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmStyle="danger"
        isSubmitting={isDeleting}
      />
    </div>
  )
}

export default Collaboration

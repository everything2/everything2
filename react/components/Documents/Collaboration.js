import React from 'react'
import LinkNode from '../LinkNode'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import { FaUsers, FaLock, FaLockOpen, FaEdit, FaTrash, FaGlobe, FaShieldAlt, FaUser } from 'react-icons/fa'

/**
 * Collaboration - Display page for collaboration nodes
 *
 * Collaborations are private group documents with:
 * - Access control (admins, CEs, crtleads, and approved users/groups)
 * - Edit locking (15-minute auto-expire)
 * - Public/private toggle
 */
const Collaboration = ({ data }) => {
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

  // Permission denied view
  if (!can_access && !is_public) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <FaShieldAlt style={{ color: '#dc3545', marginRight: 8, fontSize: 24 }} />
          <h1 style={styles.title}>{collaboration.title}</h1>
        </div>
        <div style={styles.permissionDenied}>
          <FaLock style={{ fontSize: 48, color: '#6c757d', marginBottom: 16 }} />
          <h3>Permission Denied</h3>
          <p>You do not have access to view this collaboration.</p>
          <p style={{ fontSize: 13, color: '#666' }}>
            Only administrators, content editors, crtleads members, and approved users can view this document.
          </p>
        </div>
      </div>
    )
  }

  // Public-only view (can see content but not members or edit)
  const showPublicOnly = !can_access && is_public

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <FaUsers style={{ color: '#507898', marginRight: 8, fontSize: 24 }} />
        <div style={styles.headerInfo}>
          <h1 style={styles.title}>{collaboration.title}</h1>
          {is_public ? (
            <span style={styles.publicBadge}>
              <FaGlobe style={{ marginRight: 4 }} />
              Public
            </span>
          ) : null}
        </div>
        {can_edit ? (
          <div style={styles.actions}>
            <a
              href={`/?node_id=${collaboration.node_id}&displaytype=useredit`}
              style={styles.editLink}
            >
              <FaEdit style={{ marginRight: 4 }} />
              edit
            </a>
            {is_locked && is_locked_by_me ? (
              <a
                href={`/?node_id=${collaboration.node_id}&unlock=true`}
                style={styles.unlockLink}
              >
                <FaLockOpen style={{ marginRight: 4 }} />
                unlock
              </a>
            ) : null}
            {user.is_admin ? (
              <a
                href={`/?node_id=${collaboration.node_id}&confirmop=nuke`}
                style={styles.deleteLink}
              >
                <FaTrash style={{ marginRight: 4 }} />
                delete
              </a>
            ) : null}
          </div>
        ) : null}
      </div>

      {/* Unlock message */}
      {unlock_msg && (
        <div style={styles.unlockMessage}>
          {unlock_msg}
        </div>
      )}

      {/* Lock status */}
      {is_locked && can_access ? (
        <div style={{
          ...styles.lockStatus,
          backgroundColor: is_locked_by_me ? '#d4edda' : '#fff3cd',
          borderColor: is_locked_by_me ? '#c3e6cb' : '#ffeeba'
        }}>
          <FaLock style={{ marginRight: 8, color: is_locked_by_me ? '#155724' : '#856404' }} />
          <span style={{ color: is_locked_by_me ? '#155724' : '#856404' }}>
            {is_locked_by_me ? (
              <>Locked by you</>
            ) : (
              <>Locked by <LinkNode {...lockedby} type="user" /></>
            )}
          </span>
          {!is_locked_by_me && (user.is_admin || user.is_editor) ? (
            <a
              href={`/?node_id=${collaboration.node_id}&displaytype=useredit`}
              style={{ marginLeft: 12, fontSize: 13, color: '#4060b0' }}
            >
              (force edit - will take over lock)
            </a>
          ) : null}
        </div>
      ) : null}

      {/* Author info */}
      {collaboration.author && (
        <div style={styles.meta}>
          <FaUser style={{ marginRight: 6, color: '#507898' }} />
          Created by: <LinkNode {...collaboration.author} type="user" />
          {collaboration.createtime && (
            <span style={styles.createtime}> on {collaboration.createtime}</span>
          )}
        </div>
      )}

      {/* Members section - only shown to those with access */}
      {!showPublicOnly && members && members.length > 0 && (
        <div style={styles.membersSection}>
          <h3 style={styles.sectionTitle}>
            <FaUsers style={{ marginRight: 8 }} />
            Allowed Users/Groups
          </h3>
          <div style={styles.membersList}>
            {members.map(member => (
              <span key={member.node_id} style={styles.memberChip}>
                <LinkNode {...member} type={member.type} />
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Content */}
      {collaboration.doctext ? (
        <div style={styles.content}>
          <div
            style={styles.doctext}
            dangerouslySetInnerHTML={{ __html: renderE2Content(collaboration.doctext).html }}
          />
        </div>
      ) : (
        <div style={styles.emptyContent}>
          <p>This collaboration has no content yet.</p>
          {can_edit ? (
            <a href={`/?node_id=${collaboration.node_id}&displaytype=useredit`}>
              Add content
            </a>
          ) : null}
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    maxWidth: 800,
    margin: '0 auto',
    padding: '16px 0'
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: 16,
    paddingBottom: 16,
    borderBottom: '2px solid #38495e',
    flexWrap: 'wrap',
    gap: 8
  },
  headerInfo: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    minWidth: 200
  },
  title: {
    margin: 0,
    fontSize: 24,
    fontWeight: 'bold',
    color: '#38495e'
  },
  publicBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    fontSize: 12,
    color: '#155724',
    backgroundColor: '#d4edda',
    padding: '2px 8px',
    borderRadius: 4
  },
  actions: {
    display: 'flex',
    gap: 12,
    alignItems: 'center'
  },
  editLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  unlockLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#28a745',
    textDecoration: 'none'
  },
  deleteLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#dc3545',
    textDecoration: 'none'
  },
  unlockMessage: {
    padding: 12,
    marginBottom: 16,
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: 4,
    color: '#155724'
  },
  lockStatus: {
    display: 'flex',
    alignItems: 'center',
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
    border: '1px solid'
  },
  meta: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#38495e',
    marginBottom: 20
  },
  createtime: {
    color: '#666',
    marginLeft: 4
  },
  membersSection: {
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    padding: 16,
    marginBottom: 20
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    fontWeight: 'bold',
    color: '#38495e',
    marginTop: 0,
    marginBottom: 12
  },
  membersList: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: 8
  },
  memberChip: {
    display: 'inline-block',
    backgroundColor: '#e8f4f8',
    padding: '4px 10px',
    borderRadius: 4,
    fontSize: 13
  },
  content: {
    marginTop: 20
  },
  doctext: {
    lineHeight: 1.6,
    color: '#333'
  },
  emptyContent: {
    padding: 20,
    textAlign: 'center',
    color: '#666',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  permissionDenied: {
    padding: 40,
    textAlign: 'center',
    color: '#666',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  }
}

export default Collaboration

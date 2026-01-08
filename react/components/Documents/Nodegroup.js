import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import NodegroupEditor from '../NodegroupEditor'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import { getNodeTypeIcon, getNodeTypeIconStyle } from '../../utils/nodeTypeIcons'
import { FaEdit, FaFolder } from 'react-icons/fa'

/**
 * Nodegroup - Display page for nodegroup nodes
 *
 * Nodegroups are generic containers for any node type.
 * Only admins can edit them.
 *
 * Features:
 * - Display list of members with type-specific icons
 * - Admin-only editing via modal
 * - Type and author info for each member
 */
const Nodegroup = ({ data, user, e2 }) => {
  const [showEditor, setShowEditor] = useState(false)
  const [members, setMembers] = useState(null)
  const [message, setMessage] = useState(null)

  if (!data || !data.nodegroup) return null

  const {
    nodegroup,
    user: userData,
    can_edit
  } = data

  // Use local members state if updated, otherwise use data from server
  const group = members || nodegroup.group || []
  const hasMembers = group.length > 0

  // Handle member editor updates
  const handleMemberUpdate = (updatedData) => {
    if (updatedData?.group) {
      setMembers(updatedData.group)
      setMessage({ type: 'success', text: 'Members updated successfully' })
      setTimeout(() => setMessage(null), 3000)
    }
  }

  // Styles
  const styles = {
    container: {
      maxWidth: '800px',
      margin: '0 auto'
    },
    header: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: '16px'
    },
    title: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      fontSize: '18px',
      fontWeight: 'bold',
      color: '#38495e'
    },
    editButton: {
      display: 'flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      backgroundColor: '#4060b0',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      cursor: 'pointer',
      fontSize: '14px'
    },
    description: {
      backgroundColor: '#f8f9fa',
      padding: '16px',
      borderRadius: '4px',
      marginBottom: '20px',
      borderLeft: '3px solid #4060b0'
    },
    memberCount: {
      fontSize: '14px',
      color: '#666',
      marginBottom: '12px'
    },
    memberList: {
      listStyle: 'none',
      padding: 0,
      margin: 0
    },
    memberItem: {
      display: 'flex',
      alignItems: 'center',
      padding: '10px 12px',
      borderBottom: '1px solid #eee',
      backgroundColor: '#fff'
    },
    memberIcon: {
      marginRight: '10px',
      width: '20px',
      textAlign: 'center'
    },
    memberInfo: {
      flex: 1
    },
    memberTitle: {
      fontWeight: '500'
    },
    memberMeta: {
      fontSize: '12px',
      color: '#666',
      marginTop: '2px'
    },
    typeLabel: {
      display: 'inline-block',
      padding: '2px 6px',
      backgroundColor: '#e8f4f8',
      color: '#507898',
      borderRadius: '3px',
      fontSize: '11px',
      marginLeft: '8px'
    },
    emptyState: {
      textAlign: 'center',
      padding: '40px 20px',
      color: '#666',
      fontStyle: 'italic'
    },
    message: {
      padding: '12px 16px',
      marginBottom: '16px',
      borderRadius: '4px',
      fontSize: '14px'
    }
  }

  return (
    <div style={styles.container}>
      {/* Header with edit button */}
      <div style={styles.header}>
        <div style={styles.title}>
          <FaFolder style={{ color: '#507898' }} />
          {nodegroup.title}
        </div>
        {can_edit && (
          <button
            onClick={() => setShowEditor(true)}
            style={styles.editButton}
          >
            <FaEdit /> Edit Members
          </button>
        )}
      </div>

      {/* Message */}
      {message && (
        <div style={{
          ...styles.message,
          backgroundColor: message.type === 'error' ? '#fee' : '#efe',
          color: message.type === 'error' ? '#c00' : '#060'
        }}>
          {message.text}
        </div>
      )}

      {/* Description */}
      {nodegroup.doctext && (
        <div
          style={styles.description}
          dangerouslySetInnerHTML={{
            __html: renderE2Content(nodegroup.doctext)
          }}
        />
      )}

      {/* Member count */}
      <div style={styles.memberCount}>
        {hasMembers
          ? `${group.length} member${group.length !== 1 ? 's' : ''}`
          : 'No members'}
      </div>

      {/* Member list */}
      {hasMembers ? (
        <ul style={styles.memberList}>
          {group.map((member) => (
            <li key={member.node_id} style={styles.memberItem}>
              <span style={{ ...styles.memberIcon, ...getNodeTypeIconStyle(member.type) }}>
                {getNodeTypeIcon(member.type, { size: 16 })}
              </span>
              <div style={styles.memberInfo}>
                <span style={styles.memberTitle}>
                  <LinkNode nodeId={member.node_id} title={member.title} />
                </span>
                <span style={styles.typeLabel}>{member.type}</span>
                {member.author && (
                  <div style={styles.memberMeta}>
                    by <LinkNode nodeId={member.author.node_id} title={member.author.title} />
                  </div>
                )}
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <div style={styles.emptyState}>
          This nodegroup is empty.
          {can_edit && ' Click "Edit Members" to add nodes.'}
        </div>
      )}

      {/* Member Editor Modal */}
      <NodegroupEditor
        isOpen={showEditor}
        onClose={() => setShowEditor(false)}
        nodegroup={{
          node_id: nodegroup.node_id,
          title: nodegroup.title,
          group: group
        }}
        onUpdate={handleMemberUpdate}
      />
    </div>
  )
}

export default Nodegroup

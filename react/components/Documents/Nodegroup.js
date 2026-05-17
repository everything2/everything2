import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import NodegroupEditor from '../NodegroupEditor'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import { getNodeTypeIcon, getNodeTypeIconStyle } from '../../utils/nodeTypeIcons'
import { FaEdit, FaFolder } from 'react-icons/fa'

/**
 * Nodegroup - Display page for nodegroup nodes
 * Styles in CSS: .nodegroup__*
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

  return (
    <div className="nodegroup">
      {/* Header with edit button */}
      <div className="nodegroup__header">
        <div className="nodegroup__title">
          <FaFolder className="nodegroup__title-icon" />
          {nodegroup.title}
        </div>
        {can_edit && (
          <button
            onClick={() => setShowEditor(true)}
            className="nodegroup__edit-button"
          >
            <FaEdit /> Edit Members
          </button>
        )}
      </div>

      {/* Message */}
      {message && (
        <div className={`nodegroup__message nodegroup__message--${message.type}`}>
          {message.text}
        </div>
      )}

      {/* Description */}
      {nodegroup.doctext && (
        <div
          className="nodegroup__description"
          dangerouslySetInnerHTML={{
            __html: renderE2Content(nodegroup.doctext)
          }}
        />
      )}

      {/* Member count */}
      <div className="nodegroup__member-count">
        {hasMembers
          ? `${group.length} member${group.length !== 1 ? 's' : ''}`
          : 'No members'}
      </div>

      {/* Member list */}
      {hasMembers ? (
        <ul className="nodegroup__member-list">
          {group.map((member) => (
            <li key={member.node_id} className="nodegroup__member-item">
              <span className="nodegroup__member-icon" style={getNodeTypeIconStyle(member.type)}>
                {getNodeTypeIcon(member.type, { size: 16 })}
              </span>
              <div className="nodegroup__member-info">
                <span className="nodegroup__member-title">
                  <LinkNode nodeId={member.node_id} title={member.title} />
                </span>
                <span className="nodegroup__type-label">{member.type}</span>
                {member.author && (
                  <div className="nodegroup__member-meta">
                    by <LinkNode nodeId={member.author.node_id} title={member.author.title} />
                  </div>
                )}
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <div className="nodegroup__empty-state">
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

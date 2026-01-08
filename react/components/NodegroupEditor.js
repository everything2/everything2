import React, { useState, useEffect } from 'react'
import LinkNode from './LinkNode'
import { GroupEditorModal, styles } from './GroupEditorBase'
import { getNodeTypeIcon, getNodeTypeIconStyle } from '../utils/nodeTypeIcons'
import { FaFolder } from 'react-icons/fa'

/**
 * NodegroupEditor - Modal for managing nodegroup members
 *
 * Unlike UsergroupEditor, this:
 * - Allows ANY node type (not just users/usergroups)
 * - Uses nodegroup_addable search scope
 * - Displays type-specific icons for each member
 * - Admin-only (no owner concept)
 *
 * Usage:
 *   <NodegroupEditor
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *     nodegroup={{ node_id, title, group: [...] }}
 *     onUpdate={(updatedData) => { ... }}
 *   />
 */
const NodegroupEditor = ({ isOpen, onClose, nodegroup, onUpdate }) => {
  const [members, setMembers] = useState([])
  const [message, setMessage] = useState(null)

  // Initialize members when modal opens
  useEffect(() => {
    if (isOpen && nodegroup?.group) {
      setMembers(nodegroup.group.map(m => ({
        node_id: m.node_id,
        title: m.title,
        type: m.type || 'node',
        author: m.author || null
      })))
      setMessage(null)
    }
  }, [isOpen, nodegroup])

  if (!isOpen || !nodegroup) return null

  // Search for any node type
  const handleSearch = async (query) => {
    const response = await fetch(
      `/api/node_search?q=${encodeURIComponent(query)}&scope=nodegroup_addable&group_id=${nodegroup.node_id}`
    )
    const data = await response.json()
    return data.success ? data.results : []
  }

  // Add a member
  const handleAdd = async (item) => {
    const response = await fetch(`/api/nodegroups/${nodegroup.node_id}/action/addnode`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ node_ids: [item.node_id] })
    })
    const data = await response.json()

    if (data.success && data.group) {
      setMembers(data.group)
      if (onUpdate) onUpdate(data)
    } else if (data.error) {
      throw new Error(data.error)
    }
  }

  // Remove a member
  const handleRemove = async (member) => {
    const response = await fetch(`/api/nodegroups/${nodegroup.node_id}/action/removenode`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ node_ids: [member.node_id] })
    })
    const data = await response.json()

    if (data.success && data.group) {
      setMembers(data.group)
      if (onUpdate) onUpdate(data)
    } else if (data.error) {
      throw new Error(data.error)
    }
  }

  // Save reordering
  const handleSaveOrder = async (newOrder) => {
    const response = await fetch(`/api/nodegroups/${nodegroup.node_id}/action/reorder`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newOrder)
    })
    const data = await response.json()

    if (data.success) {
      if (onUpdate) onUpdate(data)
    } else {
      throw new Error(data.error || 'Failed to save order')
    }
  }

  // Render search result with type icon
  const renderSearchResult = (result) => (
    <>
      <span style={{ ...styles.typeIcon, ...getNodeTypeIconStyle(result.type) }}>
        {getNodeTypeIcon(result.type, { size: 14 })}
      </span>
      <span style={styles.resultTitle}>{result.title}</span>
      <span style={styles.resultType}>{result.type}</span>
    </>
  )

  // Render member content with type icon and author
  const renderMemberContent = (member) => (
    <>
      <span style={{ ...styles.typeIcon, ...getNodeTypeIconStyle(member.type) }}>
        {getNodeTypeIcon(member.type, { size: 14 })}
      </span>
      <div style={styles.memberDetails}>
        <LinkNode nodeId={member.node_id} title={member.title} />
        <span style={styles.typeLabel}>{member.type}</span>
        {member.author && (
          <span style={styles.authorInfo}>
            by <LinkNode nodeId={member.author.node_id} title={member.author.title} />
          </span>
        )}
      </div>
    </>
  )

  return (
    <GroupEditorModal
      isOpen={isOpen}
      onClose={onClose}
      title={`Edit: ${nodegroup.title}`}
      headerIcon={<FaFolder style={{ marginRight: '8px', color: '#507898' }} />}
      searchPlaceholder="Search for any node..."
      addLabel="Add Node"
      helpText="Drag members to reorder. Search for any node type to add."
      members={members}
      setMembers={setMembers}
      onSaveOrder={handleSaveOrder}
      renderMemberContent={renderMemberContent}
      onSearch={handleSearch}
      onAdd={handleAdd}
      onRemove={handleRemove}
      renderSearchResult={renderSearchResult}
      message={message}
      setMessage={setMessage}
    />
  )
}

export default NodegroupEditor

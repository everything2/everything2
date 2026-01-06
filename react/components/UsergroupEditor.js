import React, { useState, useCallback, useRef, useEffect } from 'react'
import LinkNode from './LinkNode'
import { FaTimes, FaGripVertical, FaPlus, FaSearch, FaUser, FaUsers, FaSave, FaExchangeAlt } from 'react-icons/fa'

/**
 * UsergroupEditor - Modal for managing usergroup members
 *
 * Allows admins/owners to:
 * - Add users or subgroups
 * - Remove members
 * - Reorder members via drag-and-drop
 *
 * Usage:
 *   <UsergroupEditor
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *     usergroup={{ node_id, title, group: [...] }}
 *     onUpdate={(updatedGroup) => { ... }}
 *   />
 */
const UsergroupEditor = ({ isOpen, onClose, usergroup, onUpdate, currentUserId }) => {
  const [members, setMembers] = useState([])
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState([])
  const [isSearching, setIsSearching] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [message, setMessage] = useState(null)
  const [draggedIndex, setDraggedIndex] = useState(null)
  const [dragOverIndex, setDragOverIndex] = useState(null)
  const [hasChanges, setHasChanges] = useState(false)
  const [showTransferModal, setShowTransferModal] = useState(false)
  const [isTransferring, setIsTransferring] = useState(false)
  const searchTimeoutRef = useRef(null)
  const searchInputRef = useRef(null)

  // Check if current user is the owner
  const currentUserIsOwner = members.some(m => m.is_owner && m.node_id === currentUserId)

  // Initialize members when modal opens
  useEffect(() => {
    if (isOpen && usergroup?.group) {
      setMembers(usergroup.group.map(m => ({
        node_id: m.node_id,
        title: m.title,
        type: m.type || 'user',
        is_owner: m.is_owner || false,
        flags: m.flags || ''
      })))
      setHasChanges(false)
      setMessage(null)
      setSearchQuery('')
      setSearchResults([])
    }
  }, [isOpen, usergroup])

  if (!isOpen || !usergroup) return null

  // Handle search for users/usergroups
  const handleSearch = async (query) => {
    setSearchQuery(query)

    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }

    if (query.length < 2) {
      setSearchResults([])
      return
    }

    searchTimeoutRef.current = setTimeout(async () => {
      setIsSearching(true)
      try {
        // Use unified node_search API with group_addable scope to exclude current members
        const response = await fetch(
          `/api/node_search?q=${encodeURIComponent(query)}&scope=group_addable&group_id=${usergroup.node_id}`
        )
        const data = await response.json()
        if (data.success) {
          // Filter out any that are already in our current local members list
          // (in case of recently added members not yet persisted)
          const currentIds = new Set(members.map(m => m.node_id))
          setSearchResults(data.results.filter(r => !currentIds.has(r.node_id)))
        }
      } catch (error) {
        console.error('Search failed:', error)
      } finally {
        setIsSearching(false)
      }
    }, 300)
  }

  // Add a member
  const handleAdd = async (item) => {
    setMessage(null)

    try {
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/adduser`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify([item.node_id])
      })
      const data = await response.json()

      if (data.group) {
        // Add to local state
        setMembers(prev => [...prev, {
          node_id: item.node_id,
          title: item.title,
          type: item.type,
          is_owner: false,
          flags: ''
        }])

        // Clear from search results
        setSearchResults(prev => prev.filter(r => r.node_id !== item.node_id))
        setSearchQuery('')
        setMessage({ type: 'success', text: `Added ${item.title}` })

        // Notify parent
        if (onUpdate) onUpdate(data)
      } else if (data.error) {
        setMessage({ type: 'error', text: data.error })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to add member: ' + error.message })
    }
  }

  // Remove a member
  const handleRemove = async (member) => {
    if (member.is_owner) {
      setMessage({ type: 'error', text: 'Cannot remove the group owner. Transfer ownership first.' })
      return
    }

    setMessage(null)

    try {
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/removeuser`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify([member.node_id])
      })
      const data = await response.json()

      if (data.group) {
        setMembers(prev => prev.filter(m => m.node_id !== member.node_id))
        setMessage({ type: 'success', text: `Removed ${member.title}` })

        // Notify parent
        if (onUpdate) onUpdate(data)
      } else if (data.error) {
        setMessage({ type: 'error', text: data.error })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to remove member: ' + error.message })
    }
  }

  // Drag and drop handlers
  const handleDragStart = (e, index) => {
    setDraggedIndex(index)
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', index)
    // Add a slight delay to allow the drag image to be set
    setTimeout(() => {
      e.target.style.opacity = '0.5'
    }, 0)
  }

  const handleDragEnd = (e) => {
    e.target.style.opacity = '1'
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  const handleDragOver = (e, index) => {
    e.preventDefault()
    if (e.dataTransfer) {
      e.dataTransfer.dropEffect = 'move'
    }
    if (dragOverIndex !== index) {
      setDragOverIndex(index)
    }
  }

  const handleDragLeave = () => {
    setDragOverIndex(null)
  }

  const handleDrop = (e, dropIndex) => {
    e.preventDefault()
    const dragIndex = draggedIndex

    if (dragIndex === null || dragIndex === dropIndex) {
      setDraggedIndex(null)
      setDragOverIndex(null)
      return
    }

    const newMembers = [...members]
    const [draggedMember] = newMembers.splice(dragIndex, 1)
    newMembers.splice(dropIndex, 0, draggedMember)

    setMembers(newMembers)
    setHasChanges(true)
    setDraggedIndex(null)
    setDragOverIndex(null)
  }

  // Transfer ownership to another member
  const handleTransferOwnership = async (newOwnerId) => {
    setIsTransferring(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/transfer_ownership`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ new_owner_id: newOwnerId })
      })
      const data = await response.json()

      if (data.success) {
        // Update local members list to reflect new ownership
        setMembers(prev => prev.map(m => ({
          ...m,
          is_owner: m.node_id === newOwnerId
        })))
        setShowTransferModal(false)
        setMessage({ type: 'success', text: data.message || 'Ownership transferred successfully' })

        // Notify parent
        if (onUpdate) onUpdate(data)
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to transfer ownership' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to transfer ownership: ' + error.message })
    } finally {
      setIsTransferring(false)
    }
  }

  // Save reordering
  const handleSaveOrder = async () => {
    setIsSaving(true)
    setMessage(null)

    try {
      const newOrder = members.map(m => m.node_id)
      const response = await fetch(`/api/usergroups/${usergroup.node_id}/action/reorder`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newOrder)
      })
      const data = await response.json()

      if (data.success) {
        setHasChanges(false)
        setMessage({ type: 'success', text: 'Order saved' })
        if (onUpdate) onUpdate(data.group)
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to save order' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Failed to save order: ' + error.message })
    } finally {
      setIsSaving(false)
    }
  }

  // Close handler with unsaved changes warning
  const handleClose = () => {
    if (hasChanges) {
      if (window.confirm('You have unsaved changes to the member order. Close anyway?')) {
        onClose()
      }
    } else {
      onClose()
    }
  }

  return (
    <div style={styles.backdrop}>
      <div style={styles.modal}>
        {/* Header */}
        <div style={styles.header}>
          <h3 style={styles.title}>
            Edit Members: {usergroup.title}
          </h3>
          <button onClick={handleClose} style={styles.closeButton}>&times;</button>
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

        {/* Search to add */}
        <div style={styles.searchSection}>
          <div style={styles.searchHeader}>
            <FaPlus style={{ marginRight: '6px' }} />
            Add Member
          </div>
          <div style={styles.searchInputWrapper}>
            <FaSearch style={styles.searchIcon} />
            <input
              ref={searchInputRef}
              type="text"
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder="Search for users or usergroups..."
              style={styles.searchInput}
            />
            {isSearching && <span style={styles.searchingText}>Searching...</span>}
          </div>

          {/* Search results */}
          {searchResults.length > 0 && (
            <div style={styles.searchResults}>
              {searchResults.map((result) => (
                <div
                  key={result.node_id}
                  style={styles.searchResult}
                  onClick={() => handleAdd(result)}
                >
                  {result.type === 'user' ? (
                    <FaUser style={styles.typeIcon} />
                  ) : (
                    <FaUsers style={styles.typeIcon} />
                  )}
                  <span style={styles.resultTitle}>{result.title}</span>
                  <span style={styles.resultType}>{result.type}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Member list */}
        <div style={styles.memberSection}>
          <div style={styles.memberHeader}>
            <span>Members ({members.length})</span>
            {hasChanges && (
              <button
                onClick={handleSaveOrder}
                disabled={isSaving}
                style={styles.saveButton}
              >
                <FaSave style={{ marginRight: '4px' }} />
                {isSaving ? 'Saving...' : 'Save Order'}
              </button>
            )}
          </div>

          <div style={styles.memberList}>
            {members.length === 0 ? (
              <div style={styles.emptyState}>No members in this group</div>
            ) : (
              members.map((member, index) => (
                <div
                  key={member.node_id}
                  draggable
                  onDragStart={(e) => handleDragStart(e, index)}
                  onDragEnd={handleDragEnd}
                  onDragOver={(e) => handleDragOver(e, index)}
                  onDragLeave={handleDragLeave}
                  onDrop={(e) => handleDrop(e, index)}
                  style={{
                    ...styles.memberItem,
                    ...(dragOverIndex === index ? styles.memberItemDragOver : {}),
                    ...(draggedIndex === index ? styles.memberItemDragging : {})
                  }}
                >
                  <FaGripVertical style={styles.dragHandle} title="Drag to reorder" />

                  <div style={styles.memberInfo}>
                    {member.type === 'usergroup' ? (
                      <FaUsers style={styles.memberTypeIcon} />
                    ) : (
                      <FaUser style={styles.memberTypeIcon} />
                    )}
                    <LinkNode nodeId={member.node_id} title={member.title} />
                    {member.flags && (
                      <small style={styles.memberFlags}>{member.flags}</small>
                    )}
                    {member.is_owner && (
                      <span style={styles.ownerBadge}>owner</span>
                    )}
                  </div>

                  {/* Show Change Owner button for the owner row if current user is owner */}
                  {member.is_owner && currentUserIsOwner && members.filter(m => m.type !== 'usergroup').length > 1 && (
                    <button
                      onClick={() => setShowTransferModal(true)}
                      style={styles.changeOwnerButton}
                      title="Transfer ownership to another member"
                    >
                      <FaExchangeAlt style={{ marginRight: '4px' }} />
                      Change Owner
                    </button>
                  )}

                  <button
                    onClick={() => handleRemove(member)}
                    style={styles.removeButton}
                    title={member.is_owner ? 'Cannot remove owner' : 'Remove member'}
                    disabled={member.is_owner}
                  >
                    <FaTimes />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Footer */}
        <div style={styles.footer}>
          <p style={styles.helpText}>
            Drag members to reorder. The first member is the group leader.
          </p>
          <button onClick={handleClose} style={styles.doneButton}>
            Done
          </button>
        </div>
      </div>

      {/* Transfer Ownership Modal */}
      {showTransferModal && (
        <div style={styles.backdrop}>
          <div style={styles.transferModal}>
            <div style={styles.header}>
              <h3 style={styles.title}>Transfer Ownership</h3>
              <button onClick={() => setShowTransferModal(false)} style={styles.closeButton}>&times;</button>
            </div>
            <div style={styles.transferContent}>
              <p style={styles.transferText}>
                Select a member to become the new owner of <strong>{usergroup.title}</strong>:
              </p>
              <div style={styles.transferMemberList}>
                {members
                  .filter(m => !m.is_owner && m.type !== 'usergroup')
                  .map(member => (
                    <div
                      key={member.node_id}
                      style={styles.transferMemberItem}
                      onClick={() => !isTransferring && handleTransferOwnership(member.node_id)}
                    >
                      <FaUser style={styles.memberTypeIcon} />
                      <span style={styles.transferMemberName}>{member.title}</span>
                      {member.flags && (
                        <small style={styles.memberFlags}>{member.flags}</small>
                      )}
                    </div>
                  ))}
              </div>
              {isTransferring && (
                <div style={styles.transferringMessage}>Transferring ownership...</div>
              )}
            </div>
            <div style={styles.footer}>
              <button
                onClick={() => setShowTransferModal(false)}
                style={styles.cancelButton}
                disabled={isTransferring}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

const styles = {
  backdrop: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10000,
    padding: '20px'
  },
  modal: {
    backgroundColor: '#fff',
    borderRadius: '8px',
    maxWidth: '600px',
    width: '100%',
    maxHeight: '90vh',
    display: 'flex',
    flexDirection: 'column',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)'
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px 20px',
    borderBottom: '2px solid #38495e',
    backgroundColor: '#f8f9fa'
  },
  title: {
    margin: 0,
    fontSize: '16px',
    color: '#38495e',
    fontWeight: 'bold'
  },
  closeButton: {
    background: 'none',
    border: 'none',
    fontSize: '24px',
    cursor: 'pointer',
    color: '#666',
    padding: '0 4px',
    lineHeight: 1
  },
  message: {
    padding: '10px 20px',
    fontSize: '13px',
    borderBottom: '1px solid #eee'
  },
  searchSection: {
    padding: '16px 20px',
    borderBottom: '1px solid #eee',
    position: 'relative'
  },
  searchHeader: {
    display: 'flex',
    alignItems: 'center',
    fontSize: '13px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '10px'
  },
  searchInputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center'
  },
  searchIcon: {
    position: 'absolute',
    left: '10px',
    color: '#999',
    fontSize: '14px'
  },
  searchInput: {
    width: '100%',
    padding: '8px 12px 8px 32px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontSize: '14px'
  },
  searchingText: {
    position: 'absolute',
    right: '10px',
    fontSize: '12px',
    color: '#666'
  },
  searchResults: {
    position: 'absolute',
    left: '20px',
    right: '20px',
    marginTop: '4px',
    border: '1px solid #ddd',
    borderRadius: '4px',
    maxHeight: '200px',
    overflowY: 'auto',
    backgroundColor: '#fff',
    boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
    zIndex: 100
  },
  searchResult: {
    display: 'flex',
    alignItems: 'center',
    padding: '8px 12px',
    cursor: 'pointer',
    borderBottom: '1px solid #eee'
  },
  typeIcon: {
    marginRight: '8px',
    color: '#666',
    fontSize: '14px'
  },
  resultTitle: {
    flex: 1,
    fontSize: '14px'
  },
  resultType: {
    fontSize: '11px',
    color: '#999',
    textTransform: 'capitalize'
  },
  memberSection: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    minHeight: 0,
    padding: '16px 20px'
  },
  memberHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    fontSize: '13px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '10px'
  },
  saveButton: {
    display: 'flex',
    alignItems: 'center',
    padding: '6px 12px',
    fontSize: '12px',
    border: 'none',
    borderRadius: '4px',
    backgroundColor: '#28a745',
    color: '#fff',
    cursor: 'pointer'
  },
  memberList: {
    flex: 1,
    overflowY: 'auto',
    border: '1px solid #ddd',
    borderRadius: '4px',
    minHeight: '200px',
    maxHeight: '300px'
  },
  emptyState: {
    padding: '20px',
    textAlign: 'center',
    color: '#999',
    fontStyle: 'italic'
  },
  memberItem: {
    display: 'flex',
    alignItems: 'center',
    padding: '10px 12px',
    borderBottom: '1px solid #eee',
    backgroundColor: '#fff',
    transition: 'background-color 0.2s'
  },
  memberItemDragOver: {
    backgroundColor: '#e3f2fd',
    borderTop: '2px solid #2196f3'
  },
  memberItemDragging: {
    opacity: 0.5
  },
  dragHandle: {
    color: '#ccc',
    cursor: 'grab',
    marginRight: '12px',
    fontSize: '14px'
  },
  memberInfo: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    gap: '6px'
  },
  memberTypeIcon: {
    color: '#666',
    fontSize: '12px'
  },
  memberFlags: {
    color: '#999',
    fontSize: '11px'
  },
  ownerBadge: {
    fontSize: '10px',
    padding: '2px 6px',
    backgroundColor: '#fff3cd',
    color: '#856404',
    borderRadius: '10px',
    marginLeft: '4px'
  },
  removeButton: {
    background: 'none',
    border: 'none',
    color: '#dc3545',
    cursor: 'pointer',
    padding: '4px 8px',
    fontSize: '14px',
    opacity: 0.7
  },
  changeOwnerButton: {
    display: 'flex',
    alignItems: 'center',
    padding: '4px 10px',
    fontSize: '11px',
    border: '1px solid #17a2b8',
    borderRadius: '4px',
    backgroundColor: '#fff',
    color: '#17a2b8',
    cursor: 'pointer',
    marginRight: '8px',
    whiteSpace: 'nowrap'
  },
  transferModal: {
    backgroundColor: '#fff',
    borderRadius: '8px',
    maxWidth: '400px',
    width: '100%',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)'
  },
  transferContent: {
    padding: '20px'
  },
  transferText: {
    margin: '0 0 16px 0',
    fontSize: '14px',
    color: '#333'
  },
  transferMemberList: {
    border: '1px solid #ddd',
    borderRadius: '4px',
    maxHeight: '250px',
    overflowY: 'auto'
  },
  transferMemberItem: {
    display: 'flex',
    alignItems: 'center',
    padding: '10px 12px',
    borderBottom: '1px solid #eee',
    cursor: 'pointer',
    transition: 'background-color 0.2s'
  },
  transferMemberName: {
    flex: 1,
    marginLeft: '8px',
    fontSize: '14px'
  },
  transferringMessage: {
    marginTop: '12px',
    fontSize: '13px',
    color: '#666',
    textAlign: 'center'
  },
  cancelButton: {
    padding: '8px 16px',
    fontSize: '13px',
    border: '1px solid #6c757d',
    borderRadius: '4px',
    backgroundColor: '#fff',
    color: '#6c757d',
    cursor: 'pointer'
  },
  footer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '16px 20px',
    borderTop: '1px solid #eee',
    backgroundColor: '#f8f9fa'
  },
  helpText: {
    margin: 0,
    fontSize: '12px',
    color: '#666'
  },
  doneButton: {
    padding: '8px 20px',
    fontSize: '13px',
    border: 'none',
    borderRadius: '4px',
    backgroundColor: '#38495e',
    color: '#fff',
    cursor: 'pointer',
    fontWeight: 'bold'
  }
}

// Add hover effect via CSS-in-JS workaround
if (typeof document !== 'undefined') {
  const styleSheet = document.createElement('style')
  styleSheet.textContent = `
    .usergroup-editor-search-result:hover {
      background-color: #f0f7ff !important;
    }
    .usergroup-editor-remove:hover {
      opacity: 1 !important;
    }
    .usergroup-editor-remove:disabled {
      opacity: 0.3 !important;
      cursor: not-allowed !important;
    }
  `
  document.head.appendChild(styleSheet)

  // Add hover styles for transfer modal items
  const transferStyles = document.createElement('style')
  transferStyles.textContent = `
    .usergroup-transfer-item:hover {
      background-color: #e3f2fd !important;
    }
    .usergroup-change-owner:hover {
      background-color: #17a2b8 !important;
      color: #fff !important;
    }
  `
  document.head.appendChild(transferStyles)
}

export default UsergroupEditor

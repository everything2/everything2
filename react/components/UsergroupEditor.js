import React, { useState, useCallback, useRef, useEffect } from 'react'
import LinkNode from './LinkNode'
import { FaTimes, FaGripVertical, FaPlus, FaSearch, FaUser, FaUsers, FaSave, FaExchangeAlt } from 'react-icons/fa'
import { useAutocompleteSearch } from '../hooks/useAutocompleteSearch'

/**
 * UsergroupEditor - Modal for managing usergroup members
 * Styles in CSS: .usergroup-editor__*
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
  const [isSaving, setIsSaving] = useState(false)
  const [message, setMessage] = useState(null)
  const [draggedIndex, setDraggedIndex] = useState(null)
  const [dragOverIndex, setDragOverIndex] = useState(null)
  const [hasChanges, setHasChanges] = useState(false)
  const [showTransferModal, setShowTransferModal] = useState(false)
  const [isTransferring, setIsTransferring] = useState(false)
  const searchInputRef = useRef(null)

  // Members ref so the search callback (memoized once) can read the
  // current local member list when filtering out already-added rows.
  const membersRef = useRef(members)
  useEffect(() => { membersRef.current = members }, [members])

  // Debounce / abort / stale-guard live in useAutocompleteSearch.
  const groupId = usergroup?.node_id
  const searchMembers = useCallback(async (query, { signal }) => {
    if (!groupId) return []
    const response = await fetch(
      `/api/node_search?q=${encodeURIComponent(query)}&scope=group_addable&group_id=${groupId}`,
      { signal }
    )
    const data = await response.json()
    if (!data.success) return []
    const currentIds = new Set(membersRef.current.map(m => m.node_id))
    return data.results.filter(r => !currentIds.has(r.node_id))
  }, [groupId])
  const {
    results: searchResults,
    setResults: setSearchResults,
    loading: isSearching,
    triggerSearch,
    clearResults: clearSearchResults,
  } = useAutocompleteSearch({ search: searchMembers, debounceMs: 300 })

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
      clearSearchResults()
    }
  }, [isOpen, usergroup, clearSearchResults])

  if (!isOpen || !usergroup) return null

  // Handle search for users/usergroups
  const handleSearch = (query) => {
    setSearchQuery(query)
    triggerSearch(query)
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
    <div className="usergroup-editor__backdrop">
      <div className="usergroup-editor__modal">
        {/* Header */}
        <div className="usergroup-editor__header">
          <h3 className="usergroup-editor__title">
            Edit Members: {usergroup.title}
          </h3>
          <button onClick={handleClose} className="usergroup-editor__close-button">&times;</button>
        </div>

        {/* Message */}
        {message && (
          <div className={`usergroup-editor__message ${message.type === 'error' ? 'usergroup-editor__message--error' : 'usergroup-editor__message--success'}`}>
            {message.text}
          </div>
        )}

        {/* Search to add */}
        <div className="usergroup-editor__search-section">
          <div className="usergroup-editor__search-header">
            <FaPlus className="usergroup-editor__icon-margin-right" />
            Add Member
          </div>
          <div className="usergroup-editor__search-wrapper">
            <FaSearch className="usergroup-editor__search-icon" />
            <input
              ref={searchInputRef}
              type="text"
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder="Search for users or usergroups..."
              className="usergroup-editor__search-input"
            />
            {isSearching && <span className="usergroup-editor__searching-text">Searching...</span>}
          </div>

          {/* Search results */}
          {searchResults.length > 0 && (
            <div className="usergroup-editor__search-results">
              {searchResults.map((result) => (
                <div
                  key={result.node_id}
                  className="usergroup-editor__search-result"
                  onClick={() => handleAdd(result)}
                >
                  {result.type === 'user' ? (
                    <FaUser className="usergroup-editor__type-icon" />
                  ) : (
                    <FaUsers className="usergroup-editor__type-icon" />
                  )}
                  <span className="usergroup-editor__result-title">{result.title}</span>
                  <span className="usergroup-editor__result-type">{result.type}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Member list */}
        <div className="usergroup-editor__member-section">
          <div className="usergroup-editor__member-header">
            <span>Members ({members.length})</span>
            {hasChanges && (
              <button
                onClick={handleSaveOrder}
                disabled={isSaving}
                className="usergroup-editor__save-button"
              >
                <FaSave className="usergroup-editor__icon-margin-right-sm" />
                {isSaving ? 'Saving...' : 'Save Order'}
              </button>
            )}
          </div>

          <div className="usergroup-editor__member-list">
            {members.length === 0 ? (
              <div className="usergroup-editor__empty-state">No members in this group</div>
            ) : (
              members.map((member, index) => {
                const itemClasses = [
                  'usergroup-editor__member-item',
                  dragOverIndex === index ? 'usergroup-editor__member-item--drag-over' : '',
                  draggedIndex === index ? 'usergroup-editor__member-item--dragging' : ''
                ].filter(Boolean).join(' ')

                return (
                  <div
                    key={member.node_id}
                    draggable
                    onDragStart={(e) => handleDragStart(e, index)}
                    onDragEnd={handleDragEnd}
                    onDragOver={(e) => handleDragOver(e, index)}
                    onDragLeave={handleDragLeave}
                    onDrop={(e) => handleDrop(e, index)}
                    className={itemClasses}
                  >
                    <FaGripVertical className="usergroup-editor__drag-handle" title="Drag to reorder" />

                    <div className="usergroup-editor__member-info">
                      {member.type === 'usergroup' ? (
                        <FaUsers className="usergroup-editor__member-type-icon" />
                      ) : (
                        <FaUser className="usergroup-editor__member-type-icon" />
                      )}
                      <LinkNode nodeId={member.node_id} title={member.title} />
                      {member.flags && (
                        <small className="usergroup-editor__member-flags">{member.flags}</small>
                      )}
                      {!!member.is_owner && (
                        <span className="usergroup-editor__owner-badge">owner</span>
                      )}
                    </div>

                    {/* Show Change Owner button for the owner row if current user is owner */}
                    {!!member.is_owner && currentUserIsOwner && members.filter(m => m.type !== 'usergroup').length > 1 && (
                      <button
                        onClick={() => setShowTransferModal(true)}
                        className="usergroup-editor__change-owner-button"
                        title="Transfer ownership to another member"
                      >
                        <FaExchangeAlt className="usergroup-editor__icon-margin-right-sm" />
                        Change Owner
                      </button>
                    )}

                    <button
                      onClick={() => handleRemove(member)}
                      className="usergroup-editor__remove-button"
                      title={member.is_owner ? 'Cannot remove owner' : 'Remove member'}
                      disabled={member.is_owner}
                    >
                      <FaTimes />
                    </button>
                  </div>
                )
              })
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="usergroup-editor__footer">
          <p className="usergroup-editor__help-text">
            Drag members to reorder. The first member is the group leader.
          </p>
          <button onClick={handleClose} className="usergroup-editor__done-button">
            Done
          </button>
        </div>
      </div>

      {/* Transfer Ownership Modal */}
      {showTransferModal && (
        <div className="usergroup-editor__backdrop">
          <div className="usergroup-editor__transfer-modal">
            <div className="usergroup-editor__header">
              <h3 className="usergroup-editor__title">Transfer Ownership</h3>
              <button onClick={() => setShowTransferModal(false)} className="usergroup-editor__close-button">&times;</button>
            </div>
            <div className="usergroup-editor__transfer-content">
              <p className="usergroup-editor__transfer-text">
                Select a member to become the new owner of <strong>{usergroup.title}</strong>:
              </p>
              <div className="usergroup-editor__transfer-member-list">
                {members
                  .filter(m => !m.is_owner && m.type !== 'usergroup')
                  .map(member => (
                    <div
                      key={member.node_id}
                      className="usergroup-editor__transfer-member-item"
                      onClick={() => !isTransferring && handleTransferOwnership(member.node_id)}
                    >
                      <FaUser className="usergroup-editor__member-type-icon" />
                      <span className="usergroup-editor__transfer-member-name">{member.title}</span>
                      {member.flags && (
                        <small className="usergroup-editor__member-flags">{member.flags}</small>
                      )}
                    </div>
                  ))}
              </div>
              {isTransferring && (
                <div className="usergroup-editor__transferring-message">Transferring ownership...</div>
              )}
            </div>
            <div className="usergroup-editor__footer">
              <button
                onClick={() => setShowTransferModal(false)}
                className="usergroup-editor__cancel-button"
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

export default UsergroupEditor

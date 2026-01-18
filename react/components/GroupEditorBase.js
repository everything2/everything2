import React, { useState, useRef, useEffect } from 'react'
import LinkNode from './LinkNode'
import { FaTimes, FaGripVertical, FaPlus, FaSearch, FaSave } from 'react-icons/fa'

/**
 * GroupEditorBase - Shared modal infrastructure for group editors
 *
 * Used by:
 * - UsergroupEditor (users/usergroups, owner concept)
 * - NodegroupEditor (any node type, admin-only)
 *
 * Props:
 * - isOpen: boolean - whether modal is visible
 * - onClose: function - called when modal is closed
 * - title: string - modal title
 * - headerIcon: ReactNode - icon to show in header
 * - searchPlaceholder: string - placeholder for search input
 * - addLabel: string - label for add section (e.g., "Add Member", "Add Node")
 * - helpText: string - help text shown in footer
 * - members: array - current members
 * - setMembers: function - update members
 * - onSaveOrder: async function - save reordered members
 * - renderMemberContent: function(member) - render member-specific content
 * - renderMemberExtra: function(member, index) - render extra content (e.g., owner badge)
 * - canRemove: function(member) - check if member can be removed
 * - onSearch: async function(query) - perform search
 * - onAdd: async function(item) - add a member
 * - onRemove: async function(member) - remove a member
 * - renderSearchResult: function(result) - render search result item
 */
export const GroupEditorModal = ({
  isOpen,
  onClose,
  title,
  headerIcon,
  searchPlaceholder = "Search...",
  addLabel = "Add",
  helpText = "Drag members to reorder.",
  members,
  setMembers,
  onSaveOrder,
  renderMemberContent,
  renderMemberExtra,
  canRemove = () => true,
  onSearch,
  onAdd,
  onRemove,
  renderSearchResult,
  message,
  setMessage
}) => {
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState([])
  const [isSearching, setIsSearching] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [draggedIndex, setDraggedIndex] = useState(null)
  const [dragOverIndex, setDragOverIndex] = useState(null)
  const [hasChanges, setHasChanges] = useState(false)
  const searchTimeoutRef = useRef(null)

  // Reset state when modal opens
  useEffect(() => {
    if (isOpen) {
      setHasChanges(false)
      setSearchQuery('')
      setSearchResults([])
    }
  }, [isOpen])

  if (!isOpen) return null

  // Handle search
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
        const results = await onSearch(query)
        // Filter out current members
        const currentIds = new Set(members.map(m => m.node_id))
        setSearchResults(results.filter(r => !currentIds.has(r.node_id)))
      } catch (error) {
        console.error('Search failed:', error)
      } finally {
        setIsSearching(false)
      }
    }, 300)
  }

  // Handle add
  const handleAdd = async (item) => {
    setMessage(null)
    try {
      await onAdd(item)
      setSearchResults(prev => prev.filter(r => r.node_id !== item.node_id))
      setSearchQuery('')
      setMessage({ type: 'success', text: `Added ${item.title}` })
    } catch (error) {
      setMessage({ type: 'error', text: error.message })
    }
  }

  // Handle remove
  const handleRemove = async (member) => {
    if (!canRemove(member)) return
    setMessage(null)
    try {
      await onRemove(member)
      setMessage({ type: 'success', text: `Removed ${member.title}` })
    } catch (error) {
      setMessage({ type: 'error', text: error.message })
    }
  }

  // Drag and drop handlers
  const handleDragStart = (e, index) => {
    setDraggedIndex(index)
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', index)
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

  // Save order
  const handleSaveOrder = async () => {
    setIsSaving(true)
    setMessage(null)
    try {
      await onSaveOrder(members.map(m => m.node_id))
      setHasChanges(false)
      setMessage({ type: 'success', text: 'Order saved' })
    } catch (error) {
      setMessage({ type: 'error', text: error.message })
    } finally {
      setIsSaving(false)
    }
  }

  // Close handler
  const handleClose = () => {
    if (hasChanges) {
      if (window.confirm('You have unsaved changes to the member order. Close anyway?')) {
        onClose()
      }
    } else {
      onClose()
    }
  }

  // Helper for member item class
  const getMemberClass = (index) => {
    let cls = 'group-editor__member'
    if (dragOverIndex === index) cls += ' group-editor__member--drag-over'
    if (draggedIndex === index) cls += ' group-editor__member--dragging'
    return cls
  }

  // Helper for message class
  const getMessageClass = () => {
    if (!message) return ''
    return message.type === 'error'
      ? 'group-editor__message group-editor__message--error'
      : 'group-editor__message group-editor__message--success'
  }

  return (
    <div className="group-editor__backdrop">
      <div className="group-editor__modal">
        {/* Header */}
        <div className="group-editor__header">
          <h3 className="group-editor__title">
            {headerIcon}
            {title}
          </h3>
          <button onClick={handleClose} className="group-editor__close-btn">&times;</button>
        </div>

        {/* Message */}
        {message && (
          <div className={getMessageClass()}>
            {message.text}
          </div>
        )}

        {/* Search to add */}
        <div className="group-editor__search-section">
          <div className="group-editor__search-header">
            <FaPlus />
            {addLabel}
          </div>
          <div className="group-editor__search-wrapper">
            <FaSearch className="group-editor__search-icon" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder={searchPlaceholder}
              className="group-editor__search-input"
            />
            {isSearching && <span className="group-editor__searching">Searching...</span>}
          </div>

          {/* Search results */}
          {searchResults.length > 0 && (
            <div className="group-editor__results">
              {searchResults.map((result) => (
                <div
                  key={result.node_id}
                  className="group-editor__result"
                  onClick={() => handleAdd(result)}
                >
                  {renderSearchResult(result)}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Member list */}
        <div className="group-editor__member-section">
          <div className="group-editor__member-header">
            <span>Members ({members.length})</span>
            {hasChanges && (
              <button
                onClick={handleSaveOrder}
                disabled={isSaving}
                className="group-editor__save-btn"
              >
                <FaSave />
                {isSaving ? 'Saving...' : 'Save Order'}
              </button>
            )}
          </div>

          <div className="group-editor__member-list">
            {members.length === 0 ? (
              <div className="group-editor__empty">No members in this group</div>
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
                  className={getMemberClass(index)}
                >
                  <FaGripVertical className="group-editor__drag-handle" title="Drag to reorder" />

                  <div className="group-editor__member-info">
                    {renderMemberContent(member)}
                  </div>

                  {renderMemberExtra && renderMemberExtra(member, index)}

                  <button
                    onClick={() => handleRemove(member)}
                    className="group-editor__remove-btn"
                    title={canRemove(member) ? 'Remove' : 'Cannot remove'}
                    disabled={!canRemove(member)}
                  >
                    <FaTimes />
                  </button>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="group-editor__footer">
          <p className="group-editor__help-text">{helpText}</p>
          <button onClick={handleClose} className="group-editor__done-btn">
            Done
          </button>
        </div>
      </div>
    </div>
  )
}

export default GroupEditorModal

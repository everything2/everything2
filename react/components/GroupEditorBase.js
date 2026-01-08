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

  return (
    <div style={styles.backdrop}>
      <div style={styles.modal}>
        {/* Header */}
        <div style={styles.header}>
          <h3 style={styles.title}>
            {headerIcon}
            {title}
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
            {addLabel}
          </div>
          <div style={styles.searchInputWrapper}>
            <FaSearch style={styles.searchIcon} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder={searchPlaceholder}
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
                  {renderSearchResult(result)}
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
                    {renderMemberContent(member)}
                  </div>

                  {renderMemberExtra && renderMemberExtra(member, index)}

                  <button
                    onClick={() => handleRemove(member)}
                    style={styles.removeButton}
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
        <div style={styles.footer}>
          <p style={styles.helpText}>{helpText}</p>
          <button onClick={handleClose} style={styles.doneButton}>
            Done
          </button>
        </div>
      </div>
    </div>
  )
}

export const styles = {
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
    maxWidth: '650px',
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
    fontWeight: 'bold',
    display: 'flex',
    alignItems: 'center'
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
    gap: '8px'
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
  },
  // Additional shared styles for member content
  typeIcon: {
    marginRight: '8px',
    display: 'flex',
    alignItems: 'center'
  },
  resultTitle: {
    flex: 1,
    fontSize: '14px'
  },
  resultType: {
    fontSize: '11px',
    color: '#999',
    padding: '2px 6px',
    backgroundColor: '#f0f0f0',
    borderRadius: '3px'
  },
  typeLabel: {
    fontSize: '11px',
    padding: '2px 6px',
    backgroundColor: '#e8f4f8',
    color: '#507898',
    borderRadius: '3px'
  },
  authorInfo: {
    fontSize: '12px',
    color: '#666'
  },
  memberDetails: {
    display: 'flex',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: '6px'
  },
  ownerBadge: {
    fontSize: '10px',
    padding: '2px 6px',
    backgroundColor: '#fff3cd',
    color: '#856404',
    borderRadius: '10px',
    marginLeft: '4px'
  },
  memberFlags: {
    color: '#999',
    fontSize: '11px'
  }
}

export default GroupEditorModal

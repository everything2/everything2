import React, { useState, useCallback, useEffect } from 'react'
import Modal from 'react-modal'
import { FaTools, FaTimes, FaLink, FaSort, FaEdit, FaLock, FaUnlink } from 'react-icons/fa'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import './E2NodeToolsModal.css'

/**
 * E2NodeToolsModal - Admin tools modal for e2node management
 *
 * Features:
 * - Left-side menu for tool selection
 * - Right panel for tool-specific UI
 * - Available on both e2node and writeup pages
 * - Operations apply to parent e2node
 *
 * Tools:
 * - Firmlink: Create firmlinks from this node to other nodes
 * - Order & Repair: Manage writeup ordering and repair e2node
 * - Title Change: Rename the e2node
 * - Node Lock: Lock/unlock the node to prevent writeup creation
 */

const E2NodeToolsModal = ({ e2node, isOpen, onClose, user }) => {
  const [selectedTool, setSelectedTool] = useState('firmlink')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [message, setMessage] = useState(null)

  // Only show for editors
  if (!(user?.editor || user?.is_editor)) {
    return null
  }

  const tools = [
    { id: 'firmlink', label: 'Firmlink', icon: FaLink },
    { id: 'softlinks', label: 'Trim Softlinks', icon: FaUnlink },
    { id: 'order', label: 'Order & Repair', icon: FaSort },
    { id: 'title', label: 'Title Change', icon: FaEdit },
    { id: 'lock', label: 'Node Lock', icon: FaLock }
  ]

  const handleClose = () => {
    setMessage(null)
    setSelectedTool('firmlink')
    onClose()
  }

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={handleClose}
      className="e2node-tools-modal"
      overlayClassName="e2node-tools-modal-overlay"
      contentLabel="E2 Node Tools"
    >
      <div className="e2node-tools-container">
        {/* Header */}
        <div className="e2node-tools-header">
          <h2><FaTools /> E2 Node Tools</h2>
          <button onClick={handleClose} className="close-button" aria-label="Close">
            <FaTimes />
          </button>
        </div>

        {/* Current Node Info */}
        <div className="e2node-tools-node-info">
          <strong>Node:</strong> {e2node.title}
        </div>

        {/* Content Area */}
        <div className="e2node-tools-content">
          {/* Left Menu */}
          <nav className="e2node-tools-menu">
            {tools.map(tool => (
              <button
                key={tool.id}
                className={`menu-item ${selectedTool === tool.id ? 'active' : ''}`}
                onClick={() => {
                  setSelectedTool(tool.id)
                  setMessage(null)
                }}
              >
                <tool.icon /> {tool.label}
              </button>
            ))}
          </nav>

          {/* Right Panel */}
          <div className="e2node-tools-panel">
            {message && (
              <div className={`message ${message.type}`}>
                {message.text}
              </div>
            )}

            {selectedTool === 'firmlink' && (
              <FirmlinkPanel
                e2node={e2node}
                setMessage={setMessage}
                isSubmitting={isSubmitting}
                setIsSubmitting={setIsSubmitting}
              />
            )}

            {selectedTool === 'softlinks' && (
              <SoftlinkPanel
                e2node={e2node}
                setMessage={setMessage}
                isSubmitting={isSubmitting}
                setIsSubmitting={setIsSubmitting}
              />
            )}

            {selectedTool === 'order' && (
              <OrderRepairPanel
                e2node={e2node}
                setMessage={setMessage}
                isSubmitting={isSubmitting}
                setIsSubmitting={setIsSubmitting}
              />
            )}

            {selectedTool === 'title' && (
              <TitleChangePanel
                e2node={e2node}
                setMessage={setMessage}
                isSubmitting={isSubmitting}
                setIsSubmitting={setIsSubmitting}
                onClose={handleClose}
              />
            )}

            {selectedTool === 'lock' && (
              <NodeLockPanel
                e2node={e2node}
                setMessage={setMessage}
                isSubmitting={isSubmitting}
                setIsSubmitting={setIsSubmitting}
              />
            )}
          </div>
        </div>
      </div>
    </Modal>
  )
}

/**
 * FirmlinkPanel - Create and manage firmlinks from this node to other nodes
 */
const FirmlinkPanel = ({ e2node, setMessage, isSubmitting, setIsSubmitting }) => {
  const [toNode, setToNode] = useState('')
  const [noteText, setNoteText] = useState('')
  const [firmlinks, setFirmlinks] = useState(e2node.firmlinks || [])

  const handleSubmit = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/firmlink`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to_node: toNode,
          note_text: noteText
        })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || 'Firmlink created successfully' })
        setToNode('')
        setNoteText('')
        // Refresh firmlinks list
        if (data.firmlinks) {
          setFirmlinks(data.firmlinks)
        }
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to create firmlink' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while creating firmlink' })
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleRemove = async (targetNodeId, linkTitle, noteText) => {
    const confirmMsg = noteText
      ? `Remove firmlink to "${linkTitle}" (${noteText})?`
      : `Remove firmlink to "${linkTitle}"?`

    if (!confirm(confirmMsg)) {
      return
    }

    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/firmlink/${targetNodeId}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' }
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || 'Firmlink removed successfully' })
        // Refresh firmlinks list
        if (data.firmlinks) {
          setFirmlinks(data.firmlinks)
        }
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to remove firmlink' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while removing firmlink' })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="firmlink-panel">
      <h3>Create Firmlink</h3>
      <p>Link this node to another node with a firm relationship.</p>

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="firmlink-to">Firmlink node to:</label>
          <input
            id="firmlink-to"
            type="text"
            value={toNode}
            onChange={(e) => setToNode(e.target.value)}
            placeholder="Node title or ID"
            required
            disabled={isSubmitting}
          />
        </div>

        <div className="form-group">
          <label htmlFor="firmlink-note">With (optional) following text:</label>
          <input
            id="firmlink-note"
            type="text"
            value={noteText}
            onChange={(e) => setNoteText(e.target.value)}
            placeholder="Optional note"
            disabled={isSubmitting}
          />
        </div>

        <button type="submit" disabled={isSubmitting} className="submit-button">
          {isSubmitting ? 'Creating...' : 'Firmlink'}
        </button>
      </form>

      {/* Existing firmlinks */}
      {firmlinks && firmlinks.length > 0 && (
        <div style={{ marginTop: '2rem' }}>
          <h3>Existing Firmlinks</h3>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {firmlinks.map((link) => (
              <li
                key={link.node_id}
                style={{
                  padding: '0.5rem',
                  borderBottom: '1px solid #e0e0e0',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}
              >
                <span>
                  {link.title}
                  {link.note_text && <span style={{ color: '#666', fontSize: '0.9em' }}> {link.note_text}</span>}
                </span>
                <button
                  onClick={() => handleRemove(link.node_id, link.title, link.note_text)}
                  disabled={isSubmitting}
                  className="remove-button"
                  style={{
                    background: '#dc3545',
                    color: 'white',
                    border: 'none',
                    padding: '0.25rem 0.75rem',
                    borderRadius: '4px',
                    cursor: 'pointer',
                    fontSize: '0.85rem'
                  }}
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

/**
 * SoftlinkPanel - View and delete softlinks from this node
 */
const SoftlinkPanel = ({ e2node, setMessage, isSubmitting, setIsSubmitting }) => {
  const [softlinks, setSoftlinks] = useState([])
  const [selectedIds, setSelectedIds] = useState(new Set())
  const [isLoading, setIsLoading] = useState(true)

  // Fetch softlinks on mount
  useEffect(() => {
    const fetchSoftlinks = async () => {
      try {
        const response = await fetch(`/api/e2node/${e2node.node_id}/softlinks`)
        const data = await response.json()

        if (data.success) {
          setSoftlinks(data.softlinks || [])
        } else {
          setMessage({ type: 'error', text: data.error || 'Failed to load softlinks' })
        }
      } catch (error) {
        setMessage({ type: 'error', text: 'Network error while loading softlinks' })
      } finally {
        setIsLoading(false)
      }
    }

    fetchSoftlinks()
  }, [e2node.node_id, setMessage])

  const handleToggle = (nodeId) => {
    setSelectedIds(prev => {
      const next = new Set(prev)
      if (next.has(nodeId)) {
        next.delete(nodeId)
      } else {
        next.add(nodeId)
      }
      return next
    })
  }

  const handleSelectAll = () => {
    if (selectedIds.size === softlinks.length) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(softlinks.map(s => s.node_id)))
    }
  }

  const handleDelete = async () => {
    if (selectedIds.size === 0) {
      setMessage({ type: 'error', text: 'No softlinks selected' })
      return
    }

    const count = selectedIds.size
    if (!confirm(`Delete ${count} selected softlink${count > 1 ? 's' : ''}?`)) {
      return
    }

    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/softlinks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          delete_ids: Array.from(selectedIds)
        })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || `Deleted ${data.deleted_count} softlink(s)` })
        setSoftlinks(data.softlinks || [])
        setSelectedIds(new Set())
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to delete softlinks' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while deleting softlinks' })
    } finally {
      setIsSubmitting(false)
    }
  }

  if (isLoading) {
    return (
      <div className="softlink-panel">
        <h3>Trim Softlinks</h3>
        <p>Loading softlinks...</p>
      </div>
    )
  }

  if (softlinks.length === 0) {
    return (
      <div className="softlink-panel">
        <h3>Trim Softlinks</h3>
        <p className="info-message">This node has no softlinks.</p>
      </div>
    )
  }

  return (
    <div className="softlink-panel">
      <h3>Trim Softlinks</h3>
      <p style={{ fontSize: '0.9rem', color: '#666', marginBottom: '12px' }}>
        Select softlinks to remove. Shown in order of hit count (highest first).
      </p>

      {/* Action buttons at top */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '12px', alignItems: 'center' }}>
        <button
          onClick={handleDelete}
          disabled={isSubmitting || selectedIds.size === 0}
          className="submit-button"
          style={{ backgroundColor: selectedIds.size > 0 ? '#dc3545' : '#ccc' }}
        >
          {isSubmitting ? 'Deleting...' : `Delete Selected (${selectedIds.size})`}
        </button>
        <button
          onClick={handleSelectAll}
          disabled={isSubmitting}
          className="submit-button"
          style={{ backgroundColor: '#6c757d' }}
        >
          {selectedIds.size === softlinks.length ? 'Deselect All' : 'Select All'}
        </button>
      </div>

      {/* Scrollable list of softlinks */}
      <div style={{
        maxHeight: '350px',
        overflowY: 'auto',
        border: '1px solid #ddd',
        borderRadius: '4px'
      }}>
        {softlinks.map((link, index) => (
          <div
            key={link.node_id}
            style={{
              display: 'flex',
              alignItems: 'center',
              padding: '8px 12px',
              borderBottom: index < softlinks.length - 1 ? '1px solid #eee' : 'none',
              backgroundColor: selectedIds.has(link.node_id) ? '#fff3cd' : 'white',
              cursor: 'pointer'
            }}
            onClick={() => handleToggle(link.node_id)}
          >
            <input
              type="checkbox"
              checked={selectedIds.has(link.node_id)}
              onChange={() => handleToggle(link.node_id)}
              onClick={(e) => e.stopPropagation()}
              style={{ marginRight: '12px' }}
            />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontWeight: 500,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis'
              }}>
                {link.title}
              </div>
            </div>
            <div style={{
              fontSize: '0.8rem',
              color: '#666',
              marginLeft: '12px',
              whiteSpace: 'nowrap'
            }}>
              {link.hits} hit{link.hits !== 1 ? 's' : ''}
            </div>
          </div>
        ))}
      </div>

      <div style={{ marginTop: '12px', fontSize: '0.85rem', color: '#666' }}>
        Total: {softlinks.length} softlink{softlinks.length !== 1 ? 's' : ''}
      </div>
    </div>
  )
}

/**
 * SortableWriteupItem - Draggable writeup item for reordering
 */
function SortableWriteupItem({ id, writeup }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    padding: '10px 12px',
    margin: '4px 0',
    backgroundColor: isDragging ? '#e8f4fc' : 'white',
    border: '1px solid #ddd',
    borderRadius: '4px',
    cursor: 'grab',
    userSelect: 'none',
    opacity: isDragging ? 0.7 : 1,
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    fontSize: '0.9rem',
  }

  const authorName = writeup.author?.title || 'Unknown'
  const writeupType = writeup.writeuptype?.title || writeup.wrtype || 'writeup'
  const reputation = writeup.reputation ?? 0

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      <span style={{ color: '#507898', fontSize: '1.1rem' }}>☰</span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 500, marginBottom: '2px' }}>{authorName}</div>
        <div style={{ fontSize: '0.8rem', color: '#666' }}>
          {writeupType} · rep: {reputation}
        </div>
      </div>
    </div>
  )
}

/**
 * OrderRepairPanel - Manage writeup ordering with drag-and-drop
 */
const OrderRepairPanel = ({ e2node, setMessage, isSubmitting, setIsSubmitting }) => {
  const hasWriteups = e2node.group && e2node.group.length > 0
  const [writeups, setWriteups] = useState(e2node.group || [])
  const [isOrderLocked, setIsOrderLocked] = useState(!!e2node.orderlock_user)
  const [hasChanges, setHasChanges] = useState(false)

  // Drag-and-drop sensors
  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Handle drag end
  const handleDragEnd = useCallback((event) => {
    const { active, over } = event
    if (active.id !== over?.id) {
      setWriteups((items) => {
        const oldIndex = items.findIndex((item) => item.node_id === active.id)
        const newIndex = items.findIndex((item) => item.node_id === over.id)
        setHasChanges(true)
        return arrayMove(items, oldIndex, newIndex)
      })
    }
  }, [])

  // Save order to API
  const handleSaveOrder = async () => {
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/reorder`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          writeup_ids: writeups.map(w => w.node_id),
          lock_order: isOrderLocked
        })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || 'Order saved successfully' })
        setHasChanges(false)
        // Reload to show new order
        setTimeout(() => window.location.reload(), 1000)
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to save order' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while saving order' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Reset to default order (by publishtime)
  const handleResetToDefault = async () => {
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/reorder`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reset_to_default: true,
          lock_order: isOrderLocked
        })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || 'Order reset to default' })
        // Reload to show new order
        setTimeout(() => window.location.reload(), 1000)
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to reset order' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while resetting order' })
    } finally {
      setIsSubmitting(false)
    }
  }

  // Repair node
  const handleRepair = async () => {
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/repair`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || 'Node repaired successfully' })
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to repair node' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while repairing node' })
    } finally {
      setIsSubmitting(false)
    }
  }

  if (!hasWriteups) {
    return (
      <div className="order-repair-panel">
        <h3>Writeups, Order and Repair</h3>
        <p className="info-message">
          This node has no writeups. Repair is available to fix node metadata.
        </p>
        <button onClick={handleRepair} disabled={isSubmitting} className="submit-button">
          {isSubmitting ? 'Repairing...' : 'Repair Node'}
        </button>
      </div>
    )
  }

  return (
    <div className="order-repair-panel">
      <h3>Writeup Order</h3>
      <p style={{ fontSize: '0.9rem', color: '#666', marginBottom: '12px' }}>
        Drag writeups to reorder them. Shows author, type, and reputation.
      </p>

      {/* Drag-and-drop list */}
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        onDragEnd={handleDragEnd}
      >
        <SortableContext
          items={writeups.map(w => w.node_id)}
          strategy={verticalListSortingStrategy}
        >
          <div style={{ marginBottom: '16px', maxHeight: '300px', overflowY: 'auto' }}>
            {writeups.map((writeup) => (
              <SortableWriteupItem
                key={writeup.node_id}
                id={writeup.node_id}
                writeup={writeup}
              />
            ))}
          </div>
        </SortableContext>
      </DndContext>

      {/* Lock order checkbox */}
      <div style={{ marginBottom: '16px' }}>
        <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
          <input
            type="checkbox"
            checked={isOrderLocked}
            onChange={(e) => {
              setIsOrderLocked(e.target.checked)
              setHasChanges(true)
            }}
          />
          <span>Lock order (prevents auto-reorder on repair)</span>
        </label>
      </div>

      {/* Action buttons */}
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '16px' }}>
        <button
          onClick={handleSaveOrder}
          disabled={isSubmitting || !hasChanges}
          className="submit-button"
        >
          {isSubmitting ? 'Saving...' : 'Save Order'}
        </button>
        <button
          onClick={handleResetToDefault}
          disabled={isSubmitting}
          className="submit-button"
          style={{ backgroundColor: '#6c757d' }}
        >
          Reset to Default
        </button>
      </div>

      <hr style={{ margin: '16px 0' }} />

      {/* Repair section */}
      <div className="repair-section">
        <p style={{ fontSize: '0.9rem', marginBottom: '8px' }}>
          Repair this node to fix writeup titles and metadata.
        </p>
        <button onClick={handleRepair} disabled={isSubmitting} className="submit-button">
          {isSubmitting ? 'Repairing...' : 'Repair Node'}
        </button>
      </div>
    </div>
  )
}

/**
 * TitleChangePanel - Rename the e2node
 */
const TitleChangePanel = ({ e2node, setMessage, isSubmitting, setIsSubmitting, onClose }) => {
  const [newTitle, setNewTitle] = useState(e2node.title)

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (newTitle === e2node.title) {
      setMessage({ type: 'error', text: 'New title is the same as current title' })
      return
    }

    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/title`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ new_title: newTitle })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: data.message || 'Title changed successfully' })
        // Redirect to new URL after successful rename
        setTimeout(() => {
          window.location.href = `/title/${encodeURIComponent(newTitle)}`
        }, 1500)
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to change title' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while changing title' })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="title-change-panel">
      <h3>Change Title</h3>
      <p className="warning-message">
        Warning: Changing the node title will rename all writeups in this node.
        Use with caution!
      </p>

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="new-title">New title:</label>
          <input
            id="new-title"
            type="text"
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            required
            disabled={isSubmitting}
          />
        </div>

        <div className="current-title">
          <strong>Current title:</strong> {e2node.title}
        </div>

        <button type="submit" disabled={isSubmitting} className="submit-button">
          {isSubmitting ? 'Renaming...' : 'Rename'}
        </button>
      </form>
    </div>
  )
}

/**
 * NodeLockPanel - Lock/unlock node to prevent writeup creation
 */
const NodeLockPanel = ({ e2node, setMessage, isSubmitting, setIsSubmitting }) => {
  const [lockReason, setLockReason] = useState('')
  const [isLocked, setIsLocked] = useState(false)
  const [currentLock, setCurrentLock] = useState(null)

  // Fetch current lock status
  React.useEffect(() => {
    const fetchLockStatus = async () => {
      try {
        const response = await fetch(`/api/e2node/${e2node.node_id}/lock`)
        const data = await response.json()

        if (data.success && data.lock) {
          setIsLocked(true)
          setCurrentLock(data.lock)
          setLockReason(data.lock.reason || '')
        } else {
          setIsLocked(false)
          setCurrentLock(null)
        }
      } catch (error) {
        console.error('Failed to fetch lock status:', error)
      }
    }

    fetchLockStatus()
  }, [e2node.node_id])

  const handleLock = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/lock`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'lock',
          reason: lockReason
        })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: 'Node locked successfully' })
        setIsLocked(true)
        setCurrentLock({ reason: lockReason, user_id: data.user_id })
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to lock node' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while locking node' })
    } finally {
      setIsSubmitting(false)
    }
  }

  const handleUnlock = async () => {
    setIsSubmitting(true)
    setMessage(null)

    try {
      const response = await fetch(`/api/e2node/${e2node.node_id}/lock`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'unlock' })
      })

      const data = await response.json()

      if (data.success) {
        setMessage({ type: 'success', text: 'Node unlocked successfully' })
        setIsLocked(false)
        setCurrentLock(null)
        setLockReason('')
      } else {
        setMessage({ type: 'error', text: data.error || 'Failed to unlock node' })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Network error while unlocking node' })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="node-lock-panel">
      <h3>Node Lock</h3>

      {isLocked ? (
        <div className="lock-status">
          <p className="warning-message">
            This node is currently locked. Users cannot create new writeups.
          </p>
          {currentLock?.reason && (
            <div className="lock-reason">
              <strong>Reason:</strong> {currentLock.reason}
            </div>
          )}
          <button
            onClick={handleUnlock}
            disabled={isSubmitting}
            className="submit-button unlock-button"
          >
            {isSubmitting ? 'Unlocking...' : 'Unlock Node'}
          </button>
        </div>
      ) : (
        <form onSubmit={handleLock}>
          <p>Lock this node to prevent users from creating new writeups.</p>

          <div className="form-group">
            <label htmlFor="lock-reason">Reason for locking:</label>
            <textarea
              id="lock-reason"
              value={lockReason}
              onChange={(e) => setLockReason(e.target.value)}
              rows="3"
              placeholder="Enter reason for locking this node"
              required
              disabled={isSubmitting}
            />
          </div>

          <button type="submit" disabled={isSubmitting} className="submit-button">
            {isSubmitting ? 'Locking...' : 'Lock Node'}
          </button>
        </form>
      )}
    </div>
  )
}

export default E2NodeToolsModal

import React, { useState, useEffect } from 'react'
import Modal from 'react-modal'
import { FaExclamationTriangle, FaTrashAlt, FaEdit, FaBook, FaClone, FaEye, FaSave } from 'react-icons/fa'
import LinkNode from '../LinkNode'

// System node types that use the modal edit interface instead of legacy edit pages
const SYSTEM_NODE_TYPES = [
  'maintenance',
  'htmlcode',
  'htmlpage',
  'nodelet',
  'nodetype',
  'superdoc',
  'restricted_superdoc',
  'oppressor_superdoc',
  'fullpage'
]

const NodeToolset = ({
  nodeId,
  nodeTitle,
  nodeType,
  canDelete,
  currentDisplay,
  hasHelp,
  isWriteup,
  preventNuke
}) => {
  const [nukeModalOpen, setNukeModalOpen] = useState(false)
  const [cloneModalOpen, setCloneModalOpen] = useState(false)
  const [editModalOpen, setEditModalOpen] = useState(false)
  const [isDeleting, setIsDeleting] = useState(false)
  const [isCloning, setIsCloning] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [isLoadingEdit, setIsLoadingEdit] = useState(false)
  const [cloneTitle, setCloneTitle] = useState('')
  const [editTitle, setEditTitle] = useState('')
  const [editMaintainer, setEditMaintainer] = useState('')
  const [originalData, setOriginalData] = useState(null)
  const [error, setError] = useState(null)

  const isSystemNode = SYSTEM_NODE_TYPES.includes(nodeType)

  const openNukeModal = () => {
    setNukeModalOpen(true)
    setError(null)
  }

  const closeNukeModal = () => {
    setNukeModalOpen(false)
    setError(null)
  }

  const openCloneModal = () => {
    setCloneModalOpen(true)
    setCloneTitle('')
    setError(null)
  }

  const closeCloneModal = () => {
    setCloneModalOpen(false)
    setCloneTitle('')
    setError(null)
  }

  const openEditModal = async () => {
    setEditModalOpen(true)
    setError(null)
    setIsLoadingEdit(true)

    try {
      const response = await fetch(`/api/admin/node/${nodeId}`, {
        method: 'GET',
        credentials: 'include',
      })

      const data = await response.json()

      if (response.ok) {
        setOriginalData(data)
        setEditTitle(data.title || '')
        setEditMaintainer(data.maintainedby_user?.title || '')
      } else {
        setError(data.error || 'Failed to load node data')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setIsLoadingEdit(false)
    }
  }

  const closeEditModal = () => {
    setEditModalOpen(false)
    setEditTitle('')
    setEditMaintainer('')
    setOriginalData(null)
    setError(null)
  }

  const handleEdit = async (e) => {
    e.preventDefault()
    if (!editTitle.trim()) return

    setIsSaving(true)
    setError(null)

    try {
      // Build update payload - only include changed fields
      const updates = {}

      if (editTitle !== originalData?.title) {
        updates.title = editTitle
      }

      // For maintainer, we need to look up the user ID
      // For now, only update if cleared (null) or unchanged
      // TODO: Add user autocomplete for maintainer selection
      if (editMaintainer === '' && originalData?.maintainedby_user) {
        updates.maintainedby_user = null
      }

      if (Object.keys(updates).length === 0) {
        setError('No changes to save')
        setIsSaving(false)
        return
      }

      const response = await fetch(`/api/admin/node/${nodeId}/edit`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify(updates),
      })

      const data = await response.json()

      if (response.ok) {
        // Navigate to the new title - if title changed, reload would show "not found"
        const newTitle = data.title || editTitle
        window.location.href = `/title/${encodeURIComponent(newTitle)}`
      } else {
        setError(data.error || data.message || 'Failed to update node')
        setIsSaving(false)
      }
    } catch (err) {
      setError('Network error: ' + err.message)
      setIsSaving(false)
    }
  }

  const handleNuke = async () => {
    setIsDeleting(true)
    setError(null)

    try {
      const response = await fetch(`/api/nodes/${nodeId}/action/delete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
      })

      const data = await response.json()

      if (response.ok) {
        // Navigate to the deleted node page which will show "not found"
        window.location.href = `/?node_id=${nodeId}`
      } else {
        setError(data.error || 'Failed to delete node')
        setIsDeleting(false)
        closeNukeModal()
      }
    } catch (err) {
      setError('Network error: ' + err.message)
      setIsDeleting(false)
      closeNukeModal()
    }
  }

  const handleClone = async (e) => {
    e.preventDefault()
    if (!cloneTitle.trim()) return

    setIsCloning(true)
    setError(null)

    try {
      const response = await fetch(`/api/nodes/${nodeId}/action/clone`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ title: cloneTitle }),
      })

      const data = await response.json()

      if (response.ok) {
        // Navigate to the newly cloned node
        window.location.href = `/?node_id=${data.cloned_node_id}`
      } else {
        setError(data.error || 'Failed to clone node')
        setIsCloning(false)
      }
    } catch (err) {
      setError('Network error: ' + err.message)
      setIsCloning(false)
    }
  }

  const isSuperdoc = nodeType === 'nodelet' || nodeType.includes('superdoc')
  const isOnEditPage = currentDisplay === 'edit' || currentDisplay === 'basicedit'
  const showEdit = !isOnEditPage
  const showHelp = currentDisplay !== 'help'
  const showAdvancedEdit = isOnEditPage  // Show "Advanced Edit" link when already editing

  const buttonStyle = {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '12px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    backgroundColor: '#f9f9f9',
    cursor: 'pointer',
    textAlign: 'center',
    textDecoration: 'none',
    color: 'inherit',
    gap: '6px',
    minHeight: '70px',
    transition: 'all 0.2s ease'
  }

  const buttonHoverStyle = {
    backgroundColor: '#e9e9e9',
    borderColor: '#999'
  }

  const disabledButtonStyle = {
    ...buttonStyle,
    backgroundColor: '#f5f5f5',
    color: '#999',
    cursor: 'not-allowed',
    opacity: 0.6
  }

  return (
    <div className="nodelet_section">
      <h4 className="ns_title">Node Toolset</h4>

      {/* Display node link when not on display page */}
      {currentDisplay !== 'display' && (
        <div style={{ marginBottom: '10px' }}>
          <LinkNode nodeId={nodeId} title={nodeTitle} />
        </div>
      )}

      {/* 2x2 Button Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: '8px',
        marginBottom: '10px'
      }}>
        {/* Edit/Display Button */}
        {showEdit ? (
          isSystemNode ? (
            // System nodes use modal edit
            <button
              onClick={openEditModal}
              style={buttonStyle}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
                e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
                e.currentTarget.style.borderColor = '#ccc'
              }}
            >
              <FaEdit size={20} />
              <span>Edit Node</span>
            </button>
          ) : (
            // Non-system nodes use legacy edit page
            <div
              style={buttonStyle}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
                e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
                e.currentTarget.style.borderColor = '#ccc'
              }}
            >
              <LinkNode
                nodeId={nodeId}
                title={nodeTitle}
                display={
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                    <FaEdit size={20} />
                    <span>{isSuperdoc ? 'Edit Code' : 'Edit Node'}</span>
                  </div>
                }
                params={{ displaytype: 'edit' }}
                style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}
              />
            </div>
          )
        ) : (
          <div
            style={buttonStyle}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
              e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
              e.currentTarget.style.borderColor = '#ccc'
            }}
          >
            <LinkNode
              nodeId={nodeId}
              title={nodeTitle}
              display={
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                  <FaEye size={20} />
                  <span>Display</span>
                </div>
              }
              style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}
            />
          </div>
        )}

        {/* Document/Advanced Edit Button */}
        {showAdvancedEdit ? (
          <div
            style={buttonStyle}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
              e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
              e.currentTarget.style.borderColor = '#ccc'
            }}
          >
            <LinkNode
              nodeId={nodeId}
              title={nodeTitle}
              display={
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                  <FaBook size={20} />
                  <span>Advanced Edit</span>
                </div>
              }
              params={{ displaytype: 'basicedit' }}
              style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}
            />
          </div>
        ) : showHelp ? (
          <div
            style={buttonStyle}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
              e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
              e.currentTarget.style.borderColor = '#ccc'
            }}
          >
            <LinkNode
              nodeId={nodeId}
              title={nodeTitle}
              display={
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                  <FaBook size={20} />
                  <span>{hasHelp ? 'Documentation' : 'Document Node'}</span>
                </div>
              }
              params={{ displaytype: 'help' }}
              style={{ textDecoration: 'none', color: 'inherit', display: 'block' }}
            />
          </div>
        ) : (
          <div style={disabledButtonStyle}>
            <FaBook size={20} />
            <span>Documentation</span>
          </div>
        )}

        {/* Clone Button */}
        <button
          onClick={openCloneModal}
          style={buttonStyle}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
            e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
            e.currentTarget.style.borderColor = '#ccc'
          }}
        >
          <FaClone size={20} />
          <span>Clone Node</span>
        </button>

        {/* Delete Button - shows warning icon with "Insured" when protected */}
        {preventNuke ? (
          <div
            title="This node is protected from deletion (nuke insurance). It is a core system node."
            style={{
              ...disabledButtonStyle,
              color: '#d9534f'
            }}
          >
            <FaExclamationTriangle size={20} />
            <span>Insured</span>
          </div>
        ) : (
          <button
            onClick={canDelete ? openNukeModal : undefined}
            disabled={!canDelete}
            title={canDelete ? "Delete this node" : "Cannot delete this node"}
            style={canDelete ? buttonStyle : disabledButtonStyle}
            onMouseEnter={(e) => {
              if (canDelete) {
                e.currentTarget.style.backgroundColor = buttonHoverStyle.backgroundColor
                e.currentTarget.style.borderColor = buttonHoverStyle.borderColor
              }
            }}
            onMouseLeave={(e) => {
              if (canDelete) {
                e.currentTarget.style.backgroundColor = buttonStyle.backgroundColor
                e.currentTarget.style.borderColor = '#ccc'
              }
            }}
          >
            <FaTrashAlt size={20} />
            <span>Delete Node</span>
          </button>
        )}
      </div>

      {/* Writeup Warning */}
      {isWriteup && !preventNuke && canDelete && (
        <div style={{ fontSize: '0.9em', color: '#666', marginTop: '8px' }}>
          <strong>writeup:</strong> only nuke under exceptional circumstances.
          Removal is almost certainly a better idea.
        </div>
      )}

      <Modal
        isOpen={nukeModalOpen}
        onRequestClose={closeNukeModal}
        ariaHideApp={false}
        contentLabel="Confirm Node Deletion"
        style={{
          content: {
            top: '50%',
            left: '50%',
            right: 'auto',
            bottom: 'auto',
            marginRight: '-50%',
            transform: 'translate(-50%, -50%)',
            minWidth: '400px',
            maxWidth: '600px',
          },
        }}
      >
        <div>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#d9534f' }}>
            <FaExclamationTriangle size={20} /> Confirm Node Deletion
          </h2>

          <div style={{ margin: '20px 0', lineHeight: '1.6' }}>
            <p>
              <strong>Warning:</strong> Nuking a node <strong>removes it immediately</strong> and
              should only be used when you know what the consequences might be.
            </p>
            <p>
              Deleted nodes can be restored if necessary using the resurrection system,
              but you should still use caution.
            </p>
            <p style={{ marginTop: '15px', padding: '10px', backgroundColor: '#f5f5f5', border: '1px solid #ddd' }}>
              You are about to delete: <br />
              <strong>{nodeTitle}</strong> ({nodeType})
            </p>
          </div>

          {error && (
            <div style={{ color: 'red', padding: '10px', marginBottom: '10px', border: '1px solid red' }}>
              {error}
            </div>
          )}

          <div style={{ textAlign: 'right', marginTop: '20px' }}>
            <button
              type="button"
              onClick={closeNukeModal}
              disabled={isDeleting}
              style={{
                marginRight: '10px',
                padding: '6px 16px',
                backgroundColor: '#f5f5f5',
                color: '#333',
                border: '1px solid #ccc',
                borderRadius: '3px',
                cursor: isDeleting ? 'not-allowed' : 'pointer',
                fontSize: '0.9em'
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleNuke}
              disabled={isDeleting}
              style={{
                padding: '6px 16px',
                backgroundColor: '#d9534f',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: isDeleting ? 'not-allowed' : 'pointer',
                fontSize: '0.9em',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                opacity: isDeleting ? 0.6 : 1
              }}
            >
              <FaTrashAlt size={12} /> {isDeleting ? 'Deleting...' : 'Delete Node'}
            </button>
          </div>
        </div>
      </Modal>

      <Modal
        isOpen={cloneModalOpen}
        onRequestClose={closeCloneModal}
        ariaHideApp={false}
        contentLabel="Clone Node"
        style={{
          content: {
            top: '50%',
            left: '50%',
            right: 'auto',
            bottom: 'auto',
            marginRight: '-50%',
            transform: 'translate(-50%, -50%)',
            minWidth: '400px',
            maxWidth: '600px',
          },
        }}
      >
        <div>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <FaClone size={20} /> Clone Node
          </h2>

          <div style={{ margin: '20px 0', lineHeight: '1.6' }}>
            <p>
              Create a copy of this node with a new title. The cloned node will have
              the same content and type as the original.
            </p>
            <p style={{ marginTop: '15px', padding: '10px', backgroundColor: '#f5f5f5', border: '1px solid #ddd' }}>
              Cloning: <br />
              <strong>{nodeTitle}</strong> ({nodeType})
            </p>

            <form onSubmit={handleClone} style={{ marginTop: '15px' }}>
              <label htmlFor="clone-title" style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                New Node Title:
              </label>
              <input
                id="clone-title"
                type="text"
                value={cloneTitle}
                onChange={(e) => setCloneTitle(e.target.value)}
                disabled={isCloning}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ccc',
                  borderRadius: '3px',
                  fontSize: '0.9em',
                  boxSizing: 'border-box'
                }}
                placeholder="Enter title for cloned node"
                autoFocus
              />
            </form>
          </div>

          {error && (
            <div style={{ color: 'red', padding: '10px', marginBottom: '10px', border: '1px solid red' }}>
              {error}
            </div>
          )}

          <div style={{ textAlign: 'right', marginTop: '20px' }}>
            <button
              type="button"
              onClick={closeCloneModal}
              disabled={isCloning}
              style={{
                marginRight: '10px',
                padding: '6px 16px',
                backgroundColor: '#f5f5f5',
                color: '#333',
                border: '1px solid #ccc',
                borderRadius: '3px',
                cursor: isCloning ? 'not-allowed' : 'pointer',
                fontSize: '0.9em'
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleClone}
              disabled={isCloning || !cloneTitle.trim()}
              style={{
                padding: '6px 16px',
                backgroundColor: isCloning || !cloneTitle.trim() ? '#ccc' : '#5bc0de',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: isCloning || !cloneTitle.trim() ? 'not-allowed' : 'pointer',
                fontSize: '0.9em',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                opacity: isCloning || !cloneTitle.trim() ? 0.6 : 1
              }}
            >
              <FaClone size={12} /> {isCloning ? 'Cloning...' : 'Clone Node'}
            </button>
          </div>
        </div>
      </Modal>

      {/* Edit Modal - for system node types */}
      <Modal
        isOpen={editModalOpen}
        onRequestClose={closeEditModal}
        ariaHideApp={false}
        contentLabel="Edit Node"
        style={{
          content: {
            top: '50%',
            left: '50%',
            right: 'auto',
            bottom: 'auto',
            marginRight: '-50%',
            transform: 'translate(-50%, -50%)',
            minWidth: '450px',
            maxWidth: '600px',
          },
        }}
      >
        <div>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <FaEdit size={20} /> Edit Node
          </h2>

          {isLoadingEdit ? (
            <div style={{ margin: '20px 0', textAlign: 'center', color: '#666' }}>
              Loading node data...
            </div>
          ) : (
            <div style={{ margin: '20px 0', lineHeight: '1.6' }}>
              <p style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f5f5f5', border: '1px solid #ddd' }}>
                Editing: <strong>{nodeTitle}</strong><br />
                <span style={{ fontSize: '0.9em', color: '#666' }}>Type: {nodeType} | ID: {nodeId}</span>
              </p>

              <form onSubmit={handleEdit}>
                <div style={{ marginBottom: '15px' }}>
                  <label htmlFor="edit-title" style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                    Title:
                  </label>
                  <input
                    id="edit-title"
                    type="text"
                    value={editTitle}
                    onChange={(e) => setEditTitle(e.target.value)}
                    disabled={isSaving}
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #ccc',
                      borderRadius: '3px',
                      fontSize: '0.9em',
                      boxSizing: 'border-box'
                    }}
                    placeholder="Node title"
                    autoFocus
                  />
                </div>

                <div style={{ marginBottom: '15px' }}>
                  <label htmlFor="edit-maintainer" style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                    Maintained By:
                  </label>
                  <input
                    id="edit-maintainer"
                    type="text"
                    value={editMaintainer}
                    onChange={(e) => setEditMaintainer(e.target.value)}
                    disabled={isSaving}
                    style={{
                      width: '100%',
                      padding: '8px',
                      border: '1px solid #ccc',
                      borderRadius: '3px',
                      fontSize: '0.9em',
                      boxSizing: 'border-box',
                      backgroundColor: '#f9f9f9'
                    }}
                    placeholder="Username (read-only for now)"
                    readOnly
                    title="Maintainer editing coming soon"
                  />
                  <span style={{ fontSize: '0.8em', color: '#666', marginTop: '4px', display: 'block' }}>
                    Maintainer selection coming in a future update
                  </span>
                </div>

                {originalData && (
                  <div style={{ fontSize: '0.85em', color: '#666', padding: '10px', backgroundColor: '#f9f9f9', borderRadius: '3px' }}>
                    <strong>Author:</strong> {originalData.author_user?.title || 'Unknown'}<br />
                    <strong>Created:</strong> {originalData.createtime || 'Unknown'}
                  </div>
                )}
              </form>
            </div>
          )}

          {error && (
            <div style={{ color: 'red', padding: '10px', marginBottom: '10px', border: '1px solid red' }}>
              {error}
            </div>
          )}

          <div style={{ textAlign: 'right', marginTop: '20px' }}>
            <button
              type="button"
              onClick={closeEditModal}
              disabled={isSaving}
              style={{
                marginRight: '10px',
                padding: '6px 16px',
                backgroundColor: '#f5f5f5',
                color: '#333',
                border: '1px solid #ccc',
                borderRadius: '3px',
                cursor: isSaving ? 'not-allowed' : 'pointer',
                fontSize: '0.9em'
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleEdit}
              disabled={isSaving || isLoadingEdit || !editTitle.trim()}
              style={{
                padding: '6px 16px',
                backgroundColor: isSaving || isLoadingEdit || !editTitle.trim() ? '#ccc' : '#5cb85c',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: isSaving || isLoadingEdit || !editTitle.trim() ? 'not-allowed' : 'pointer',
                fontSize: '0.9em',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                opacity: isSaving || isLoadingEdit || !editTitle.trim() ? 0.6 : 1
              }}
            >
              <FaSave size={12} /> {isSaving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  )
}

export default NodeToolset

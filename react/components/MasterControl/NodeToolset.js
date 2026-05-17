import React, { useState } from 'react'
import Modal from 'react-modal'
import { FaExclamationTriangle, FaTrashAlt, FaEdit, FaBook, FaClone, FaEye, FaSave } from 'react-icons/fa'
import LinkNode from '../LinkNode'

// System node types that use the modal edit interface instead of legacy edit pages
// Note: nodetype, nodelet, container, htmlcode, htmlpage, and maintenance are excluded - they use basicedit for full field editing
const SYSTEM_NODE_TYPES = [
  'superdoc',
  'restricted_superdoc',
  'oppressor_superdoc',
  'fullpage'
]

// Modal positioning styles (react-modal requires inline style objects)
const modalStyle = {
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
}

const editModalStyle = {
  content: {
    ...modalStyle.content,
    minWidth: '450px',
  },
}

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

  return (
    <div className="nodelet_section">
      <h4 className="ns_title">Node Toolset</h4>

      {/* Display node link when not on display page */}
      {currentDisplay !== 'display' && (
        <div className="node-toolset__node-link">
          <LinkNode id={nodeId} display={nodeTitle} />
        </div>
      )}

      {/* 2x2 Button Grid */}
      <div className="node-toolset__grid">
        {/* Edit/Display Button */}
        {showEdit ? (
          isSystemNode ? (
            // System nodes use modal edit
            <button onClick={openEditModal} className="node-toolset__btn">
              <FaEdit size={20} />
              <span>Edit Node</span>
            </button>
          ) : (
            // Non-system nodes use legacy edit page
            <LinkNode
              id={nodeId}
              display={
                <span className="node-toolset__btn-content">
                  <FaEdit size={20} />
                  <span>{isSuperdoc ? 'Edit Code' : 'Edit Node'}</span>
                </span>
              }
              params={{ displaytype: 'edit' }}
              className="node-toolset__btn"
            />
          )
        ) : (
          <LinkNode
            id={nodeId}
            display={
              <span className="node-toolset__btn-content">
                <FaEye size={20} />
                <span>Display</span>
              </span>
            }
            className="node-toolset__btn"
          />
        )}

        {/* Document/Advanced Edit Button */}
        {showAdvancedEdit ? (
          <LinkNode
            id={nodeId}
            display={
              <span className="node-toolset__btn-content">
                <FaBook size={20} />
                <span>Advanced Edit</span>
              </span>
            }
            params={{ displaytype: 'basicedit' }}
            className="node-toolset__btn"
          />
        ) : showHelp ? (
          <LinkNode
            id={nodeId}
            display={
              <span className="node-toolset__btn-content">
                <FaBook size={20} />
                <span>{hasHelp ? 'Documentation' : 'Document Node'}</span>
              </span>
            }
            params={{ displaytype: 'help' }}
            className="node-toolset__btn"
          />
        ) : (
          <div className="node-toolset__btn node-toolset__btn--disabled">
            <FaBook size={20} />
            <span>Documentation</span>
          </div>
        )}

        {/* Clone Button */}
        <button onClick={openCloneModal} className="node-toolset__btn">
          <FaClone size={20} />
          <span>Clone Node</span>
        </button>

        {/* Delete Button - shows warning icon with "Insured" when protected */}
        {preventNuke ? (
          <div
            title="This node is protected from deletion (nuke insurance). It is a core system node."
            className="node-toolset__btn node-toolset__btn--disabled node-toolset__btn--danger"
          >
            <FaExclamationTriangle size={20} />
            <span>Insured</span>
          </div>
        ) : (
          <button
            onClick={canDelete ? openNukeModal : undefined}
            disabled={!canDelete}
            title={canDelete ? "Delete this node" : "Cannot delete this node"}
            className={canDelete ? 'node-toolset__btn' : 'node-toolset__btn node-toolset__btn--disabled'}
          >
            <FaTrashAlt size={20} />
            <span>Delete Node</span>
          </button>
        )}
      </div>

      {/* Writeup Warning */}
      {isWriteup && !preventNuke && canDelete && (
        <div className="node-toolset__warning">
          <strong>writeup:</strong> only nuke under exceptional circumstances.
          Removal is almost certainly a better idea.
        </div>
      )}

      {/* Nuke Confirmation Modal */}
      <Modal
        isOpen={nukeModalOpen}
        onRequestClose={closeNukeModal}
        ariaHideApp={false}
        contentLabel="Confirm Node Deletion"
        style={modalStyle}
      >
        <div>
          <h2 className="node-toolset__modal-title node-toolset__modal-title--danger">
            <FaExclamationTriangle size={20} /> Confirm Node Deletion
          </h2>

          <div className="node-toolset__modal-content">
            <p>
              <strong>Warning:</strong> Nuking a node <strong>removes it immediately</strong> and
              should only be used when you know what the consequences might be.
            </p>
            <p>
              Deleted nodes can be restored if necessary using the resurrection system,
              but you should still use caution.
            </p>
            <p className="node-toolset__info-box">
              You are about to delete: <br />
              <strong>{nodeTitle}</strong> ({nodeType})
            </p>
          </div>

          {error && <div className="node-toolset__error">{error}</div>}

          <div className="node-toolset__modal-footer">
            <button
              type="button"
              onClick={closeNukeModal}
              disabled={isDeleting}
              className="node-toolset__modal-cancel"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleNuke}
              disabled={isDeleting}
              className="node-toolset__modal-action node-toolset__modal-action--delete"
            >
              <FaTrashAlt size={12} /> {isDeleting ? 'Deleting...' : 'Delete Node'}
            </button>
          </div>
        </div>
      </Modal>

      {/* Clone Modal */}
      <Modal
        isOpen={cloneModalOpen}
        onRequestClose={closeCloneModal}
        ariaHideApp={false}
        contentLabel="Clone Node"
        style={modalStyle}
      >
        <div>
          <h2 className="node-toolset__modal-title">
            <FaClone size={20} /> Clone Node
          </h2>

          <div className="node-toolset__modal-content">
            <p>
              Create a copy of this node with a new title. The cloned node will have
              the same content and type as the original.
            </p>
            <p className="node-toolset__info-box">
              Cloning: <br />
              <strong>{nodeTitle}</strong> ({nodeType})
            </p>

            <form onSubmit={handleClone} className="node-toolset__form-group">
              <label htmlFor="clone-title" className="node-toolset__label">
                New Node Title:
              </label>
              <input
                id="clone-title"
                type="text"
                value={cloneTitle}
                onChange={(e) => setCloneTitle(e.target.value)}
                disabled={isCloning}
                className="node-toolset__input"
                placeholder="Enter title for cloned node"
                autoFocus
              />
            </form>
          </div>

          {error && <div className="node-toolset__error">{error}</div>}

          <div className="node-toolset__modal-footer">
            <button
              type="button"
              onClick={closeCloneModal}
              disabled={isCloning}
              className="node-toolset__modal-cancel"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleClone}
              disabled={isCloning || !cloneTitle.trim()}
              className="node-toolset__modal-action node-toolset__modal-action--clone"
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
        style={editModalStyle}
      >
        <div>
          <h2 className="node-toolset__modal-title">
            <FaEdit size={20} /> Edit Node
          </h2>

          {isLoadingEdit ? (
            <div className="node-toolset__loading">Loading node data...</div>
          ) : (
            <div className="node-toolset__modal-content">
              <p className="node-toolset__info-box">
                Editing: <strong>{nodeTitle}</strong><br />
                <span className="node-toolset__edit-info">Type: {nodeType} | ID: {nodeId}</span>
              </p>

              <form onSubmit={handleEdit}>
                <div className="node-toolset__form-group">
                  <label htmlFor="edit-title" className="node-toolset__label">
                    Title:
                  </label>
                  <input
                    id="edit-title"
                    type="text"
                    value={editTitle}
                    onChange={(e) => setEditTitle(e.target.value)}
                    disabled={isSaving}
                    className="node-toolset__input"
                    placeholder="Node title"
                    autoFocus
                  />
                </div>

                <div className="node-toolset__form-group">
                  <label htmlFor="edit-maintainer" className="node-toolset__label">
                    Maintained By:
                  </label>
                  <input
                    id="edit-maintainer"
                    type="text"
                    value={editMaintainer}
                    onChange={(e) => setEditMaintainer(e.target.value)}
                    disabled={isSaving}
                    className="node-toolset__input node-toolset__input--readonly"
                    placeholder="Username (read-only for now)"
                    readOnly
                    title="Maintainer editing coming soon"
                  />
                  <span className="node-toolset__input-hint">
                    Maintainer selection coming in a future update
                  </span>
                </div>

                {originalData && (
                  <div className="node-toolset__metadata">
                    <strong>Author:</strong> {originalData.author_user?.title || 'Unknown'}<br />
                    <strong>Created:</strong> {originalData.createtime || 'Unknown'}
                  </div>
                )}
              </form>
            </div>
          )}

          {error && <div className="node-toolset__error">{error}</div>}

          <div className="node-toolset__modal-footer">
            <button
              type="button"
              onClick={closeEditModal}
              disabled={isSaving}
              className="node-toolset__modal-cancel"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleEdit}
              disabled={isSaving || isLoadingEdit || !editTitle.trim()}
              className="node-toolset__modal-action node-toolset__modal-action--save"
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

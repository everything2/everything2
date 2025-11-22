import React, { useState } from 'react'
import Modal from 'react-modal'
import { FaClone } from 'react-icons/fa'

const NodeCloner = ({ nodeId, nodeTitle, nodeType }) => {
  const [modalIsOpen, setModalIsOpen] = useState(false)
  const [newTitle, setNewTitle] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState(null)

  const openModal = () => {
    setModalIsOpen(true)
    setNewTitle('')
    setError(null)
  }

  const closeModal = () => {
    setModalIsOpen(false)
    setNewTitle('')
    setError(null)
  }

  const handleClone = async (e) => {
    e.preventDefault()
    if (!newTitle.trim()) return

    setIsSubmitting(true)
    setError(null)

    try {
      const response = await fetch(`/api/nodes/${nodeId}/action/clone`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ title: newTitle }),
      })

      const data = await response.json()

      if (response.ok) {
        // Navigate to the newly cloned node
        window.location.href = `/?node_id=${data.cloned_node_id}`
      } else {
        setError(data.error || 'Failed to clone node')
        setIsSubmitting(false)
      }
    } catch (err) {
      setError('Network error: ' + err.message)
      setIsSubmitting(false)
    }
  }

  return (
    <div className="nodelet_section" id="nodecloner">
      <h4 className="ns_title">Clone Node</h4>

      <p>
        <button onClick={openModal} style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
          <FaClone size={14} /> Clone this {nodeType}
        </button>
      </p>

      <Modal
        isOpen={modalIsOpen}
        onRequestClose={closeModal}
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
          <h2>Clone Node</h2>

          <p>
            Create a complete copy of{' '}
            <strong>
              {nodeTitle} ({nodeType})
            </strong>{' '}
            with a new title.
          </p>

          {error && (
            <div style={{ color: 'red', padding: '10px', marginBottom: '10px', border: '1px solid red' }}>
              {error}
            </div>
          )}

          <form onSubmit={handleClone}>
            <p>
              <label>
                <strong>New title:</strong>
                <br />
                <input
                  type="text"
                  value={newTitle}
                  onChange={(e) => setNewTitle(e.target.value)}
                  placeholder="Enter new node title..."
                  disabled={isSubmitting}
                  style={{ width: '100%', marginTop: '5px', padding: '5px' }}
                  autoFocus
                />
              </label>
            </p>

            <div style={{ fontSize: '0.9em', color: '#666', marginBottom: '15px' }}>
              <strong>Note:</strong> The cloned node will have all the same data as the original, but
              with a new title and node ID. You will be the author of the cloned node.
            </div>

            <div style={{ textAlign: 'right' }}>
              <button type="button" onClick={closeModal} disabled={isSubmitting} style={{ marginRight: '10px' }}>
                Cancel
              </button>
              <button type="submit" disabled={isSubmitting || !newTitle.trim()}>
                {isSubmitting ? 'Cloning...' : 'Clone Node'}
              </button>
            </div>
          </form>
        </div>
      </Modal>
    </div>
  )
}

export default NodeCloner

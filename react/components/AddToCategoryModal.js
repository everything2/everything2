import React, { useState, useEffect } from 'react'
import { FaFolderPlus } from 'react-icons/fa'

/**
 * AddToCategoryModal - Modal for adding a node to a category
 *
 * Shows available categories organized into:
 * - Your categories (owned by user or their usergroups)
 * - Public categories (owned by Guest User)
 * - Other categories (for editors only)
 *
 * Usage:
 *   <AddToCategoryModal
 *     nodeId={123}
 *     nodeTitle="Some Title"
 *     nodeType="writeup"
 *     user={userData}
 *     isOpen={boolean}
 *     onClose={() => setIsOpen(false)}
 *   />
 *
 * Or with the built-in button:
 *   <AddToCategoryButton nodeId={123} nodeTitle="Some Title" nodeType="writeup" user={userData} />
 */

const AddToCategoryModal = ({ nodeId, nodeTitle, nodeType, user, isOpen, onClose }) => {
  const [selectedCategory, setSelectedCategory] = useState('')
  const [isAdding, setIsAdding] = useState(false)
  const [categories, setCategories] = useState({ your: [], public: [], other: [] })
  const [isLoading, setIsLoading] = useState(false)
  const [actionStatus, setActionStatus] = useState(null)

  // Fetch available categories when modal opens
  useEffect(() => {
    if (!isOpen || user?.is_guest || user?.guest) return

    const fetchCategories = async () => {
      setIsLoading(true)
      try {
        const response = await fetch(`/api/category/list?node_id=${nodeId}`)
        const data = await response.json()
        if (data.success) {
          setCategories({
            your: data.your_categories || [],
            public: data.public_categories || [],
            other: data.other_categories || []
          })
        }
      } catch (error) {
        console.error('Failed to fetch categories:', error)
      } finally {
        setIsLoading(false)
      }
    }

    fetchCategories()
  }, [isOpen, user, nodeId])

  // Reset state when modal closes
  useEffect(() => {
    if (!isOpen) {
      setSelectedCategory('')
      setActionStatus(null)
    }
  }, [isOpen])

  if (!isOpen) return null

  const handleBackdropClick = (e) => {
    if (e.target === e.currentTarget) {
      onClose()
    }
  }

  const handleAddToCategory = async () => {
    if (!selectedCategory) {
      setActionStatus({ type: 'error', message: 'Please select a category' })
      return
    }

    setIsAdding(true)
    setActionStatus(null)

    try {
      const response = await fetch('/api/category/add_member', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category_id: parseInt(selectedCategory, 10),
          node_id: nodeId
        })
      })

      const data = await response.json()

      if (data.success) {
        setActionStatus({
          type: 'success',
          message: `Added to ${data.category_title}`
        })
        setSelectedCategory('')

        // Remove the category from the list (it's no longer available)
        setCategories(prev => ({
          your: prev.your.filter(c => String(c.node_id) !== String(selectedCategory)),
          public: prev.public.filter(c => String(c.node_id) !== String(selectedCategory)),
          other: prev.other.filter(c => String(c.node_id) !== String(selectedCategory))
        }))
      } else {
        setActionStatus({ type: 'error', message: data.error || 'Failed to add to category' })
      }
    } catch (error) {
      setActionStatus({ type: 'error', message: error.message })
    } finally {
      setIsAdding(false)
    }
  }

  const hasCategories = categories.your.length > 0 || categories.public.length > 0 || categories.other.length > 0
  const isEditor = !!(user?.is_editor || user?.editor)

  return (
    <div className="nodelet-modal-overlay" onClick={handleBackdropClick}>
      <div className="modal-compact">
        <div className="modal-compact__header">
          <h3 className="modal-compact__title">Add to Category</h3>
          <button onClick={onClose} className="modal-compact__close">&times;</button>
        </div>

        <div className="modal-compact__content">
          {/* Status message */}
          {actionStatus && (
            <div className={`modal-compact__status modal-compact__status--${actionStatus.type}`}>
              {actionStatus.message}
            </div>
          )}

          {isLoading ? (
            <p className="modal-compact__help">Loading categories...</p>
          ) : !hasCategories ? (
            <p className="modal-compact__help">
              No categories available. This {nodeType || 'item'} may already be in all available categories.
            </p>
          ) : (
            <>
              <p className="mb-3" style={{ fontSize: '12px', margin: 0 }}>
                Add <strong>{nodeTitle}</strong> to a category:
              </p>

              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="modal-compact__select"
                disabled={isAdding}
              >
                <option value="">Select a category...</option>

                {categories.your.length > 0 && (
                  <optgroup label="Your Categories">
                    {categories.your.map((cat) => (
                      <option key={cat.node_id} value={cat.node_id}>
                        {cat.title}
                      </option>
                    ))}
                  </optgroup>
                )}

                {categories.public.length > 0 && (
                  <optgroup label="Public Categories">
                    {categories.public.map((cat) => (
                      <option key={cat.node_id} value={cat.node_id}>
                        {cat.title}
                      </option>
                    ))}
                  </optgroup>
                )}

                {isEditor && categories.other.length > 0 && (
                  <optgroup label="Other Categories (Editors)">
                    {categories.other.map((cat) => (
                      <option key={cat.node_id} value={cat.node_id}>
                        {cat.title} ({cat.author_username})
                      </option>
                    ))}
                  </optgroup>
                )}
              </select>

              <button
                onClick={handleAddToCategory}
                disabled={!selectedCategory || isAdding}
                className="modal-compact__btn"
              >
                {isAdding ? 'Adding...' : 'Add to Category'}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

/**
 * AddToCategoryButton - Button that opens the AddToCategoryModal
 *
 * Only renders for users level > 1 or editors (matching legacy categoryform behavior)
 */
export const AddToCategoryButton = ({ nodeId, nodeTitle, nodeType, user, style }) => {
  const [isOpen, setIsOpen] = useState(false)

  // Only show for users level > 1 or editors
  const canAddToCategory = user && !user.is_guest && !user.guest && (
    (user.level && user.level > 1) || user.is_editor || user.editor
  )

  if (!canAddToCategory) return null

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        title="Add to category"
        className="icon-btn"
        style={style}
      >
        <FaFolderPlus />
      </button>

      <AddToCategoryModal
        nodeId={nodeId}
        nodeTitle={nodeTitle}
        nodeType={nodeType}
        user={user}
        isOpen={isOpen}
        onClose={() => setIsOpen(false)}
      />
    </>
  )
}

export default AddToCategoryModal

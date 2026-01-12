import React, { useState, useEffect } from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import ConfirmModal from '../ConfirmModal'
import { FaPlus, FaSpinner, FaFolder, FaGlobe, FaTimes, FaList, FaSearch, FaUser } from 'react-icons/fa'
import { fetchWithErrorReporting } from '../../utils/reportClientError'

/**
 * Categories Nodelet - Shows categories containing this node and allows adding/removing
 *
 * Features:
 * - Lists categories the current node belongs to (from page state)
 * - Shows remove button for categories user has permission to manage
 * - Modal dialog for adding to new categories
 * - Lazy-loads available categories on demand
 * - Search filter for finding categories
 */
const Categories = (props) => {
  const { currentNodeId, nodeCategories, updateNodeCategories } = props

  // State for removal operations
  const [removingFrom, setRemovingFrom] = useState(null)
  const [confirmRemove, setConfirmRemove] = useState(null) // { node_id, title }

  // Modal state
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [availableCategories, setAvailableCategories] = useState(null)
  const [loadError, setLoadError] = useState(null)
  const [addingTo, setAddingTo] = useState(null)
  const [searchFilter, setSearchFilter] = useState('')

  // Load categories when modal opens
  useEffect(() => {
    if (isModalOpen && availableCategories === null && !isLoading) {
      loadAvailableCategories()
    }
  }, [isModalOpen])

  // Handle ESC key to close modal
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isModalOpen) {
        setIsModalOpen(false)
      }
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [isModalOpen])

  const loadAvailableCategories = async () => {
    setIsLoading(true)
    setLoadError(null)

    try {
      const url = currentNodeId
        ? `/api/category/list?node_id=${currentNodeId}`
        : '/api/category/list'

      const response = await fetchWithErrorReporting(url, {
        credentials: 'same-origin'
      })
      const data = await response.json()

      if (data.success) {
        setAvailableCategories({
          your: data.your_categories || [],
          public: data.public_categories || [],
          other: data.other_categories || [],
          isEditor: data.is_editor || false
        })
      } else {
        setLoadError(data.error || 'Failed to load categories')
      }
    } catch (err) {
      setLoadError('Failed to load categories')
    } finally {
      setIsLoading(false)
    }
  }

  const handleAddToCategory = async (categoryId, categoryTitle) => {
    if (!currentNodeId) return

    setAddingTo(categoryId)

    try {
      const response = await fetchWithErrorReporting('/api/category/add_member', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category_id: categoryId,
          node_id: currentNodeId
        })
      })

      const data = await response.json()

      if (data.success) {
        // Remove from available list
        setAvailableCategories(prev => ({
          ...prev,
          your: prev.your.filter(c => c.node_id !== categoryId),
          public: prev.public.filter(c => c.node_id !== categoryId),
          other: prev.other.filter(c => c.node_id !== categoryId)
        }))

        // Add to current categories via parent state update
        const addedCat = availableCategories.your.find(c => c.node_id === categoryId)
          || availableCategories.public.find(c => c.node_id === categoryId)
          || availableCategories.other.find(c => c.node_id === categoryId)

        if (addedCat && updateNodeCategories) {
          updateNodeCategories([...(nodeCategories || []), {
            ...addedCat,
            can_remove: !addedCat.is_public // User can remove from non-public categories they add to
          }])
        }

        setIsModalOpen(false)
        setSearchFilter('')
      } else {
        alert(data.error || 'Failed to add to category')
      }
    } catch (err) {
      alert('Failed to add to category')
    } finally {
      setAddingTo(null)
    }
  }

  const promptRemoveFromCategory = (categoryId, categoryTitle) => {
    setConfirmRemove({ node_id: categoryId, title: categoryTitle })
  }

  const handleRemoveFromCategory = async () => {
    if (!currentNodeId || !confirmRemove) return

    const categoryId = confirmRemove.node_id
    setConfirmRemove(null)
    setRemovingFrom(categoryId)

    try {
      const response = await fetchWithErrorReporting('/api/category/remove_member', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          node_id: categoryId,
          member_id: currentNodeId
        })
      })

      const data = await response.json()

      if (data.success) {
        // Remove from current categories via parent state update
        if (updateNodeCategories) {
          updateNodeCategories(nodeCategories.filter(c => c.node_id !== categoryId))
        }

        // Reset available categories so they reload with updated list
        setAvailableCategories(null)
      } else {
        alert(data.error || 'Failed to remove from category')
      }
    } catch (err) {
      alert('Failed to remove from category')
    } finally {
      setRemovingFrom(null)
    }
  }

  const openModal = () => {
    setIsModalOpen(true)
    setSearchFilter('')
  }

  const closeModal = () => {
    setIsModalOpen(false)
    setSearchFilter('')
  }

  // Filter categories by search term
  const filterCategories = (cats) => {
    if (!searchFilter.trim()) return cats
    const term = searchFilter.toLowerCase()
    return cats.filter(c => c.title.toLowerCase().includes(term))
  }

  const hasAvailableCategories = availableCategories &&
    (availableCategories.your.length > 0 || availableCategories.public.length > 0 || availableCategories.other.length > 0)

  const hasCurrentCategories = nodeCategories && nodeCategories.length > 0

  const filteredYour = availableCategories ? filterCategories(availableCategories.your) : []
  const filteredPublic = availableCategories ? filterCategories(availableCategories.public) : []
  const filteredOther = availableCategories ? filterCategories(availableCategories.other) : []
  const hasFilteredResults = filteredYour.length > 0 || filteredPublic.length > 0 || filteredOther.length > 0

  return (
    <NodeletContainer
      id={props.id}
      title="Categories"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <div className="categories-content">
        {/* Current categories section */}
        {hasCurrentCategories && (
          <div className="categories-current">
            <div className="categories-section-header">
              <FaList size={10} className="categories-header-icon" />
              In Categories:
            </div>
            <ul className="categories-list">
              {nodeCategories.map(cat => (
                <li
                  key={cat.node_id}
                  className={`categories-item${removingFrom === cat.node_id ? ' categories-item--removing' : ''}`}
                >
                  <LinkNode
                    nodeId={cat.node_id}
                    title={cat.title}
                    type="category"
                  />
                  {cat.can_remove ? (
                    <button
                      onClick={() => promptRemoveFromCategory(cat.node_id, cat.title)}
                      disabled={removingFrom === cat.node_id}
                      title="Remove from category"
                      className="categories-remove-btn"
                    >
                      {removingFrom === cat.node_id ? (
                        <FaSpinner className="fa-spin" size={10} />
                      ) : (
                        <FaTimes size={10} />
                      )}
                    </button>
                  ) : null}
                </li>
              ))}
            </ul>
          </div>
        )}

        {!hasCurrentCategories && nodeCategories !== null && nodeCategories !== undefined && (
          <div className="categories-empty">
            Not in any categories
          </div>
        )}

        {/* Add to category button */}
        <button onClick={openModal} className="categories-add-btn">
          <FaPlus size={10} />
          Add to category
        </button>

        {/* Footer with create link */}
        <div className="categories-footer">
          <LinkNode
            title="Create category"
            type="superdoc"
            display="Create new category"
            className="categories-create-link"
          />
        </div>
      </div>

      {/* Add to Category Modal */}
      {isModalOpen && (
        <div className="categories-modal-overlay" onClick={closeModal}>
          <div className="categories-modal" onClick={(e) => e.stopPropagation()}>
            {/* Modal Header */}
            <div className="categories-modal-header">
              <h3 className="categories-modal-title">
                Add to Category
              </h3>
              <button onClick={closeModal} className="categories-modal-close">
                <FaTimes size={16} />
              </button>
            </div>

            {/* Search input */}
            {availableCategories && hasAvailableCategories && (
              <div className="categories-modal-search">
                <div className="categories-search-box">
                  <FaSearch size={12} className="categories-search-icon" />
                  <input
                    type="text"
                    placeholder="Search categories..."
                    value={searchFilter}
                    onChange={(e) => setSearchFilter(e.target.value)}
                    className="categories-search-input"
                    autoFocus
                  />
                  {searchFilter && (
                    <button onClick={() => setSearchFilter('')} className="categories-search-clear">
                      <FaTimes size={10} />
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* Modal Content */}
            <div className="categories-modal-content">
              {isLoading && (
                <div className="categories-modal-loading">
                  <FaSpinner className="fa-spin" size={20} />
                  <div>Loading categories...</div>
                </div>
              )}

              {loadError && (
                <div className="categories-modal-error">
                  {loadError}
                  <button onClick={loadAvailableCategories} className="categories-retry-btn">
                    Retry
                  </button>
                </div>
              )}

              {availableCategories && !hasAvailableCategories && (
                <div className="categories-modal-empty">
                  <em>No categories available to add to</em>
                </div>
              )}

              {availableCategories && hasAvailableCategories && !hasFilteredResults && searchFilter && (
                <div className="categories-modal-empty">
                  <em>No categories match "{searchFilter}"</em>
                </div>
              )}

              {/* Your Categories section */}
              {filteredYour.length > 0 && (
                <div>
                  <div className="categories-section-title">
                    <FaFolder size={12} className="categories-section-icon" />
                    Your Categories ({filteredYour.length})
                  </div>
                  <ul className="categories-modal-list">
                    {filteredYour.map(cat => (
                      <li key={cat.node_id}>
                        <button
                          onClick={() => handleAddToCategory(cat.node_id, cat.title)}
                          disabled={addingTo === cat.node_id}
                          className="categories-select-btn"
                        >
                          <span>{cat.title}</span>
                          {addingTo === cat.node_id && (
                            <FaSpinner className="fa-spin categories-spinner" size={12} />
                          )}
                        </button>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {/* Public Categories section */}
              {filteredPublic.length > 0 && (
                <div>
                  <div className={`categories-section-title${filteredYour.length > 0 ? ' categories-section-title--bordered' : ''}`}>
                    <FaGlobe size={12} className="categories-section-icon" />
                    Public Categories ({filteredPublic.length})
                  </div>
                  <ul className="categories-modal-list">
                    {filteredPublic.map(cat => (
                      <li key={cat.node_id}>
                        <button
                          onClick={() => handleAddToCategory(cat.node_id, cat.title)}
                          disabled={addingTo === cat.node_id}
                          className="categories-select-btn"
                        >
                          <span>{cat.title}</span>
                          {addingTo === cat.node_id && (
                            <FaSpinner className="fa-spin categories-spinner" size={12} />
                          )}
                        </button>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {/* Other Users' Categories section (editors only) */}
              {filteredOther.length > 0 && (
                <div>
                  <div className={`categories-section-title${(filteredYour.length > 0 || filteredPublic.length > 0) ? ' categories-section-title--bordered' : ''}`}>
                    <FaUser size={12} className="categories-section-icon" />
                    Other Users' Categories ({filteredOther.length})
                  </div>
                  <ul className="categories-modal-list">
                    {filteredOther.map(cat => (
                      <li key={cat.node_id}>
                        <button
                          onClick={() => handleAddToCategory(cat.node_id, cat.title)}
                          disabled={addingTo === cat.node_id}
                          className="categories-select-btn"
                        >
                          <span>
                            {cat.title}
                            <span className="categories-author">
                              by {cat.author_username}
                            </span>
                          </span>
                          {addingTo === cat.node_id && (
                            <FaSpinner className="fa-spin categories-spinner" size={12} />
                          )}
                        </button>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="categories-modal-footer">
              <LinkNode
                title="Create category"
                type="superdoc"
                display="Create new category"
                className="categories-create-link"
              />
              <button onClick={closeModal} className="categories-cancel-btn">
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Remove Modal */}
      <ConfirmModal
        isOpen={confirmRemove !== null}
        onClose={() => setConfirmRemove(null)}
        onConfirm={handleRemoveFromCategory}
        title="Remove from Category"
        message={confirmRemove ? (
          <>
            Remove this node from <strong>"{confirmRemove.title}"</strong>?
          </>
        ) : ''}
        confirmText="Remove"
        cancelText="Cancel"
        confirmColor="#c62828"
      />
    </NodeletContainer>
  )
}

export default Categories

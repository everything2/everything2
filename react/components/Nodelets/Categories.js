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
      <div style={{ padding: '8px' }}>
        {/* Current categories section */}
        {hasCurrentCategories && (
          <div style={{ marginBottom: '12px' }}>
            <div style={{
              fontSize: '11px',
              fontWeight: 'bold',
              color: '#38495e',
              marginBottom: '6px',
              display: 'flex',
              alignItems: 'center',
              gap: '6px'
            }}>
              <FaList size={10} style={{ color: '#4060b0' }} />
              In Categories:
            </div>
            <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
              {nodeCategories.map(cat => (
                <li
                  key={cat.node_id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '4px 6px',
                    fontSize: '12px',
                    borderBottom: '1px solid #eee',
                    backgroundColor: removingFrom === cat.node_id ? '#fff3f3' : 'transparent'
                  }}
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
                      style={{
                        background: 'none',
                        border: 'none',
                        padding: '2px 4px',
                        cursor: removingFrom === cat.node_id ? 'wait' : 'pointer',
                        color: '#999',
                        display: 'flex',
                        alignItems: 'center'
                      }}
                      onMouseOver={(e) => e.currentTarget.style.color = '#c62828'}
                      onMouseOut={(e) => e.currentTarget.style.color = '#999'}
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
          <div style={{
            padding: '8px',
            fontSize: '12px',
            color: '#666',
            fontStyle: 'italic',
            textAlign: 'center',
            marginBottom: '8px'
          }}>
            Not in any categories
          </div>
        )}

        {/* Add to category button */}
        <button
          onClick={openModal}
          style={{
            width: '100%',
            padding: '8px 12px',
            fontSize: '12px',
            backgroundColor: '#f5f5f5',
            border: '1px solid #ccc',
            borderRadius: '4px',
            cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '6px'
          }}
        >
          <FaPlus size={10} />
          Add to category
        </button>

        {/* Footer with create link */}
        <div style={{ marginTop: '8px', textAlign: 'center' }}>
          <LinkNode
            title="Create category"
            type="superdoc"
            display="Create new category"
            style={{ fontSize: '11px' }}
          />
        </div>
      </div>

      {/* Add to Category Modal */}
      {isModalOpen && (
        <div
          style={{
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
          }}
          onClick={closeModal}
        >
          <div
            style={{
              backgroundColor: '#fff',
              borderRadius: '8px',
              maxWidth: '450px',
              width: '100%',
              maxHeight: '80vh',
              display: 'flex',
              flexDirection: 'column',
              boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
              position: 'relative'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div style={{
              padding: '16px 20px',
              borderBottom: '2px solid #4060b0',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center'
            }}>
              <h3 style={{ margin: 0, color: '#4060b0', fontSize: '16px' }}>
                Add to Category
              </h3>
              <button
                onClick={closeModal}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: '#666',
                  padding: '4px',
                  display: 'flex',
                  alignItems: 'center'
                }}
              >
                <FaTimes size={16} />
              </button>
            </div>

            {/* Search input */}
            {availableCategories && hasAvailableCategories && (
              <div style={{ padding: '12px 20px', borderBottom: '1px solid #eee' }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  padding: '6px 10px',
                  backgroundColor: '#f9f9f9'
                }}>
                  <FaSearch size={12} style={{ color: '#999', marginRight: '8px' }} />
                  <input
                    type="text"
                    placeholder="Search categories..."
                    value={searchFilter}
                    onChange={(e) => setSearchFilter(e.target.value)}
                    style={{
                      border: 'none',
                      background: 'transparent',
                      outline: 'none',
                      flex: 1,
                      fontSize: '13px'
                    }}
                    autoFocus
                  />
                  {searchFilter && (
                    <button
                      onClick={() => setSearchFilter('')}
                      style={{
                        background: 'none',
                        border: 'none',
                        cursor: 'pointer',
                        color: '#999',
                        padding: '2px'
                      }}
                    >
                      <FaTimes size={10} />
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* Modal Content */}
            <div style={{
              flex: 1,
              overflowY: 'auto',
              padding: '0'
            }}>
              {isLoading && (
                <div style={{
                  padding: '40px 20px',
                  textAlign: 'center',
                  color: '#666'
                }}>
                  <FaSpinner className="fa-spin" size={20} style={{ marginBottom: '12px' }} />
                  <div style={{ fontSize: '13px' }}>Loading categories...</div>
                </div>
              )}

              {loadError && (
                <div style={{
                  padding: '20px',
                  color: '#c62828',
                  fontSize: '13px',
                  textAlign: 'center'
                }}>
                  {loadError}
                  <button
                    onClick={loadAvailableCategories}
                    style={{
                      display: 'block',
                      margin: '12px auto 0',
                      padding: '6px 12px',
                      fontSize: '12px',
                      border: '1px solid #ccc',
                      borderRadius: '4px',
                      backgroundColor: '#f5f5f5',
                      cursor: 'pointer'
                    }}
                  >
                    Retry
                  </button>
                </div>
              )}

              {availableCategories && !hasAvailableCategories && (
                <div style={{
                  padding: '40px 20px',
                  color: '#666',
                  fontSize: '13px',
                  textAlign: 'center'
                }}>
                  <em>No categories available to add to</em>
                </div>
              )}

              {availableCategories && hasAvailableCategories && !hasFilteredResults && searchFilter && (
                <div style={{
                  padding: '40px 20px',
                  color: '#666',
                  fontSize: '13px',
                  textAlign: 'center'
                }}>
                  <em>No categories match "{searchFilter}"</em>
                </div>
              )}

              {/* Your Categories section */}
              {filteredYour.length > 0 && (
                <div>
                  <div style={{
                    padding: '8px 20px',
                    backgroundColor: '#f0f4f8',
                    borderBottom: '1px solid #e0e0e0',
                    fontSize: '12px',
                    fontWeight: 'bold',
                    color: '#38495e',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    position: 'sticky',
                    top: 0
                  }}>
                    <FaFolder size={12} style={{ color: '#4060b0' }} />
                    Your Categories ({filteredYour.length})
                  </div>
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                    {filteredYour.map(cat => (
                      <li key={cat.node_id}>
                        <button
                          onClick={() => handleAddToCategory(cat.node_id, cat.title)}
                          disabled={addingTo === cat.node_id}
                          style={{
                            width: '100%',
                            padding: '10px 20px',
                            textAlign: 'left',
                            border: 'none',
                            borderBottom: '1px solid #eee',
                            backgroundColor: 'white',
                            cursor: addingTo === cat.node_id ? 'wait' : 'pointer',
                            fontSize: '13px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between'
                          }}
                          onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#f5f8ff'}
                          onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'white'}
                        >
                          <span>{cat.title}</span>
                          {addingTo === cat.node_id && (
                            <FaSpinner className="fa-spin" size={12} style={{ color: '#4060b0' }} />
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
                  <div style={{
                    padding: '8px 20px',
                    backgroundColor: '#f0f4f8',
                    borderBottom: '1px solid #e0e0e0',
                    borderTop: filteredYour.length > 0 ? '1px solid #e0e0e0' : 'none',
                    fontSize: '12px',
                    fontWeight: 'bold',
                    color: '#38495e',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    position: 'sticky',
                    top: 0
                  }}>
                    <FaGlobe size={12} style={{ color: '#4060b0' }} />
                    Public Categories ({filteredPublic.length})
                  </div>
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                    {filteredPublic.map(cat => (
                      <li key={cat.node_id}>
                        <button
                          onClick={() => handleAddToCategory(cat.node_id, cat.title)}
                          disabled={addingTo === cat.node_id}
                          style={{
                            width: '100%',
                            padding: '10px 20px',
                            textAlign: 'left',
                            border: 'none',
                            borderBottom: '1px solid #eee',
                            backgroundColor: 'white',
                            cursor: addingTo === cat.node_id ? 'wait' : 'pointer',
                            fontSize: '13px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between'
                          }}
                          onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#f5f8ff'}
                          onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'white'}
                        >
                          <span>{cat.title}</span>
                          {addingTo === cat.node_id && (
                            <FaSpinner className="fa-spin" size={12} style={{ color: '#4060b0' }} />
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
                  <div style={{
                    padding: '8px 20px',
                    backgroundColor: '#f0f4f8',
                    borderBottom: '1px solid #e0e0e0',
                    borderTop: (filteredYour.length > 0 || filteredPublic.length > 0) ? '1px solid #e0e0e0' : 'none',
                    fontSize: '12px',
                    fontWeight: 'bold',
                    color: '#38495e',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    position: 'sticky',
                    top: 0
                  }}>
                    <FaUser size={12} style={{ color: '#4060b0' }} />
                    Other Users' Categories ({filteredOther.length})
                  </div>
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                    {filteredOther.map(cat => (
                      <li key={cat.node_id}>
                        <button
                          onClick={() => handleAddToCategory(cat.node_id, cat.title)}
                          disabled={addingTo === cat.node_id}
                          style={{
                            width: '100%',
                            padding: '10px 20px',
                            textAlign: 'left',
                            border: 'none',
                            borderBottom: '1px solid #eee',
                            backgroundColor: 'white',
                            cursor: addingTo === cat.node_id ? 'wait' : 'pointer',
                            fontSize: '13px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between'
                          }}
                          onMouseOver={(e) => e.currentTarget.style.backgroundColor = '#f5f8ff'}
                          onMouseOut={(e) => e.currentTarget.style.backgroundColor = 'white'}
                        >
                          <span>
                            {cat.title}
                            <span style={{ color: '#999', fontSize: '11px', marginLeft: '8px' }}>
                              by {cat.author_username}
                            </span>
                          </span>
                          {addingTo === cat.node_id && (
                            <FaSpinner className="fa-spin" size={12} style={{ color: '#4060b0' }} />
                          )}
                        </button>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div style={{
              padding: '12px 20px',
              borderTop: '1px solid #eee',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center'
            }}>
              <LinkNode
                title="Create category"
                type="superdoc"
                display="Create new category"
                style={{ fontSize: '12px' }}
              />
              <button
                onClick={closeModal}
                style={{
                  padding: '8px 16px',
                  fontSize: '13px',
                  border: '1px solid #dee2e6',
                  borderRadius: '4px',
                  backgroundColor: '#fff',
                  color: '#495057',
                  cursor: 'pointer'
                }}
              >
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

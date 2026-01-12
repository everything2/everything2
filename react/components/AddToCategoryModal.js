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

// Styles matching Kernel Blue theme
const styles = {
  backdrop: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.4)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 10000
  },
  modal: {
    backgroundColor: '#fff',
    border: '1px solid #38495e',
    maxWidth: '400px',
    width: '90%',
    maxHeight: '80vh',
    overflow: 'auto',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif',
    fontSize: '12px'
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '8px 12px',
    backgroundColor: '#38495e',
    color: '#f9fafa'
  },
  title: {
    margin: 0,
    fontSize: '13px',
    fontWeight: 'bold'
  },
  closeButton: {
    background: 'none',
    border: 'none',
    fontSize: '18px',
    cursor: 'pointer',
    color: '#f9fafa',
    padding: '0 4px',
    lineHeight: 1
  },
  content: {
    padding: '12px'
  },
  status: {
    padding: '6px 10px',
    marginBottom: '12px',
    fontSize: '11px',
    border: '1px solid'
  },
  section: {
    marginBottom: '12px'
  },
  sectionTitle: {
    fontSize: '11px',
    fontWeight: 'bold',
    color: '#507898',
    marginBottom: '4px',
    marginTop: 0,
    textTransform: 'uppercase'
  },
  select: {
    width: '100%',
    padding: '6px',
    marginBottom: '8px',
    border: '1px solid #d3d3d3',
    fontSize: '12px',
    boxSizing: 'border-box',
    fontFamily: 'Verdana, Tahoma, Arial Unicode MS, sans-serif'
  },
  actionButton: {
    display: 'block',
    width: '100%',
    padding: '6px 10px',
    border: '1px solid #4060b0',
    backgroundColor: '#4060b0',
    color: '#fff',
    cursor: 'pointer',
    fontSize: '12px',
    textAlign: 'center',
    fontWeight: 'bold'
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
    borderColor: '#ccc',
    cursor: 'not-allowed'
  },
  helpText: {
    fontSize: '11px',
    color: '#507898',
    margin: '4px 0 0 0'
  },
  iconButton: {
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    fontSize: '20px',
    color: '#507898',
    padding: '4px',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: '4px'
  }
}

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
    <div style={styles.backdrop} onClick={handleBackdropClick}>
      <div style={styles.modal}>
        <div style={styles.header}>
          <h3 style={styles.title}>Add to Category</h3>
          <button onClick={onClose} style={styles.closeButton}>&times;</button>
        </div>

        <div style={styles.content}>
          {/* Status message */}
          {actionStatus && (
            <div style={{
              ...styles.status,
              backgroundColor: actionStatus.type === 'error' ? '#fee' : '#efe',
              color: actionStatus.type === 'error' ? '#c00' : '#060'
            }}>
              {actionStatus.message}
            </div>
          )}

          {isLoading ? (
            <p style={styles.helpText}>Loading categories...</p>
          ) : !hasCategories ? (
            <p style={styles.helpText}>
              No categories available. This {nodeType || 'item'} may already be in all available categories.
            </p>
          ) : (
            <>
              <p style={{ margin: '0 0 12px 0', fontSize: '12px' }}>
                Add <strong>{nodeTitle}</strong> to a category:
              </p>

              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                style={styles.select}
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
                style={{
                  ...styles.actionButton,
                  ...(!selectedCategory || isAdding ? styles.buttonDisabled : {})
                }}
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
        style={{ ...styles.iconButton, ...style }}
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

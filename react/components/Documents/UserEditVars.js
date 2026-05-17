import React, { useState } from 'react'
import { FaPlus, FaTrash, FaSave, FaTimes, FaEdit, FaArrowLeft } from 'react-icons/fa'
import LinkNode from '../LinkNode'

/**
 * UserEditVars Component - Admin tool for editing user vars
 * Styles in CSS: .user-edit-vars__*
 *
 * Admin-only component for viewing and editing key-value pairs
 * stored in a user's vars field.
 */
export default function UserEditVars({ data }) {
  const { target_user, vars: initialVars, viewer } = data
  const [vars, setVars] = useState(initialVars || [])
  const [newKey, setNewKey] = useState('')
  const [newValue, setNewValue] = useState('')
  const [saveStatus, setSaveStatus] = useState(null)
  const [editingIndex, setEditingIndex] = useState(null)
  const [editValue, setEditValue] = useState('')

  if (!target_user) {
    return <div className="error">User not found</div>
  }

  // Handle adding a new var
  const handleAddVar = async () => {
    if (!newKey.trim()) {
      setSaveStatus({ type: 'error', message: 'Key is required' })
      return
    }

    // Validate key format (alphanumeric, underscores, hyphens - can start with number)
    if (!/^[a-zA-Z0-9_][a-zA-Z0-9_\-]*$/.test(newKey)) {
      setSaveStatus({ type: 'error', message: 'Invalid key format. Use letters, numbers, underscores, and hyphens.' })
      return
    }

    // Check for duplicate key
    if (vars.some(v => v.key === newKey)) {
      setSaveStatus({ type: 'error', message: 'Key already exists' })
      return
    }

    setSaveStatus({ type: 'saving', message: 'Adding...' })

    try {
      const response = await fetch(`/api/nodevars/${target_user.node_id}/set`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ key: newKey, value: newValue })
      })

      const result = await response.json()

      if (result.success) {
        // Add to local state and sort
        const newVars = [...vars, { key: newKey, value: newValue }]
        newVars.sort((a, b) => a.key.localeCompare(b.key))
        setVars(newVars)
        setNewKey('')
        setNewValue('')
        setSaveStatus({ type: 'success', message: 'Added successfully' })
        setTimeout(() => setSaveStatus(null), 2000)
      } else {
        setSaveStatus({ type: 'error', message: result.error || 'Failed to add' })
      }
    } catch (err) {
      setSaveStatus({ type: 'error', message: err.message })
    }
  }

  // Handle updating a var
  const handleUpdateVar = async (key) => {
    setSaveStatus({ type: 'saving', message: 'Saving...' })

    try {
      const response = await fetch(`/api/nodevars/${target_user.node_id}/set`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ key, value: editValue })
      })

      const result = await response.json()

      if (result.success) {
        // Update local state
        setVars(vars.map(v => v.key === key ? { ...v, value: editValue } : v))
        setEditingIndex(null)
        setEditValue('')
        setSaveStatus({ type: 'success', message: 'Saved' })
        setTimeout(() => setSaveStatus(null), 2000)
      } else {
        setSaveStatus({ type: 'error', message: result.error || 'Failed to save' })
      }
    } catch (err) {
      setSaveStatus({ type: 'error', message: err.message })
    }
  }

  // Handle deleting a var
  const handleDeleteVar = async (key) => {
    if (!confirm(`Delete key "${key}"?`)) return

    setSaveStatus({ type: 'saving', message: 'Deleting...' })

    try {
      const response = await fetch(`/api/nodevars/${target_user.node_id}/delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ key })
      })

      const result = await response.json()

      if (result.success) {
        setVars(vars.filter(v => v.key !== key))
        setSaveStatus({ type: 'success', message: 'Deleted' })
        setTimeout(() => setSaveStatus(null), 2000)
      } else {
        setSaveStatus({ type: 'error', message: result.error || 'Failed to delete' })
      }
    } catch (err) {
      setSaveStatus({ type: 'error', message: err.message })
    }
  }

  // Start editing a value
  const startEditing = (index, currentValue) => {
    setEditingIndex(index)
    setEditValue(currentValue || '')
  }

  // Cancel editing
  const cancelEditing = () => {
    setEditingIndex(null)
    setEditValue('')
  }

  // Render value with truncation for long values
  const renderValue = (value) => {
    if (value === null || value === undefined) return <span className="user-edit-vars__empty-value">(null)</span>
    if (value === '') return <span className="user-edit-vars__empty-value">(empty)</span>
    const strValue = String(value)
    if (strValue.length > 100) {
      return (
        <span title={strValue}>
          {strValue.substring(0, 100)}...
          <span className="user-edit-vars__truncated"> ({strValue.length} chars)</span>
        </span>
      )
    }
    return strValue
  }

  return (
    <div className="user-edit-vars">
      {/* Header */}
      <div className="user-edit-vars__header">
        <div>
          <h1 className="user-edit-vars__title">
            User Vars: <LinkNode nodeId={target_user.node_id} title={target_user.title} type="user" />
          </h1>
          <a href={`/node/${target_user.node_id}`} className="user-edit-vars__back-link">
            <FaArrowLeft className="user-edit-vars__back-icon" />
            Back to homenode
          </a>
        </div>
      </div>

      {/* Statistics */}
      <div className="user-edit-vars__stats-box">
        <p className="user-edit-vars__stat-line">
          <strong>User ID:</strong> {target_user.node_id}
        </p>
        <p className="user-edit-vars__stat-line">
          <strong>Variables:</strong> {vars.length}
        </p>
      </div>

      {/* Status message */}
      {saveStatus && (
        <div className={`user-edit-vars__status-box user-edit-vars__status-box--${saveStatus.type}`}>
          {saveStatus.message}
        </div>
      )}

      {/* Add new var form */}
      <div className="user-edit-vars__add-form">
        <h3 className="user-edit-vars__add-form-title">Add New Variable</h3>
        <div className="user-edit-vars__add-form-row">
          <input
            type="text"
            placeholder="Key"
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
            className="user-edit-vars__input"
          />
          <input
            type="text"
            placeholder="Value"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
            className="user-edit-vars__input user-edit-vars__input--wide"
          />
          <button onClick={handleAddVar} className="user-edit-vars__add-button">
            <FaPlus /> Add
          </button>
        </div>
      </div>

      {/* Vars Table */}
      <div className="user-edit-vars__section">
        <h2 className="user-edit-vars__section-title">User Variables ({vars.length})</h2>
        {vars.length === 0 ? (
          <p className="user-edit-vars__no-data">No variables stored for this user.</p>
        ) : (
          <div className="user-edit-vars__table-wrapper">
            <table className="user-edit-vars__table">
              <thead>
                <tr className="user-edit-vars__header-row">
                  <th className="user-edit-vars__th">Key</th>
                  <th className="user-edit-vars__th">Value</th>
                  <th className="user-edit-vars__th user-edit-vars__th--actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {vars.map((v, idx) => (
                  <tr key={v.key} className={idx % 2 === 0 ? 'user-edit-vars__even-row' : 'user-edit-vars__odd-row'}>
                    <td className="user-edit-vars__key-cell">{v.key}</td>
                    <td className="user-edit-vars__value-cell">
                      {editingIndex === idx ? (
                        <textarea
                          value={editValue}
                          onChange={(e) => setEditValue(e.target.value)}
                          className="user-edit-vars__edit-textarea"
                          rows={3}
                        />
                      ) : (
                        renderValue(v.value)
                      )}
                    </td>
                    <td className="user-edit-vars__actions-cell">
                      {editingIndex === idx ? (
                        <>
                          <button
                            onClick={() => handleUpdateVar(v.key)}
                            className="user-edit-vars__save-button"
                            title="Save"
                          >
                            <FaSave />
                          </button>
                          <button
                            onClick={cancelEditing}
                            className="user-edit-vars__cancel-button"
                            title="Cancel"
                          >
                            <FaTimes />
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => startEditing(idx, v.value)}
                            className="user-edit-vars__edit-button"
                            title="Edit"
                          >
                            <FaEdit />
                          </button>
                          <button
                            onClick={() => handleDeleteVar(v.key)}
                            className="user-edit-vars__delete-button"
                            title="Delete"
                          >
                            <FaTrash />
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Warning box */}
      <div className="user-edit-vars__warning-box">
        <strong>Warning:</strong> Modifying user vars directly can cause unexpected behavior.
        Many preferences are stored here. Only make changes if you know what you're doing.
      </div>
    </div>
  )
}

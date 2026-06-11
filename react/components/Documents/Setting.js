import React, { useState, useEffect } from 'react'
import { FaEdit, FaPlus, FaTrash, FaSave, FaTimes } from 'react-icons/fa'

/**
 * Setting Component - Display and edit setting node vars
 * Styles in CSS: .setting__*
 *
 * Admin-only component for viewing and editing key-value pairs
 * stored in a setting node's vars field.
 */
export default function Setting({ data }) {
  const { setting, displaytype: initialDisplaytype, user } = data
  const [isEditing, setIsEditing] = useState(initialDisplaytype === 'edit')
  const [vars, setVars] = useState(setting?.vars || [])
  const [newKey, setNewKey] = useState('')
  const [newValue, setNewValue] = useState('')
  const [saveStatus, setSaveStatus] = useState(null)
  const [editingIndex, setEditingIndex] = useState(null)
  const [editValue, setEditValue] = useState('')

  if (!setting) {
    return <div className="error">Setting not found</div>
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
      const response = await fetch(`/api/nodevars/${setting.node_id}/set`, {
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
      const response = await fetch(`/api/nodevars/${setting.node_id}/set`, {
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
      const response = await fetch(`/api/nodevars/${setting.node_id}/delete`, {
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
    setEditValue(currentValue)
  }

  // Cancel editing
  const cancelEditing = () => {
    setEditingIndex(null)
    setEditValue('')
  }

  // Render value with truncation for long values
  const renderValue = (value) => {
    if (!value) return <span className="setting__empty-value">(empty)</span>
    const strValue = String(value)
    if (strValue.length > 100) {
      return (
        <span title={strValue}>
          {strValue.substring(0, 100)}...
          <span className="setting__truncated"> ({strValue.length} chars)</span>
        </span>
      )
    }
    return strValue
  }

  // Get status box class based on type
  const getStatusBoxClass = () => {
    if (!saveStatus) return 'setting__status-box'
    const typeClass = saveStatus.type === 'error' ? 'setting__status-box--error' :
                     saveStatus.type === 'success' ? 'setting__status-box--success' :
                     'setting__status-box--saving'
    return `setting__status-box ${typeClass}`
  }

  // Display mode
  if (!isEditing) {
    return (
      <div className="setting">
        {/* Page title is already rendered by PageHeader; only show the
            Edit button (admins) here as the page action. */}
        {!!user?.is_admin && (
          <div className="setting__header">
            <button
              onClick={() => setIsEditing(true)}
              className="setting__edit-button"
              title="Edit settings"
            >
              <FaEdit /> Edit
            </button>
          </div>
        )}

        {/* Statistics */}
        <div className="setting__stats-box">
          <p className="setting__stat-line">
            <strong>Node ID:</strong> {setting.node_id}
          </p>
          <p className="setting__stat-line">
            <strong>Variables:</strong> {vars.length}
          </p>
        </div>

        {/* Vars Table */}
        <div className="setting__section">
          <h2 className="setting__section-title">Settings Variables</h2>
          {vars.length === 0 ? (
            <p className="setting__no-data">No variables defined.</p>
          ) : (
            <div className="setting__table-wrapper">
              <table className="setting__table">
                <thead>
                  <tr className="setting__header-row">
                    <th className="setting__th">Key</th>
                    <th className="setting__th">Value</th>
                  </tr>
                </thead>
                <tbody>
                  {vars.map((v, idx) => (
                    <tr key={v.key} className={idx % 2 === 0 ? 'setting__even-row' : 'setting__odd-row'}>
                      <td className="setting__key-cell">{v.key}</td>
                      <td className="setting__value-cell">{renderValue(v.value)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    )
  }

  // Edit mode
  return (
    <div className="setting">
      {/* Page title is already rendered by PageHeader; only show the
          Done button as the page action. */}
      <div className="setting__header">
        <button
          onClick={() => setIsEditing(false)}
          className="setting__cancel-button"
        >
          <FaTimes /> Done
        </button>
      </div>

      {/* Status message */}
      {saveStatus && (
        <div className={getStatusBoxClass()}>
          {saveStatus.message}
        </div>
      )}

      {/* Add new var form */}
      <div className="setting__add-form">
        <h3 className="setting__add-form-title">Add New Variable</h3>
        <div className="setting__add-form-row">
          <input
            type="text"
            placeholder="Key"
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
            className="setting__input"
          />
          <input
            type="text"
            placeholder="Value"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
            className="setting__input setting__input--wide"
          />
          <button onClick={handleAddVar} className="setting__add-button">
            <FaPlus /> Add
          </button>
        </div>
      </div>

      {/* Vars Table with editing */}
      <div className="setting__section">
        <h2 className="setting__section-title">Variables ({vars.length})</h2>
        {vars.length === 0 ? (
          <p className="setting__no-data">No variables defined. Add one above.</p>
        ) : (
          <div className="setting__table-wrapper">
            <table className="setting__table">
              <thead>
                <tr className="setting__header-row">
                  <th className="setting__th">Key</th>
                  <th className="setting__th">Value</th>
                  <th className="setting__th setting__th--actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {vars.map((v, idx) => (
                  <tr key={v.key} className={idx % 2 === 0 ? 'setting__even-row' : 'setting__odd-row'}>
                    <td className="setting__key-cell">{v.key}</td>
                    <td className="setting__value-cell">
                      {editingIndex === idx ? (
                        <textarea
                          value={editValue}
                          onChange={(e) => setEditValue(e.target.value)}
                          className="setting__edit-textarea"
                          rows={3}
                        />
                      ) : (
                        renderValue(v.value)
                      )}
                    </td>
                    <td className="setting__actions-cell">
                      {editingIndex === idx ? (
                        <>
                          <button
                            onClick={() => handleUpdateVar(v.key)}
                            className="setting__save-button"
                            title="Save"
                          >
                            <FaSave />
                          </button>
                          <button
                            onClick={cancelEditing}
                            className="setting__cancel-small-button"
                            title="Cancel"
                          >
                            <FaTimes />
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => startEditing(idx, v.value)}
                            className="setting__edit-small-button"
                            title="Edit"
                          >
                            <FaEdit />
                          </button>
                          <button
                            onClick={() => handleDeleteVar(v.key)}
                            className="setting__delete-button"
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

      {/* Info box */}
      <div className="setting__info-box">
        <strong>Note:</strong> Changes are saved immediately when you click Add, Save, or Delete.
        Be careful when modifying settings as they may affect site functionality.
      </div>
    </div>
  )
}

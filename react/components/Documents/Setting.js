import React, { useState, useEffect } from 'react'
import { FaEdit, FaPlus, FaTrash, FaSave, FaTimes } from 'react-icons/fa'

/**
 * Setting Component - Display and edit setting node vars
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
    if (!value) return <span style={styles.emptyValue}>(empty)</span>
    const strValue = String(value)
    if (strValue.length > 100) {
      return (
        <span title={strValue}>
          {strValue.substring(0, 100)}...
          <span style={styles.truncated}> ({strValue.length} chars)</span>
        </span>
      )
    }
    return strValue
  }

  // Display mode
  if (!isEditing) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Setting: {setting.title}</h1>
          {user?.is_admin && (
            <button
              onClick={() => setIsEditing(true)}
              style={styles.editButton}
              title="Edit settings"
            >
              <FaEdit /> Edit
            </button>
          )}
        </div>

        {/* Statistics */}
        <div style={styles.statsBox}>
          <p style={styles.statLine}>
            <strong>Node ID:</strong> {setting.node_id}
          </p>
          <p style={styles.statLine}>
            <strong>Variables:</strong> {vars.length}
          </p>
        </div>

        {/* Vars Table */}
        <div style={styles.section}>
          <h2 style={styles.sectionTitle}>Settings Variables</h2>
          {vars.length === 0 ? (
            <p style={styles.noData}>No variables defined.</p>
          ) : (
            <div style={styles.tableWrapper}>
              <table style={styles.table}>
                <thead>
                  <tr style={styles.headerRow}>
                    <th style={styles.th}>Key</th>
                    <th style={styles.th}>Value</th>
                  </tr>
                </thead>
                <tbody>
                  {vars.map((v, idx) => (
                    <tr key={v.key} style={idx % 2 === 0 ? styles.evenRow : styles.oddRow}>
                      <td style={styles.keyCell}>{v.key}</td>
                      <td style={styles.valueCell}>{renderValue(v.value)}</td>
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
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Editing: {setting.title}</h1>
        <button
          onClick={() => setIsEditing(false)}
          style={styles.cancelButton}
        >
          <FaTimes /> Done
        </button>
      </div>

      {/* Status message */}
      {saveStatus && (
        <div style={{
          ...styles.statusBox,
          backgroundColor: saveStatus.type === 'error' ? '#fee' :
                          saveStatus.type === 'success' ? '#efe' : '#fff3cd',
          color: saveStatus.type === 'error' ? '#c00' :
                 saveStatus.type === 'success' ? '#060' : '#856404'
        }}>
          {saveStatus.message}
        </div>
      )}

      {/* Add new var form */}
      <div style={styles.addForm}>
        <h3 style={styles.addFormTitle}>Add New Variable</h3>
        <div style={styles.addFormRow}>
          <input
            type="text"
            placeholder="Key"
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
            style={styles.input}
          />
          <input
            type="text"
            placeholder="Value"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
            style={{ ...styles.input, flex: 2 }}
          />
          <button onClick={handleAddVar} style={styles.addButton}>
            <FaPlus /> Add
          </button>
        </div>
      </div>

      {/* Vars Table with editing */}
      <div style={styles.section}>
        <h2 style={styles.sectionTitle}>Variables ({vars.length})</h2>
        {vars.length === 0 ? (
          <p style={styles.noData}>No variables defined. Add one above.</p>
        ) : (
          <div style={styles.tableWrapper}>
            <table style={styles.table}>
              <thead>
                <tr style={styles.headerRow}>
                  <th style={styles.th}>Key</th>
                  <th style={styles.th}>Value</th>
                  <th style={{ ...styles.th, width: '120px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {vars.map((v, idx) => (
                  <tr key={v.key} style={idx % 2 === 0 ? styles.evenRow : styles.oddRow}>
                    <td style={styles.keyCell}>{v.key}</td>
                    <td style={styles.valueCell}>
                      {editingIndex === idx ? (
                        <textarea
                          value={editValue}
                          onChange={(e) => setEditValue(e.target.value)}
                          style={styles.editTextarea}
                          rows={3}
                        />
                      ) : (
                        renderValue(v.value)
                      )}
                    </td>
                    <td style={styles.actionsCell}>
                      {editingIndex === idx ? (
                        <>
                          <button
                            onClick={() => handleUpdateVar(v.key)}
                            style={styles.saveButton}
                            title="Save"
                          >
                            <FaSave />
                          </button>
                          <button
                            onClick={cancelEditing}
                            style={styles.cancelSmallButton}
                            title="Cancel"
                          >
                            <FaTimes />
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => startEditing(idx, v.value)}
                            style={styles.editSmallButton}
                            title="Edit"
                          >
                            <FaEdit />
                          </button>
                          <button
                            onClick={() => handleDeleteVar(v.key)}
                            style={styles.deleteButton}
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
      <div style={styles.infoBox}>
        <strong>Note:</strong> Changes are saved immediately when you click Add, Save, or Delete.
        Be careful when modifying settings as they may affect site functionality.
      </div>
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    fontFamily: 'system-ui, -apple-system, sans-serif',
    maxWidth: '1200px',
    margin: '0 auto',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '20px',
  },
  title: {
    fontSize: '24px',
    fontWeight: 'bold',
    color: '#38495e',
    margin: 0,
  },
  editButton: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '8px 16px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500',
  },
  cancelButton: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '8px 16px',
    backgroundColor: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500',
  },
  statsBox: {
    backgroundColor: '#f8f9fa',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '15px 20px',
    marginBottom: '20px',
  },
  statLine: {
    margin: '8px 0',
    fontSize: '15px',
    color: '#333',
  },
  section: {
    marginBottom: '30px',
  },
  sectionTitle: {
    fontSize: '18px',
    fontWeight: 'bold',
    marginBottom: '15px',
    color: '#333',
    borderBottom: '2px solid #4060b0',
    paddingBottom: '8px',
  },
  tableWrapper: {
    overflowX: 'auto',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px',
  },
  headerRow: {
    backgroundColor: '#38495e',
  },
  th: {
    padding: '10px 12px',
    textAlign: 'left',
    color: 'white',
    fontWeight: 'bold',
  },
  evenRow: {
    backgroundColor: '#f9f9f9',
  },
  oddRow: {
    backgroundColor: 'white',
  },
  keyCell: {
    padding: '8px 12px',
    borderBottom: '1px solid #dee2e6',
    fontFamily: 'monospace',
    fontWeight: 'bold',
    color: '#4060b0',
    width: '200px',
    verticalAlign: 'top',
  },
  valueCell: {
    padding: '8px 12px',
    borderBottom: '1px solid #dee2e6',
    fontFamily: 'monospace',
    wordBreak: 'break-word',
    verticalAlign: 'top',
  },
  actionsCell: {
    padding: '8px 12px',
    borderBottom: '1px solid #dee2e6',
    textAlign: 'center',
    whiteSpace: 'nowrap',
  },
  emptyValue: {
    color: '#999',
    fontStyle: 'italic',
  },
  truncated: {
    color: '#666',
    fontSize: '11px',
  },
  noData: {
    color: '#666',
    fontStyle: 'italic',
    padding: '20px',
    textAlign: 'center',
    backgroundColor: '#f5f5f5',
    borderRadius: '4px',
  },
  statusBox: {
    padding: '10px 15px',
    marginBottom: '15px',
    borderRadius: '4px',
    fontSize: '14px',
  },
  addForm: {
    backgroundColor: '#f8f9fa',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '15px 20px',
    marginBottom: '20px',
  },
  addFormTitle: {
    margin: '0 0 12px 0',
    fontSize: '14px',
    color: '#333',
  },
  addFormRow: {
    display: 'flex',
    gap: '10px',
    alignItems: 'center',
  },
  input: {
    flex: 1,
    padding: '8px 12px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontSize: '13px',
    fontFamily: 'monospace',
  },
  addButton: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '8px 16px',
    backgroundColor: '#28a745',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '500',
  },
  editTextarea: {
    width: '100%',
    padding: '8px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    fontSize: '13px',
    fontFamily: 'monospace',
    resize: 'vertical',
  },
  editSmallButton: {
    padding: '4px 8px',
    marginRight: '4px',
    backgroundColor: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
  },
  saveButton: {
    padding: '4px 8px',
    marginRight: '4px',
    backgroundColor: '#28a745',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
  },
  cancelSmallButton: {
    padding: '4px 8px',
    backgroundColor: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
  },
  deleteButton: {
    padding: '4px 8px',
    backgroundColor: '#dc3545',
    color: 'white',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
  },
  infoBox: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    fontSize: '14px',
    color: '#856404',
  },
}

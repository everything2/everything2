import React, { useState, useEffect } from 'react'
import { FaSave, FaTimes, FaSpinner } from 'react-icons/fa'

/**
 * SystemNodeEditor - Reusable component for editing system node fields
 *
 * Renders a form for editing all database fields of a node based on
 * field metadata from the admin API. Used by basicedit displaytype
 * for superusers to edit any node's raw database fields.
 *
 * Props:
 * - nodeId: The node_id to edit
 * - initialFields: Optional initial field data (from controller)
 * - onSave: Callback after successful save (receives updated node data)
 * - onCancel: Callback for cancel action
 */

const SystemNodeEditor = ({ nodeId, initialFields, onSave, onCancel }) => {
  const [fields, setFields] = useState(initialFields || {})
  const [originalFields, setOriginalFields] = useState({})
  const [nodeInfo, setNodeInfo] = useState(null)
  const [loading, setLoading] = useState(!initialFields)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)

  // Fetch field data if not provided
  useEffect(() => {
    if (initialFields) {
      setFields(initialFields)
      setOriginalFields(JSON.parse(JSON.stringify(initialFields)))
      return
    }

    const fetchFields = async () => {
      try {
        const response = await fetch(`/api/admin/node/${nodeId}/basicedit`, {
          method: 'GET',
          credentials: 'include',
        })
        const data = await response.json()

        if (data.success) {
          setFields(data.fields)
          setOriginalFields(JSON.parse(JSON.stringify(data.fields)))
          setNodeInfo({
            node_id: data.node_id,
            title: data.title,
            nodeType: data.nodeType,
          })
        } else {
          setError(data.error || 'Failed to load node data')
        }
      } catch (err) {
        setError(err.message || 'Failed to load node data')
      } finally {
        setLoading(false)
      }
    }

    fetchFields()
  }, [nodeId, initialFields])

  // Handle field value change
  const handleFieldChange = (fieldName, value) => {
    setFields(prev => ({
      ...prev,
      [fieldName]: {
        ...prev[fieldName],
        value: value,
      },
    }))
    setError(null)
    setSuccess(null)
  }

  // Get changed fields
  const getChangedFields = () => {
    const changed = {}
    Object.keys(fields).forEach(fieldName => {
      if (fieldName === 'node_id') return // Never update node_id
      const current = fields[fieldName]?.value
      const original = originalFields[fieldName]?.value
      // Compare as strings to handle type coercion
      if (String(current ?? '') !== String(original ?? '')) {
        changed[fieldName] = current
      }
    })
    return changed
  }

  // Handle save
  const handleSave = async () => {
    const changedFields = getChangedFields()

    if (Object.keys(changedFields).length === 0) {
      setError('No changes to save')
      return
    }

    setSaving(true)
    setError(null)
    setSuccess(null)

    try {
      const response = await fetch(`/api/admin/node/${nodeId}/basicedit`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ fields: changedFields }),
      })

      const data = await response.json()

      if (data.success) {
        setSuccess(`Updated ${data.updatedFields.length} field(s): ${data.updatedFields.join(', ')}`)
        // Update original fields to reflect saved state
        setOriginalFields(JSON.parse(JSON.stringify(fields)))
        if (onSave) {
          onSave(data)
        }
      } else {
        setError(data.error || 'Failed to save changes')
      }
    } catch (err) {
      setError(err.message || 'Failed to save changes')
    } finally {
      setSaving(false)
    }
  }

  // Render input based on field type
  const renderInput = (fieldName, fieldData) => {
    const { value, inputType, maxLength, type } = fieldData
    const isReadOnly = fieldName === 'node_id'

    const baseStyle = {
      width: '100%',
      padding: '6px 8px',
      fontSize: '13px',
      fontFamily: 'monospace',
      border: '1px solid #ccc',
      borderRadius: '3px',
      boxSizing: 'border-box',
    }

    if (isReadOnly) {
      return (
        <input
          type="text"
          value={value ?? ''}
          readOnly
          style={{ ...baseStyle, backgroundColor: '#f5f5f5', color: '#666' }}
        />
      )
    }

    if (inputType === 'textarea') {
      return (
        <textarea
          value={value ?? ''}
          onChange={(e) => handleFieldChange(fieldName, e.target.value)}
          rows={10}
          style={{ ...baseStyle, resize: 'vertical', minHeight: '100px' }}
        />
      )
    }

    if (inputType === 'number') {
      return (
        <input
          type="number"
          value={value ?? ''}
          onChange={(e) => handleFieldChange(fieldName, e.target.value)}
          maxLength={maxLength}
          style={{ ...baseStyle, maxWidth: '200px' }}
        />
      )
    }

    // Default: text input
    return (
      <input
        type="text"
        value={value ?? ''}
        onChange={(e) => handleFieldChange(fieldName, e.target.value)}
        maxLength={maxLength}
        style={baseStyle}
      />
    )
  }

  if (loading) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <FaSpinner className="fa-spin" /> Loading node data...
      </div>
    )
  }

  const changedFieldCount = Object.keys(getChangedFields()).length

  return (
    <div className="system-node-editor" style={{ padding: '15px' }}>
      {/* Header */}
      {nodeInfo && (
        <div style={{ marginBottom: '15px', paddingBottom: '10px', borderBottom: '1px solid #ddd' }}>
          <h3 style={{ margin: 0 }}>
            Basic Edit: {nodeInfo.title}
          </h3>
          <div style={{ fontSize: '12px', color: '#666', marginTop: '4px' }}>
            Type: {nodeInfo.nodeType} | Node ID: {nodeInfo.node_id}
          </div>
        </div>
      )}

      {/* Warning */}
      <div style={{
        padding: '10px',
        marginBottom: '15px',
        backgroundColor: '#fff3cd',
        border: '1px solid #ffc107',
        borderRadius: '4px',
        fontSize: '13px',
      }}>
        <strong>Warning:</strong> This is a raw database field editor.
        Incorrect values may cause system errors. Use with caution.
      </div>

      {/* Error message */}
      {error && (
        <div style={{
          padding: '10px',
          marginBottom: '15px',
          backgroundColor: '#f8d7da',
          border: '1px solid #f5c6cb',
          borderRadius: '4px',
          color: '#721c24',
        }}>
          {error}
        </div>
      )}

      {/* Success message */}
      {success && (
        <div style={{
          padding: '10px',
          marginBottom: '15px',
          backgroundColor: '#d4edda',
          border: '1px solid #c3e6cb',
          borderRadius: '4px',
          color: '#155724',
        }}>
          {success}
        </div>
      )}

      {/* Fields */}
      <div style={{ maxHeight: '60vh', overflowY: 'auto' }}>
        {Object.keys(fields).sort().map(fieldName => {
          const fieldData = fields[fieldName]
          const isChanged = String(fieldData.value ?? '') !== String(originalFields[fieldName]?.value ?? '')

          return (
            <div key={fieldName} style={{ marginBottom: '12px' }}>
              <label style={{
                display: 'block',
                marginBottom: '4px',
                fontSize: '12px',
                fontWeight: isChanged ? 'bold' : 'normal',
                color: isChanged ? '#0066cc' : '#333',
              }}>
                {fieldName}
                <span style={{ fontWeight: 'normal', color: '#999', marginLeft: '8px' }}>
                  ({fieldData.type})
                </span>
                {isChanged && (
                  <span style={{ color: '#0066cc', marginLeft: '8px' }}>*modified</span>
                )}
              </label>
              {renderInput(fieldName, fieldData)}
            </div>
          )
        })}
      </div>

      {/* Action buttons */}
      <div style={{
        marginTop: '20px',
        paddingTop: '15px',
        borderTop: '1px solid #ddd',
        display: 'flex',
        gap: '10px',
        alignItems: 'center',
      }}>
        <button
          onClick={handleSave}
          disabled={saving || changedFieldCount === 0}
          style={{
            padding: '8px 16px',
            backgroundColor: changedFieldCount > 0 ? '#28a745' : '#ccc',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: saving || changedFieldCount === 0 ? 'not-allowed' : 'pointer',
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
          }}
        >
          {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
          {saving ? 'Saving...' : 'Save Changes'}
        </button>

        {onCancel && (
          <button
            onClick={onCancel}
            disabled={saving}
            style={{
              padding: '8px 16px',
              backgroundColor: '#6c757d',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
          >
            <FaTimes /> Cancel
          </button>
        )}

        {changedFieldCount > 0 && (
          <span style={{ fontSize: '12px', color: '#666' }}>
            {changedFieldCount} field{changedFieldCount !== 1 ? 's' : ''} modified
          </span>
        )}
      </div>
    </div>
  )
}

export default SystemNodeEditor

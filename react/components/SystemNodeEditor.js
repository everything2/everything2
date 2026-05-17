import React, { useState, useEffect } from 'react'
import { FaSave, FaTimes, FaSpinner } from 'react-icons/fa'

/**
 * SystemNodeEditor - Reusable component for editing system node fields
 *
 * Renders a form for editing all database fields of a node based on
 * field metadata from the admin API. Used by basicedit displaytype
 * for superusers to edit any node's raw database fields.
 *
 * Styles are in CSS classes (system-node-editor__*)
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
    const { value, inputType, maxLength } = fieldData
    const isReadOnly = fieldName === 'node_id'

    if (isReadOnly) {
      return (
        <input
          type="text"
          value={value ?? ''}
          readOnly
          className="system-node-editor__input system-node-editor__input--readonly"
        />
      )
    }

    if (inputType === 'textarea') {
      return (
        <textarea
          value={value ?? ''}
          onChange={(e) => handleFieldChange(fieldName, e.target.value)}
          rows={10}
          className="system-node-editor__textarea"
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
          className="system-node-editor__input system-node-editor__input--number"
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
        className="system-node-editor__input"
      />
    )
  }

  if (loading) {
    return (
      <div className="system-node-editor__loading">
        <FaSpinner className="fa-spin" /> Loading node data...
      </div>
    )
  }

  const changedFieldCount = Object.keys(getChangedFields()).length

  return (
    <div className="system-node-editor">
      {/* Header */}
      {nodeInfo && (
        <div className="system-node-editor__header">
          <h3 className="system-node-editor__title">
            Basic Edit: {nodeInfo.title}
          </h3>
          <div className="system-node-editor__meta">
            Type: {nodeInfo.nodeType} | Node ID: {nodeInfo.node_id}
          </div>
        </div>
      )}

      {/* Warning */}
      <div className="system-node-editor__warning">
        <strong>Warning:</strong> This is a raw database field editor.
        Incorrect values may cause system errors. Use with caution.
      </div>

      {/* Error message */}
      {error && (
        <div className="system-node-editor__error">
          {error}
        </div>
      )}

      {/* Success message */}
      {success && (
        <div className="system-node-editor__success">
          {success}
        </div>
      )}

      {/* Fields */}
      <div className="system-node-editor__fields">
        {Object.keys(fields).sort().map(fieldName => {
          const fieldData = fields[fieldName]
          const isChanged = String(fieldData.value ?? '') !== String(originalFields[fieldName]?.value ?? '')

          return (
            <div key={fieldName} className="system-node-editor__field">
              <label className={`system-node-editor__label${isChanged ? ' system-node-editor__label--modified' : ''}`}>
                {fieldName}
                <span className="system-node-editor__label-type">
                  ({fieldData.type})
                </span>
                {isChanged && (
                  <span className="system-node-editor__label-indicator">*modified</span>
                )}
              </label>
              {renderInput(fieldName, fieldData)}
            </div>
          )
        })}
      </div>

      {/* Action buttons */}
      <div className="system-node-editor__actions">
        <button
          onClick={handleSave}
          disabled={saving || changedFieldCount === 0}
          className="system-node-editor__btn system-node-editor__btn--save"
        >
          {saving ? <FaSpinner className="fa-spin" /> : <FaSave />}
          {saving ? 'Saving...' : 'Save Changes'}
        </button>

        {onCancel && (
          <button
            onClick={onCancel}
            disabled={saving}
            className="system-node-editor__btn system-node-editor__btn--cancel"
          >
            <FaTimes /> Cancel
          </button>
        )}

        {changedFieldCount > 0 && (
          <span className="system-node-editor__status">
            {changedFieldCount} field{changedFieldCount !== 1 ? 's' : ''} modified
          </span>
        )}
      </div>
    </div>
  )
}

export default SystemNodeEditor

import React, { useState } from 'react'

/**
 * NodeParameterEditor - Edit node parameters
 *
 * Admin tool for viewing and editing node parameters.
 * Uses the /api/node_parameter endpoint for CRUD operations.
 */
const NodeParameterEditor = ({ data }) => {
  const {
    error: initialError,
    node_id,
    no_node,
    message,
    target_node: initialTargetNode,
    available_params: initialAvailableParams = [],
    current_params: initialCurrentParams = []
  } = data

  const [targetNode, setTargetNode] = useState(initialTargetNode)
  const [availableParams, setAvailableParams] = useState(initialAvailableParams)
  const [currentParams, setCurrentParams] = useState(initialCurrentParams)
  const [newValues, setNewValues] = useState({})
  const [error, setError] = useState(initialError)
  const [loading, setLoading] = useState({})
  const [statusMessage, setStatusMessage] = useState(null)

  if (error) {
    return <div className="error-message">{error}</div>
  }

  if (no_node) {
    return (
      <div className="node-parameter-editor">
        <p>
          This tool allows you to edit specialized parameters for nodes.
        </p>
        <br /><br />
        <hr style={{ width: '20%' }} />
        <br /><br />
        <p>{message}</p>
      </div>
    )
  }

  const handleInputChange = (paramName, value) => {
    setNewValues(prev => ({ ...prev, [paramName]: value }))
  }

  const refreshParams = async () => {
    try {
      const response = await fetch(`/api/node_parameter?node_id=${targetNode.node_id}`)
      const result = await response.json()

      if (result.success) {
        // Map API response to component state format
        setCurrentParams(result.current_parameters.map(p => ({
          name: p.name,
          value: p.value
        })))
        setAvailableParams(result.available_parameters.map(p => ({
          name: p.name,
          description: p.description
        })))
      }
    } catch (err) {
      console.error('Failed to refresh params:', err)
    }
  }

  const handleAddParam = async (e, paramName) => {
    e.preventDefault()

    const paramValue = newValues[paramName] || ''

    setLoading(prev => ({ ...prev, [paramName]: true }))
    setStatusMessage(null)

    try {
      const response = await fetch('/api/node_parameter/set', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          node_id: targetNode.node_id,
          param_name: paramName,
          param_value: paramValue
        })
      })

      const result = await response.json()

      if (result.success) {
        setNewValues(prev => ({ ...prev, [paramName]: '' }))
        setStatusMessage({ type: 'success', text: `Parameter '${paramName}' set successfully.` })
        // Refresh the params list
        await refreshParams()
      } else {
        setStatusMessage({ type: 'error', text: result.error || 'Failed to set parameter' })
      }
    } catch (err) {
      setStatusMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setLoading(prev => ({ ...prev, [paramName]: false }))
    }
  }

  const handleDeleteParam = async (e, paramName) => {
    e.preventDefault()

    setLoading(prev => ({ ...prev, [`del_${paramName}`]: true }))
    setStatusMessage(null)

    try {
      const response = await fetch('/api/node_parameter/delete', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          node_id: targetNode.node_id,
          param_name: paramName
        })
      })

      const result = await response.json()

      if (result.success) {
        setStatusMessage({ type: 'success', text: `Parameter '${paramName}' deleted.` })
        // Refresh the params list
        await refreshParams()
      } else {
        setStatusMessage({ type: 'error', text: result.error || 'Failed to delete parameter' })
      }
    } catch (err) {
      setStatusMessage({ type: 'error', text: 'Network error: ' + err.message })
    } finally {
      setLoading(prev => ({ ...prev, [`del_${paramName}`]: false }))
    }
  }

  return (
    <div className="node-parameter-editor">
      <p>
        This tool allows you to edit specialized parameters for nodes.
      </p>
      <br /><br />
      <hr style={{ width: '20%' }} />
      <br /><br />

      {statusMessage && (
        <div style={{
          padding: '10px',
          marginBottom: '15px',
          backgroundColor: statusMessage.type === 'success' ? '#d4edda' : '#f8d7da',
          color: statusMessage.type === 'success' ? '#155724' : '#721c24',
          border: `1px solid ${statusMessage.type === 'success' ? '#c3e6cb' : '#f5c6cb'}`,
          borderRadius: '4px'
        }}>
          {statusMessage.text}
        </div>
      )}

      <p><strong>Available types of parameters:</strong></p>

      <ul>
        {availableParams.map(param => (
          <li key={param.name} style={{ marginBottom: '10px' }}>
            <strong>{param.name}</strong> - {param.description}
            <br />
            <form onSubmit={(e) => handleAddParam(e, param.name)} style={{ display: 'inline' }}>
              <input
                type="text"
                value={newValues[param.name] || ''}
                onChange={(e) => handleInputChange(param.name, e.target.value)}
                style={{ width: '200px' }}
                disabled={loading[param.name]}
              />
              <button
                type="submit"
                style={{ marginLeft: '5px' }}
                disabled={loading[param.name]}
              >
                {loading[param.name] ? 'adding...' : 'add'}
              </button>
            </form>
          </li>
        ))}
      </ul>

      <br /><br />
      <hr style={{ width: '20%' }} />
      <br /><br />

      <h3>
        Node: {targetNode.title} / {targetNode.type}
      </h3>
      <p>(node_id: {targetNode.node_id})</p>
      <br /><br />

      {currentParams.length === 0 ? (
        <p><em>No node parameters</em></p>
      ) : (
        <table style={{ borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ width: '30%', textAlign: 'left', padding: '5px', borderBottom: '1px solid #ccc' }}>
                <strong>Parameter name</strong>
              </th>
              <th style={{ width: '50%', textAlign: 'left', padding: '5px', borderBottom: '1px solid #ccc' }}>
                <strong>Parameter value</strong>
              </th>
              <th style={{ textAlign: 'left', padding: '5px', borderBottom: '1px solid #ccc' }}>
                X
              </th>
            </tr>
          </thead>
          <tbody>
            {currentParams.map(param => (
              <tr key={param.name}>
                <td style={{ padding: '5px', borderBottom: '1px solid #eee' }}>
                  {param.name}
                </td>
                <td style={{ padding: '5px', borderBottom: '1px solid #eee' }}>
                  {param.value}
                </td>
                <td style={{ padding: '5px', borderBottom: '1px solid #eee' }}>
                  <button
                    onClick={(e) => handleDeleteParam(e, param.name)}
                    disabled={loading[`del_${param.name}`]}
                  >
                    {loading[`del_${param.name}`] ? '...' : 'del'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

export default NodeParameterEditor

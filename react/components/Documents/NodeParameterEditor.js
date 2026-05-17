import React, { useState } from 'react'

/**
 * NodeParameterEditor - Edit node parameters
 *
 * Admin tool for viewing and editing node parameters.
 * Uses the /api/node_parameter endpoint for CRUD operations.
 * Styles are in CSS classes (node-param-editor__*)
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
        <hr className="node-param-editor__hr" />
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

  const statusClass = statusMessage
    ? `node-param-editor__status node-param-editor__status--${statusMessage.type}`
    : ''

  return (
    <div className="node-parameter-editor">
      <p>
        This tool allows you to edit specialized parameters for nodes.
      </p>
      <br /><br />
      <hr className="node-param-editor__hr" />
      <br /><br />

      {statusMessage && (
        <div className={statusClass}>
          {statusMessage.text}
        </div>
      )}

      <p><strong>Available types of parameters:</strong></p>

      <ul>
        {availableParams.map(param => (
          <li key={param.name} className="node-param-editor__param-item">
            <strong>{param.name}</strong> - {param.description}
            <br />
            <form onSubmit={(e) => handleAddParam(e, param.name)} className="node-param-editor__form">
              <input
                type="text"
                value={newValues[param.name] || ''}
                onChange={(e) => handleInputChange(param.name, e.target.value)}
                className="node-param-editor__input"
                disabled={loading[param.name]}
              />
              <button
                type="submit"
                className="node-param-editor__btn"
                disabled={loading[param.name]}
              >
                {loading[param.name] ? 'adding...' : 'add'}
              </button>
            </form>
          </li>
        ))}
      </ul>

      <br /><br />
      <hr className="node-param-editor__hr" />
      <br /><br />

      <h3>
        Node: {targetNode.title} / {targetNode.type}
      </h3>
      <p>(node_id: {targetNode.node_id})</p>
      <br /><br />

      {currentParams.length === 0 ? (
        <p><em>No node parameters</em></p>
      ) : (
        <table className="node-param-editor__table">
          <thead>
            <tr>
              <th className="node-param-editor__th node-param-editor__th--name">
                <strong>Parameter name</strong>
              </th>
              <th className="node-param-editor__th node-param-editor__th--value">
                <strong>Parameter value</strong>
              </th>
              <th className="node-param-editor__th">
                X
              </th>
            </tr>
          </thead>
          <tbody>
            {currentParams.map(param => (
              <tr key={param.name}>
                <td className="node-param-editor__td">
                  {param.name}
                </td>
                <td className="node-param-editor__td">
                  {param.value}
                </td>
                <td className="node-param-editor__td">
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

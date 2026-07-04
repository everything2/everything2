import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * NodetypeChanger - Admin tool to change a node's type.
 *
 * The lookup and the type change moved to POST /api/nodetype_changer/lookup|change (#4461).
 * Changing a node INTO a permanently-cached type (usergroup/setting/datastash/room) is
 * fleet-wide and disruptive, so the UI warns on selection and the change endpoint refuses
 * such a target until confirmed.
 */
const NodetypeChanger = ({ data }) => {
  const { error: pageError, node_id, nodetypes = [] } = data

  const [nodeIdInput, setNodeIdInput] = useState('')
  const [target, setTarget] = useState(null)
  const [selectedType, setSelectedType] = useState('')
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [serverWarning, setServerWarning] = useState('')
  const [needsConfirm, setNeedsConfirm] = useState(false)
  const [loading, setLoading] = useState(false)

  if (pageError) {
    return <div className="error-message">{pageError}</div>
  }

  const selectedNt = nodetypes.find((nt) => String(nt.node_id) === String(selectedType))
  const selectedIsPermanent = !!(selectedNt && selectedNt.permanent_cache)

  const post = async (route, body) => {
    const res = await fetch(`/api/nodetype_changer/${route}`, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(body),
    })
    return res.ok ? res.json() : null
  }

  const handleLookup = async (e) => {
    e.preventDefault()
    if (!nodeIdInput.trim()) return
    setLoading(true)
    setError('')
    setMessage('')
    setServerWarning('')
    setNeedsConfirm(false)
    try {
      const json = await post('lookup', { node_id: nodeIdInput.trim() })
      if (json && json.success) {
        setTarget(json.target)
        setSelectedType(String(json.target.type_id))
      } else {
        setTarget(null)
        setError((json && json.error) || 'Lookup failed.')
      }
    } catch (err) {
      setError(err.message || 'Lookup failed.')
    } finally {
      setLoading(false)
    }
  }

  // Changing the dropdown selection clears any prior server confirm/warning (the danger is
  // re-evaluated for the new target type).
  const handleSelect = (value) => {
    setSelectedType(value)
    setNeedsConfirm(false)
    setServerWarning('')
    setMessage('')
  }

  const handleChange = async (e) => {
    e.preventDefault()
    if (!target || !selectedType) return
    setLoading(true)
    setError('')
    setMessage('')
    try {
      const json = await post('change', {
        change_id: target.node_id,
        new_nodetype: Number(selectedType),
        confirmed: needsConfirm ? 1 : 0,
      })
      if (json && json.success) {
        setMessage(json.message)
        setTarget(json.target)
        setSelectedType(String(json.target.type_id))
        setNeedsConfirm(false)
        setServerWarning('')
      } else if (json && json.needs_confirm) {
        setServerWarning(json.warning)
        setNeedsConfirm(true)
      } else {
        setError((json && json.error) || 'Change failed.')
      }
    } catch (err) {
      setError(err.message || 'Change failed.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="nodetype-changer">
      {message && <div className="nodetype-changer__success-message">{message}</div>}
      {error && <div className="error-message">{error}</div>}

      {target && (
        <div className="nodetype-changer__target-section">
          <div className="nodetype-changer__current-info">
            <strong>
              <LinkNode nodeId={target.node_id} display={target.title} target="_blank" rel="noopener noreferrer" />
            </strong>{' '}
            (node {target.node_id}) is currently a: <em>{target.current_type}</em>
          </div>

          <form onSubmit={handleChange} className="nodetype-changer__form">
            <div className="nodetype-changer__form-group">
              <label className="nodetype-changer__label">
                Change to:
                <select
                  value={selectedType}
                  onChange={(e) => handleSelect(e.target.value)}
                  className="nodetype-changer__select"
                >
                  {nodetypes.map((nt) => (
                    <option key={nt.node_id} value={nt.node_id}>
                      {nt.title}
                      {nt.permanent_cache ? ' ⚠ (permanent cache)' : ''}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            {(selectedIsPermanent || serverWarning) && (
              <div className="nodetype-changer__warning" role="alert">
                {serverWarning ||
                  `Heads up: '${selectedNt && selectedNt.title}' is a permanently-cached type. A node ` +
                    `of this type can't be edited through this interface until the servers restart — these ` +
                    `nodes are controlled by the deployment system. Only change a node into it if you know ` +
                    `exactly what you are doing.`}
              </div>
            )}

            <button type="submit" className="nodetype-changer__submit-btn" disabled={loading}>
              {loading
                ? 'Working…'
                : needsConfirm
                  ? 'Confirm: change anyway'
                  : 'Update Nodetype'}
            </button>
          </form>

          <hr className="nodetype-changer__divider" />
        </div>
      )}

      <div className="nodetype-changer__search-box">
        <form onSubmit={handleLookup} className="nodetype-changer__form">
          <input type="hidden" name="node_id" value={node_id} />
          <div className="nodetype-changer__form-group">
            <label className="nodetype-changer__label">
              Node ID:
              <input
                type="text"
                value={nodeIdInput}
                onChange={(e) => setNodeIdInput(e.target.value)}
                className="nodetype-changer__input"
                placeholder="Enter node ID"
              />
            </label>
          </div>
          <button type="submit" className="nodetype-changer__submit-btn" disabled={loading}>
            {loading ? 'Working…' : 'Get Data'}
          </button>
        </form>
      </div>
    </div>
  )
}

export default NodetypeChanger

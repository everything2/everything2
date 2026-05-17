import React, { useState } from 'react'

/**
 * NodetypeChanger - Admin tool to change a node's type
 *
 * Allows admins to change the nodetype of any node by ID.
 */
const NodetypeChanger = ({ data }) => {
  const {
    error,
    message,
    node_id,
    nodetypes = [],
    target_node
  } = data

  const [nodeId, setNodeId] = useState('')

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="nodetype-changer">
      {message && (
        <div className="nodetype-changer__success-message">{message}</div>
      )}

      {/* Show target node if we have one */}
      {target_node && (
        <div className="nodetype-changer__target-section">
          <div className="nodetype-changer__current-info">
            <strong>{target_node.title}</strong> is currently a:{' '}
            <em>{target_node.current_type}</em>
          </div>

          <form method="GET" className="nodetype-changer__form">
            <input type="hidden" name="node_id" value={node_id} />
            <input type="hidden" name="change_id" value={target_node.node_id} />
            <input type="hidden" name="oldtype_id" value={target_node.node_id} />

            <div className="nodetype-changer__form-group">
              <label className="nodetype-changer__label">
                Change to:
                <select name="new_nodetype" defaultValue={target_node.type_id} className="nodetype-changer__select">
                  {nodetypes.map((nt) => (
                    <option key={nt.node_id} value={nt.node_id}>
                      {nt.title}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <button
              type="submit"
              name="sexisgood"
              value="update"
              className="nodetype-changer__submit-btn"
            >
              Update Nodetype
            </button>
          </form>

          <hr className="nodetype-changer__divider" />
        </div>
      )}

      {/* Node ID input form */}
      <div className="nodetype-changer__search-box">
        <form method="GET" className="nodetype-changer__form">
          <input type="hidden" name="node_id" value={node_id} />

          <div className="nodetype-changer__form-group">
            <label className="nodetype-changer__label">
              Node ID:
              <input
                type="text"
                name="oldtype_id"
                value={nodeId}
                onChange={(e) => setNodeId(e.target.value)}
                className="nodetype-changer__input"
                placeholder="Enter node ID"
              />
            </label>
          </div>

          <button
            type="submit"
            name="sexisgood"
            value="get data"
            className="nodetype-changer__submit-btn"
          >
            Get Data
          </button>
        </form>
      </div>
    </div>
  )
}

export default NodetypeChanger

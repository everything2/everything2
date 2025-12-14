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
        <p style={{ color: 'green', fontWeight: 'bold' }}>{message}</p>
      )}

      {/* Show target node if we have one */}
      {target_node && (
        <div style={{ marginBottom: '1.5em' }}>
          <p>
            <strong>{target_node.title}</strong> is currently a:{' '}
            <em>{target_node.current_type}</em>
          </p>

          <form method="GET">
            <input type="hidden" name="node_id" value={node_id} />
            <input type="hidden" name="change_id" value={target_node.node_id} />
            <input type="hidden" name="oldtype_id" value={target_node.node_id} />

            <p>
              <label>
                Change to:{' '}
                <select name="new_nodetype" defaultValue={target_node.type_id}>
                  {nodetypes.map((nt) => (
                    <option key={nt.node_id} value={nt.node_id}>
                      {nt.title}
                    </option>
                  ))}
                </select>
              </label>
            </p>

            <p>
              <button
                type="submit"
                name="sexisgood"
                value="update"
                style={{
                  padding: '6px 15px',
                  backgroundColor: '#38495e',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '3px',
                  cursor: 'pointer'
                }}
              >
                Update
              </button>
            </p>
          </form>

          <hr style={{ margin: '1.5em 0' }} />
        </div>
      )}

      {/* Node ID input form */}
      <form method="GET">
        <input type="hidden" name="node_id" value={node_id} />

        <p>
          <label>
            Node Id:{' '}
            <input
              type="text"
              name="oldtype_id"
              value={nodeId}
              onChange={(e) => setNodeId(e.target.value)}
              size={20}
            />
          </label>
          {' '}
          <button
            type="submit"
            name="sexisgood"
            value="get data"
            style={{
              padding: '6px 15px',
              backgroundColor: '#38495e',
              color: '#fff',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
          >
            Get Data
          </button>
        </p>
      </form>
    </div>
  )
}

export default NodetypeChanger

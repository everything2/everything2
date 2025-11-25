import React from 'react'
import { FaServer, FaHashtag, FaSearch, FaTag, FaCodeBranch } from 'react-icons/fa'
import LinkNode from '../LinkNode'

const githubUrl = "https://github.com/everything2/everything2"

const AdminSearchForm = ({ nodeId, nodeType, nodeTitle, serverName, scriptName, lastCommit }) => {
  return (
    <div className="nodelet_section">
      <h4 className="ns_title">Node Info</h4>
      <div style={{ padding: '8px 0' }}>
        {/* Compact info grid */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'auto 1fr',
          gap: '4px 8px',
          fontSize: '0.9em',
          marginBottom: '12px'
        }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#666' }}>
            <FaHashtag size={10} /> ID:
          </span>
          <span className="var_value">{nodeId}</span>

          <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#666' }}>
            <FaTag size={10} /> Type:
          </span>
          <span className="var_value">
            <LinkNode type="nodetype" title={nodeType} />
          </span>

          <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#666' }}>
            <FaServer size={10} /> Server:
          </span>
          <span className="var_value">{serverName}</span>

          <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#666' }}>
            <FaCodeBranch size={10} /> Build:
          </span>
          <span className="var_value">
            <a href={githubUrl + "/commit/" + lastCommit} style={{ textDecoration: 'none' }}>
              {lastCommit ? lastCommit.substr(0, 7) : 'unknown'}
            </a>
          </span>
        </div>

        {/* Search by name */}
        <form method="POST" action={scriptName} style={{ marginBottom: '8px' }}>
          <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
            <FaSearch size={12} style={{ color: '#666', flexShrink: 0 }} />
            <input
              type="text"
              name="node"
              id="node"
              placeholder="Search by name..."
              defaultValue={nodeTitle}
              style={{
                flex: 1,
                padding: '4px 6px',
                border: '1px solid #ccc',
                borderRadius: '3px',
                fontSize: '0.9em'
              }}
            />
            <button
              type="submit"
              name="name_button"
              style={{
                padding: '4px 12px',
                backgroundColor: '#5a9fd4',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: 'pointer',
                fontSize: '0.9em'
              }}
            >
              Go
            </button>
          </div>
        </form>

        {/* Search by ID */}
        <form method="POST" action={scriptName}>
          <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
            <FaHashtag size={12} style={{ color: '#666', flexShrink: 0 }} />
            <input
              type="text"
              name="node_id"
              id="node_id"
              placeholder="Search by ID..."
              defaultValue={nodeId}
              style={{
                flex: 1,
                padding: '4px 6px',
                border: '1px solid #ccc',
                borderRadius: '3px',
                fontSize: '0.9em'
              }}
            />
            <button
              type="submit"
              name="id_button"
              style={{
                padding: '4px 12px',
                backgroundColor: '#5a9fd4',
                color: 'white',
                border: 'none',
                borderRadius: '3px',
                cursor: 'pointer',
                fontSize: '0.9em'
              }}
            >
              Go
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default AdminSearchForm

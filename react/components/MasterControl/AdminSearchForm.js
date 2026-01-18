import React from 'react'
import { FaServer, FaHashtag, FaSearch, FaTag, FaCodeBranch } from 'react-icons/fa'
import LinkNode from '../LinkNode'

const githubUrl = "https://github.com/everything2/everything2"

const AdminSearchForm = ({ nodeId, nodeType, nodeTitle, serverName, scriptName, lastCommit }) => {
  return (
    <div className="nodelet_section">
      <h4 className="ns_title">Node Info</h4>
      <div className="mc-search">
        {/* Compact info grid */}
        <div className="mc-search__info-grid">
          <span className="mc-search__label">
            <FaHashtag size={10} /> ID:
          </span>
          <span className="var_value">{nodeId}</span>

          <span className="mc-search__label">
            <FaTag size={10} /> Type:
          </span>
          <span className="var_value">
            <LinkNode type="nodetype" title={nodeType} />
          </span>

          <span className="mc-search__label">
            <FaServer size={10} /> Server:
          </span>
          <span className="var_value">{serverName}</span>

          <span className="mc-search__label">
            <FaCodeBranch size={10} /> Build:
          </span>
          <span className="var_value">
            <a href={githubUrl + "/commit/" + lastCommit} className="mc-search__build-link">
              {lastCommit ? lastCommit.substr(0, 7) : 'unknown'}
            </a>
          </span>
        </div>

        {/* Search by name */}
        <form method="POST" action={scriptName} className="mc-search__form">
          <div className="mc-search__input-row">
            <FaSearch size={12} className="mc-search__icon" />
            <input
              type="text"
              name="node"
              id="node"
              placeholder="Search by name..."
              defaultValue={nodeTitle}
              className="mc-search__input"
            />
            <button
              type="submit"
              name="name_button"
              className="mc-search__btn"
            >
              Go
            </button>
          </div>
        </form>

        {/* Search by ID */}
        <form method="POST" action={scriptName} className="mc-search__form">
          <div className="mc-search__input-row">
            <FaHashtag size={12} className="mc-search__icon" />
            <input
              type="text"
              name="node_id"
              id="node_id"
              placeholder="Search by ID..."
              defaultValue={nodeId}
              className="mc-search__input"
            />
            <button
              type="submit"
              name="id_button"
              className="mc-search__btn"
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

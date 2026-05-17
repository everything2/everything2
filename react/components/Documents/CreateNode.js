import React, { useState } from 'react'

/**
 * CreateNode - Form for creating new nodes of various types.
 * Styles in CSS: .create-node__*
 */
const CreateNode = ({ data }) => {
  const { nodetypes, default_type, newtitle } = data

  const [nodeName, setNodeName] = useState(newtitle || '')
  const [nodeType, setNodeType] = useState(default_type || '')

  const handleSubmit = (e) => {
    // Let the form submit naturally to the server
    // The server handles the node creation via op=new
  }

  return (
    <div className="create-node">
      <div className="create-node__notice">
        <p className="create-node__notice-heading">Please:</p>
        <p className="create-node__notice-text">
          Before creating a new node make sure there isn&apos;t already a node that you could
          simply add a writeup to. Often a user will create a new node only to find there are
          several others on the same topics. Just type several key-words in the search box
          above&mdash;there&apos;s a pretty good chance somebody&apos;s already created a node
          about it.
        </p>
      </div>

      <form method="GET" action="/" onSubmit={handleSubmit} className="create-node__form">
        <div className="create-node__form-row">
          <label>
            Node name:{' '}
            <input
              type="text"
              name="node"
              value={nodeName}
              onChange={(e) => setNodeName(e.target.value)}
              maxLength={100}
              className="create-node__input"
            />
          </label>
        </div>

        <div className="create-node__form-row">
          <label>
            Nodetype:{' '}
            <select
              name="type"
              value={nodeType}
              onChange={(e) => setNodeType(e.target.value)}
              className="create-node__select"
            >
              {nodetypes.map((nt) => (
                <option key={nt.node_id} value={nt.node_id}>
                  {nt.title}
                </option>
              ))}
            </select>
          </label>
        </div>

        <input type="hidden" name="op" value="new" />

        <div className="create-node__form-row">
          <button type="submit" className="create-node__button">
            Create It!
          </button>
        </div>
      </form>
    </div>
  )
}

export default CreateNode

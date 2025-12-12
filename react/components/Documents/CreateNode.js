import React, { useState } from 'react'

/**
 * CreateNode - Form for creating new nodes of various types.
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
    <div style={styles.container}>
      <div style={styles.notice}>
        <h3>Please:</h3>
        <ul>
          <li>
            Before creating a new node make sure there isn&apos;t already a node that you could
            simply add a writeup to. Often a user will create a new node only to find there are
            several others on the same topics. Just type several key-words in the search box
            above&mdash;there&apos;s a pretty good chance somebody&apos;s already created a node
            about it.
          </li>
        </ul>
      </div>

      <form method="GET" action="/" onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <label>
            Node name:{' '}
            <input
              type="text"
              name="node"
              value={nodeName}
              onChange={(e) => setNodeName(e.target.value)}
              size={50}
              maxLength={100}
              style={styles.input}
            />
          </label>
        </div>

        <div style={styles.formRow}>
          <label>
            Nodetype:{' '}
            <select
              name="type"
              value={nodeType}
              onChange={(e) => setNodeType(e.target.value)}
              style={styles.select}
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

        <div style={styles.formRow}>
          <button type="submit" style={styles.button}>
            Create It!
          </button>
        </div>
      </form>
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  notice: {
    backgroundColor: '#fff3e0',
    border: '1px solid #ff9800',
    borderRadius: '4px',
    padding: '10px 15px',
    marginBottom: '20px'
  },
  form: {
    marginTop: '15px'
  },
  formRow: {
    marginBottom: '10px'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px'
  },
  select: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px'
  },
  button: {
    padding: '8px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  }
}

export default CreateNode

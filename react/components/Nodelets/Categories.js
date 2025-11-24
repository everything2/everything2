import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'

const Categories = (props) => {
  if (!props.categories || !Array.isArray(props.categories) || props.categories.length === 0) {
    return (
      <NodeletContainer
        title="Categories"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', color: '#666', fontSize: '12px' }}>
          <em>No categories available</em>
        </p>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      title="Categories"
      showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
    >
      <ul id="nodelists" style={{ listStyle: 'disc', paddingLeft: '24px', margin: '8px 0' }}>
        {props.categories.map((category) => (
          <li key={category.node_id} style={{ marginBottom: '4px', fontSize: '12px' }}>
            <LinkNode
              nodeId={category.node_id}
              title={category.title}
              lastNodeId={0}
            />
            {' by '}
            <LinkNode
              nodeId={category.author_user}
              title={category.author_username}
              lastNodeId={0}
            />
            {' ('}
            <a
              href={`/index.pl?op=category&node_id=${props.currentNodeId}&cid=${category.node_id}&nid=${props.currentNodeId}`}
            >
              add
            </a>
            {')'}
          </li>
        ))}
      </ul>
      <div className="nodeletfoot">
        <LinkNode
          title="Create category"
          type="superdoc"
          display="Add a new Category"
        />
      </div>
    </NodeletContainer>
  )
}

export default Categories

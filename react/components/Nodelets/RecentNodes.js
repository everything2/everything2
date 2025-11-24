import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'

const RecentNodes = (props) => {
  const getRandomSaying = () => {
    const sayings = [
      "A trail of crumbs",
      "Footprints in the sand",
      "Are we there yet?",
      "A snapshot...",
      "The ghost of nodes past"
    ]
    return sayings[Math.floor(Math.random() * sayings.length)]
  }

  const getRandomButtonText = () => {
    const quotes = [
      "Cover my tracks",
      "Deny my past",
      "The Feds are knocking",
      "Wipe the slate clean"
    ]
    return quotes[Math.floor(Math.random() * quotes.length)]
  }

  const [saying] = React.useState(getRandomSaying())
  const [buttonText] = React.useState(getRandomButtonText())

  if (!props.recentNodes || !Array.isArray(props.recentNodes) || props.recentNodes.length === 0) {
    return (
      <NodeletContainer
        title="Recent Nodes"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <em style={{ fontSize: '12px', padding: '8px', display: 'block' }}>{saying}</em>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      title="Recent Nodes"
      showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
    >
      <em style={{ fontSize: '12px', padding: '8px 8px 4px 8px', display: 'block' }}>
        {saying}:
      </em>
      <ol style={{ paddingLeft: '28px', margin: '4px 0', fontSize: '12px' }}>
        {props.recentNodes.map((node, index) => (
          <li key={index} style={{ marginBottom: '2px' }}>
            <LinkNode
              nodeId={node.node_id}
              title={node.title}
              lastNodeId={0}
            />
          </li>
        ))}
      </ol>
      <form method="GET" className="nodeletfoot" style={{ margin: '8px 4px 4px 4px' }}>
        <input type="hidden" name="eraseTrail" value="1" />
        <input
          type="submit"
          name="schwammdrueber"
          value={buttonText}
          style={{ fontSize: '11px' }}
        />
      </form>
    </NodeletContainer>
  )
}

export default RecentNodes

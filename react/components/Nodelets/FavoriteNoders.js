import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'

const FavoriteNoders = (props) => {
  if (!props.favoriteWriteups || !Array.isArray(props.favoriteWriteups) || props.favoriteWriteups.length === 0) {
    return (
      <NodeletContainer
        id={props.id}
      title="Favorite Noders"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', color: '#666', fontSize: '12px' }}>
          <em>No favorite writeups available</em>
        </p>
      </NodeletContainer>
    )
  }

  // TODO: Remove this hard limit once issue #3765 is fixed
  // https://github.com/everything2/everything2/issues/3765
  // This will require a new API similar to the new writeups API
  const displayWriteups = props.favoriteWriteups.slice(0, 5)

  return (
    <NodeletContainer
      id={props.id}
      title="Favorite Noders"
      showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
    >
      <ul id="writeup_faves" style={{ listStyle: 'none', paddingLeft: '8px', margin: 0, fontSize: '12px' }}>
        {displayWriteups.map((writeup, index) => (
          <li key={index} style={{ marginBottom: '4px' }}>
            <span className="writeupmeta">
              <span className="title">
                <LinkNode nodeId={writeup.node_id} title={writeup.title} />
              </span>
              {' by '}
              <span className="author">
                <LinkNode nodeId={writeup.author_id} title={writeup.author_name} />
              </span>
            </span>
          </li>
        ))}
      </ul>
    </NodeletContainer>
  )
}

export default FavoriteNoders

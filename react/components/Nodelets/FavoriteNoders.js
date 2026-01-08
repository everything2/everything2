import React from 'react'
import NodeletContainer from '../NodeletContainer'
import WriteupEntry from '../WriteupEntry'

const FavoriteNoders = (props) => {
  if (!props.favoriteWriteups || !Array.isArray(props.favoriteWriteups) || props.favoriteWriteups.length === 0) {
    return (
      <NodeletContainer
        id={props.id}
        title="Favorite Noders"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <div style={{
          padding: '16px',
          textAlign: 'center',
          fontSize: '12px',
          color: '#999',
          fontStyle: 'italic'
        }}>
          No recent writeups from your favorite noders.
          <br />
          <span style={{ fontSize: '11px', marginTop: '8px', display: 'block' }}>
            Use the star icon on user profiles to follow noders.
          </span>
        </div>
      </NodeletContainer>
    )
  }

  // TODO: Remove this hard limit once issue #3765 is fixed
  // https://github.com/everything2/everything2/issues/3765
  // This will require a new API similar to the new writeups API
  const displayWriteups = props.favoriteWriteups.slice(0, 10)

  return (
    <NodeletContainer
      id={props.id}
      title="Favorite Noders"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <ul className="infolist" style={{ margin: 0 }}>
        {displayWriteups.map((entry) => (
          <WriteupEntry
            entry={entry}
            key={`fav_${entry.node_id}`}
            mode="full"
          />
        ))}
      </ul>
    </NodeletContainer>
  )
}

export default FavoriteNoders

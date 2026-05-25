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
        <div className="favorite-noders__empty">
          No recent writeups from your favorite noders.
          <br />
          <span className="favorite-noders__hint">
            Use the star icon on user profiles to follow noders.
          </span>
        </div>
      </NodeletContainer>
    )
  }

  // Cap at 5 to keep the nodelet compact (#3765). Initial data is
  // server-baked into props alongside the rest of the page state —
  // no API fetch on page load (load-balancer hygiene).
  const displayWriteups = props.favoriteWriteups.slice(0, 5)

  return (
    <NodeletContainer
      id={props.id}
      title="Favorite Noders"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <ul className="infolist favorite-noders__list">
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

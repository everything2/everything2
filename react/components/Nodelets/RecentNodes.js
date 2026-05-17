import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import WriteupEntry from '../WriteupEntry'

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
  const [isClearing, setIsClearing] = React.useState(false)

  const handleClearTracks = async (e) => {
    e.preventDefault()
    setIsClearing(true)

    try {
      const response = await fetch('/api/preferences/set', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ nodetrail: '' }),
        credentials: 'same-origin'
      })

      if (response.ok) {
        // Clear tracks successful - update parent state
        if (props.onClearTracks) {
          props.onClearTracks()
        }
      } else {
        console.error('Failed to clear tracks:', response.status)
      }
    } catch (error) {
      console.error('Error clearing tracks:', error)
    } finally {
      setIsClearing(false)
    }
  }

  if (!props.recentNodes || !Array.isArray(props.recentNodes) || props.recentNodes.length === 0) {
    return (
      <NodeletContainer
        id={props.id}
        title="Recent Nodes"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <em className="recent-nodes__saying">{saying}</em>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Recent Nodes"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <em className="recent-nodes__saying recent-nodes__saying--with-list">
        {saying}:
      </em>
      <ol className="recent-nodes__list">
        {props.recentNodes.map((node, index) => (
          <WriteupEntry
            key={index}
            entry={node}
            mode="simple"
            className=""
          />
        ))}
      </ol>
      <form onSubmit={handleClearTracks} className="nodeletfoot recent-nodes__foot">
        <input
          type="submit"
          name="schwammdrueber"
          value={buttonText}
          disabled={isClearing}
          className="recent-nodes__clear-btn"
        />
      </form>
    </NodeletContainer>
  )
}

export default RecentNodes

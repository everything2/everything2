import React from 'react'
import WriteupEntry from '../WriteupEntry'
import NewWriteupsFilter from '../NewWriteupsFilter'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'
import { useActivityDetection } from '../../hooks/useActivityDetection'

const NewWriteups = (props) => {
  const [writeups, setWriteups] = React.useState(props.newWriteups || [])
  const { isActive, isMultiTabActive } = useActivityDetection(10)
  const pollInterval = React.useRef(null)
  const missedUpdate = React.useRef(false)

  // Load new writeups from API
  const loadWriteups = React.useCallback(async () => {
    try {
      const response = await fetch('/api/newwriteups/', {
        credentials: 'include',
        headers: {
          'X-Ajax-Idle': '1'
        }
      })

      if (response.ok) {
        const data = await response.json()
        setWriteups(data)
      }
    } catch (err) {
      console.error('Failed to load new writeups:', err)
    }
  }, [])

  // Polling effect - refresh every 5 minutes when active and nodelet is expanded
  // IMPORTANT: Do not poll for guest users - they see static content from initial page load
  React.useEffect(() => {
    const isGuest = props.user?.guest
    const shouldPoll = !isGuest && isActive && isMultiTabActive && props.nodeletIsOpen

    if (shouldPoll) {
      pollInterval.current = setInterval(() => {
        loadWriteups()
      }, 300000) // 5 minutes
    } else {
      // If we're not polling because nodelet is collapsed, mark that we missed updates
      if (!isGuest && isActive && isMultiTabActive && !props.nodeletIsOpen) {
        missedUpdate.current = true
      }

      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }

    return () => {
      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }
  }, [isActive, isMultiTabActive, props.nodeletIsOpen, props.user, loadWriteups])

  // Uncollapse detection: refresh immediately when nodelet is uncollapsed after missing updates
  React.useEffect(() => {
    if (props.nodeletIsOpen && missedUpdate.current) {
      missedUpdate.current = false
      loadWriteups()
    }
  }, [props.nodeletIsOpen, loadWriteups])

  // Focus refresh: immediately refresh when page becomes visible (logged-in users only)
  React.useEffect(() => {
    const isGuest = props.user?.guest

    const handleVisibilityChange = () => {
      if (!isGuest && !document.hidden && isActive) {
        loadWriteups()
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [isActive, props.user, loadWriteups])

  const filteredWriteups = writeups
    .filter((entry) => !entry.is_junk || !props.noJunk)
    .slice(0, props.limit)

  return (
    <NodeletContainer
      id={props.id}
      title="New Writeups"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <div style={{ marginBottom: '12px' }}>
        <NewWriteupsFilter
          limit={props.limit}
          newWriteupsChange={props.newWriteupsChange}
          noJunkChange={props.noJunkChange}
          noJunk={props.noJunk}
          user={props.user}
        />
      </div>

      {writeups.length === 0 ? (
        <div className="newwriteups-empty">
          No writeups yet
        </div>
      ) : (
        <ul className="infolist" style={{ margin: 0 }}>
          {filteredWriteups.map((entry) => (
            <WriteupEntry
              entry={entry}
              key={`nwe_${entry.node_id}`}
              mode="full"
              editor={props.user.editor}
              editorHideWriteupChange={props.editorHideWriteupChange}
            />
          ))}
        </ul>
      )}

      <div className="nodeletfoot morelink newwriteups-footer">
        (<LinkNode type="superdoc" title="Writeups By Type" display="more" />)
      </div>
    </NodeletContainer>
  )
}

export default NewWriteups;

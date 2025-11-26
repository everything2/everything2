import React, { useState } from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'

const PersonalLinks = (props) => {
  // Local state for nodelet data
  const [personalLinks, setPersonalLinks] = useState(props.personalLinks || [])
  const [canAddCurrent, setCanAddCurrent] = useState(props.canAddCurrent || false)
  const [currentNodeTitle, setCurrentNodeTitle] = useState(props.currentNodeTitle || '')

  // UI state
  const [isAdding, setIsAdding] = useState(false)
  const [deletingIndex, setDeletingIndex] = useState(null)
  const [error, setError] = useState(null)

  // Update local state when props change (e.g., navigating to different page)
  React.useEffect(() => {
    const rawLinks = props.personalLinks
    const links = Array.isArray(rawLinks) ? rawLinks : []
    const title = props.currentNodeTitle || ''

    setPersonalLinks(links)
    setCurrentNodeTitle(title)

    // Calculate if we can add current node
    // Default limits (should match API)
    const itemLimit = 20
    const charLimit = 1000

    if (title && links.length < itemLimit) {
      const currentChars = links.reduce((sum, link) => sum + link.length, 0)
      const titleLength = title.length

      const underCharLimit = (currentChars + titleLength) <= charLimit

      setCanAddCurrent(underCharLimit)
    } else {
      setCanAddCurrent(false)
    }
  }, [props.personalLinks, props.currentNodeTitle])

  const updateFromAPIResponse = (data) => {
    const links = data.links || []
    setPersonalLinks(links)

    // Calculate if we can add current node based on limits
    // This is done client-side since we already have currentNodeTitle from props
    if (currentNodeTitle && data.item_limit && data.char_limit) {
      const currentCount = links.length
      const currentChars = data.total_chars || 0
      const titleLength = currentNodeTitle.length

      const underItemLimit = currentCount < data.item_limit
      const underCharLimit = (currentChars + titleLength) <= data.char_limit

      setCanAddCurrent(underItemLimit && underCharLimit)
    } else {
      setCanAddCurrent(false)
    }
  }

  const handleAddCurrent = async (e) => {
    e.preventDefault()
    setIsAdding(true)
    setError(null)

    try {
      const response = await fetch('/api/personallinks/add', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: currentNodeTitle,
        }),
        credentials: 'include',
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to add link')
      }

      const data = await response.json()
      updateFromAPIResponse(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setIsAdding(false)
    }
  }

  const handleDelete = async (index) => {
    setDeletingIndex(index)
    setError(null)

    try {
      const response = await fetch(`/api/personallinks/delete/${index}`, {
        method: 'DELETE',
        credentials: 'include',
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to delete link')
      }

      const data = await response.json()
      updateFromAPIResponse(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setDeletingIndex(null)
    }
  }

  if (props.isGuest) {
    return (
      <NodeletContainer
        id={props.id}
      title="Personal Links"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', fontSize: '12px' }}>You must log in first.</p>
      </NodeletContainer>
    )
  }

  if (!personalLinks || !Array.isArray(personalLinks) || personalLinks.length === 0) {
    return (
      <NodeletContainer
        id={props.id}
      title="Personal Links"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        {(error || canAddCurrent) && (
          <div className="nodeletfoot" style={{ padding: '8px', fontSize: '12px' }}>
            {error && (
              <div style={{ color: 'red', fontSize: '11px', marginBottom: '4px' }}>
                {error}
              </div>
            )}
            {canAddCurrent && (
              <a
                href="#"
                onClick={handleAddCurrent}
                className="action"
                style={{ cursor: isAdding ? 'wait' : 'pointer' }}
              >
                {isAdding ? 'adding...' : `add "${currentNodeTitle}"`}
              </a>
            )}
          </div>
        )}
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Personal Links"
      showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
    >
      <ul className="linklist" style={{ listStyle: 'none', paddingLeft: '8px', margin: '4px 0', fontSize: '12px' }}>
        {personalLinks.map((link, index) => (
          <li key={index} style={{ marginBottom: '2px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <LinkNode title={link} />
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault()
                handleDelete(index)
              }}
              style={{
                marginLeft: '4px',
                cursor: deletingIndex === index ? 'wait' : 'pointer',
                fontSize: '10px',
                color: '#999',
                textDecoration: 'none',
              }}
              title="Remove this link"
            >
              {deletingIndex === index ? '...' : '[x]'}
            </a>
          </li>
        ))}
      </ul>
      {(error || canAddCurrent) && (
        <div className="nodeletfoot" style={{ padding: '4px 8px', fontSize: '11px' }}>
          {error && (
            <div style={{ color: 'red', fontSize: '11px', marginBottom: '4px' }}>
              {error}
            </div>
          )}
          {canAddCurrent && (
            <a
              href="#"
              onClick={handleAddCurrent}
              className="action"
              style={{ cursor: isAdding ? 'wait' : 'pointer' }}
            >
              {isAdding ? 'adding...' : `add "${currentNodeTitle}"`}
            </a>
          )}
        </div>
      )}
    </NodeletContainer>
  )
}

export default PersonalLinks

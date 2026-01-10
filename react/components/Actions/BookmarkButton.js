import React, { useState, useCallback } from 'react'
import { FaBookmark, FaRegBookmark } from 'react-icons/fa'

/**
 * BookmarkButton - Toggle bookmark on a node
 *
 * Uses Font Awesome icons for consistency with E2 design.
 * Solid bookmark when bookmarked, outline when not.
 *
 * Props:
 *   nodeId - ID of the node to bookmark
 *   initialBookmarked - Initial bookmarked state
 *   onUpdate - Optional callback when bookmark state changes
 *   style - Optional additional styles
 */
const BookmarkButton = ({ nodeId, initialBookmarked = false, onUpdate, style }) => {
  const [isBookmarked, setIsBookmarked] = useState(initialBookmarked)
  const [isLoading, setIsLoading] = useState(false)

  const toggleBookmark = useCallback(async () => {
    const prevState = isBookmarked
    setIsBookmarked(!prevState) // Optimistic update
    setIsLoading(true)

    try {
      const response = await fetch(`/api/cool/writeup/${nodeId}/bookmark`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const data = await response.json()

      if (!data.success) {
        throw new Error(data.error || 'Failed to toggle bookmark')
      }

      setIsBookmarked(data.bookmarked)

      if (onUpdate) {
        onUpdate(data.bookmarked)
      }
    } catch (error) {
      setIsBookmarked(prevState) // Revert on error
      console.error('Bookmark error:', error)
    } finally {
      setIsLoading(false)
    }
  }, [nodeId, isBookmarked, onUpdate])

  return (
    <button
      onClick={toggleBookmark}
      disabled={isLoading}
      title={isBookmarked ? 'Remove bookmark' : 'Bookmark this page'}
      style={{
        background: 'none',
        border: 'none',
        cursor: isLoading ? 'wait' : 'pointer',
        padding: '2px 4px',
        fontSize: '14px',
        color: isBookmarked ? '#4060b0' : '#999',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: isLoading ? 0.5 : 1,
        transition: 'color 0.2s ease',
        ...style
      }}
    >
      {isBookmarked ? <FaBookmark /> : <FaRegBookmark />}
    </button>
  )
}

export default BookmarkButton

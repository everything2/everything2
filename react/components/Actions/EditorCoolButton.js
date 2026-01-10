import React, { useState, useCallback } from 'react'
import { FaStar, FaRegStar } from 'react-icons/fa'

/**
 * EditorCoolButton - Toggle editor cool (endorsement) on a writeup
 *
 * Uses Font Awesome icons for consistency with E2 design.
 * Solid gold star when cooled, outline when not.
 *
 * Only visible to editors.
 *
 * Props:
 *   nodeId - ID of the writeup to editor cool
 *   initialCooled - Initial editor cooled state
 *   onUpdate - Optional callback when edcool state changes
 *   style - Optional additional styles
 */
const EditorCoolButton = ({ nodeId, initialCooled = false, onUpdate, style }) => {
  const [isCooled, setIsCooled] = useState(initialCooled)
  const [isLoading, setIsLoading] = useState(false)

  const toggleCool = useCallback(async () => {
    setIsLoading(true)

    try {
      const response = await fetch(`/api/cool/writeup/${nodeId}/edcool`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })
      const data = await response.json()

      if (!data.success) {
        throw new Error(data.error || 'Failed to toggle editor cool')
      }

      setIsCooled(data.edcooled)

      if (onUpdate) {
        onUpdate(data.edcooled)
      }
    } catch (error) {
      console.error('Editor cool error:', error)
    } finally {
      setIsLoading(false)
    }
  }, [nodeId, onUpdate])

  return (
    <button
      onClick={toggleCool}
      disabled={isLoading}
      title={isCooled ? 'Remove editor cool' : 'Add editor cool (endorsement)'}
      style={{
        background: 'none',
        border: 'none',
        cursor: isLoading ? 'wait' : 'pointer',
        padding: '2px 4px',
        fontSize: '14px',
        color: isCooled ? '#f4d03f' : '#999',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: isLoading ? 0.5 : 1,
        transition: 'color 0.2s ease',
        ...style
      }}
    >
      {isCooled ? <FaStar /> : <FaRegStar />}
    </button>
  )
}

export default EditorCoolButton

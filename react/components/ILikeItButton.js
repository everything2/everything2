import React, { useState, useEffect } from 'react'
import { FaThumbsUp } from 'react-icons/fa'

/**
 * ILikeItButton - "I like it!" button for guest users
 *
 * Allows anonymous users to send an appreciation message to writeup authors.
 * Tracked by IP address so each visitor can only like a writeup once.
 *
 * Props:
 *   writeupId - the node_id of the writeup
 *   isGuest - whether the current user is a guest (should only show for guests)
 *   authorTitle - the author's username (for the tooltip)
 */
const ILikeItButton = ({ writeupId, isGuest, authorTitle }) => {
  const [status, setStatus] = useState('loading') // 'loading', 'available', 'liked', 'error'
  const [errorMessage, setErrorMessage] = useState(null)

  // Check if the user has already liked this writeup
  useEffect(() => {
    if (!isGuest || !writeupId) {
      setStatus('hidden')
      return
    }

    const checkStatus = async () => {
      try {
        const response = await fetch(`/api/ilikeit/status/${writeupId}`)
        const data = await response.json()

        if (data.success) {
          if (data.available) {
            setStatus('available')
          } else if (data.already_liked) {
            setStatus('liked')
          } else {
            setStatus('hidden')
          }
        } else {
          setStatus('hidden')
        }
      } catch (error) {
        console.error('Error checking ilikeit status:', error)
        setStatus('hidden')
      }
    }

    checkStatus()
  }, [writeupId, isGuest])

  const handleClick = async (e) => {
    e.preventDefault()

    if (status !== 'available') return

    setStatus('submitting')

    try {
      const response = await fetch(`/api/ilikeit/writeup/${writeupId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })

      const data = await response.json()

      if (data.success) {
        setStatus('liked')
      } else if (data.already_liked) {
        setStatus('liked')
      } else {
        setErrorMessage(data.error || 'Failed to send appreciation')
        setStatus('error')
        // Auto-clear error after 5 seconds
        setTimeout(() => {
          setErrorMessage(null)
          setStatus('available')
        }, 5000)
      }
    } catch (error) {
      console.error('Error sending ilikeit:', error)
      setErrorMessage('Failed to send appreciation')
      setStatus('error')
      setTimeout(() => {
        setErrorMessage(null)
        setStatus('available')
      }, 5000)
    }
  }

  // Don't render anything for non-guests or while checking
  if (status === 'hidden' || status === 'loading') {
    return null
  }

  // Show "Thanks!" after successful like
  if (status === 'liked') {
    return (
      <span style={{ color: '#4a4', fontWeight: 'bold', fontSize: '12px' }}>
        <FaThumbsUp style={{ marginRight: '4px', verticalAlign: 'middle' }} />
        Thanks!
      </span>
    )
  }

  // Show error state
  if (status === 'error' && errorMessage) {
    return (
      <span style={{ color: '#c00', fontSize: '12px' }}>
        {errorMessage}
      </span>
    )
  }

  // Show button (available or submitting)
  return (
    <button
      onClick={handleClick}
      disabled={status === 'submitting'}
      title={authorTitle ? `Tell ${authorTitle} you appreciate their work` : 'Send appreciation to the author'}
      style={{
        background: 'none',
        border: '1px solid #507898',
        borderRadius: '4px',
        cursor: status === 'submitting' ? 'wait' : 'pointer',
        padding: '2px 8px',
        color: '#507898',
        fontSize: '12px',
        display: 'inline-flex',
        alignItems: 'center',
        gap: '4px',
        opacity: status === 'submitting' ? 0.6 : 1
      }}
    >
      <FaThumbsUp style={{ fontSize: '10px' }} />
      {status === 'submitting' ? 'Sending...' : 'I like it!'}
    </button>
  )
}

export default ILikeItButton

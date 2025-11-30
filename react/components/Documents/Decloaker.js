import React, { useEffect, useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Decloaker - Removes user's cloaked status
 *
 * On mount, calls the set_cloaked API to uncloak the user and update global state.
 * Provides a button to recloak. If guest, shows access denied message.
 * Quote is from Shakespeare's All's Well That Ends Well (Parolles).
 */
const Decloaker = ({ data, e2 }) => {
  const [message, setMessage] = useState(data.message)
  const [hasUncloaked, setHasUncloaked] = useState(false)
  const [isCloaked, setIsCloaked] = useState(false)
  const [isLoading, setIsLoading] = useState(false)

  const setCloakStatus = async (cloaked) => {
    setIsLoading(true)
    try {
      const response = await fetch('/api/chatroom/set_cloaked', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ cloaked: cloaked ? 1 : 0 }),
        credentials: 'include'
      })

      const result = await response.json()

      if (response.ok && !result.error) {
        setIsCloaked(cloaked)
        setMessage(cloaked ? 'You have faded back into the shadows.' : '...like a new-born babe....')

        // Update global e2 state if otherUsersData is returned
        if (result.otherUsersData && e2?.updateOtherUsersData) {
          e2.updateOtherUsersData(result.otherUsersData)
        }
        return true
      } else {
        setMessage(result.error || 'Failed to change cloak status')
        return false
      }
    } catch (error) {
      setMessage('Error: ' + error.message)
      return false
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    // Only call API if user is logged in (success=true from server)
    // and we haven't already uncloaked
    if (data.success && !hasUncloaked) {
      setCloakStatus(false).then((success) => {
        if (success) {
          setHasUncloaked(true)
        }
      })
    }
  }, [data.success, hasUncloaked])

  const handleRecloak = () => {
    setCloakStatus(true)
  }

  return (
    <div className="document">
      <p>
        <em>Or to drown my clothes, and say I was stripped.</em> --- <LinkNode title="Parolles" />
      </p>
      <p>{message}</p>
      {data.success && hasUncloaked && !isCloaked && (
        <p>
          <button onClick={handleRecloak} disabled={isLoading}>
            {isLoading ? 'Working...' : 'Back into the shadows'}
          </button>
        </p>
      )}
    </div>
  )
}

export default Decloaker

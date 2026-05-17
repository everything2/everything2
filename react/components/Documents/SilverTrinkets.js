import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Silver Trinkets - Display user's sanctity (silver trinkets received)
 * Styles in CSS: .silver-trinkets__*
 *
 * Phase 4a migration from Mason template silver_trinkets.mc
 * Shows: User's sanctity count, admin lookup feature
 */
const SilverTrinkets = ({ data, user }) => {
  const [lookupUsername, setLookupUsername] = useState('')
  const [lookupResult, setLookupResult] = useState(null)
  const [lookupError, setLookupError] = useState(null)
  const [loading, setLoading] = useState(false)

  const sanctity = data.sanctity || 0
  const isAdmin = user?.is_admin || false

  const handleLookup = async (e) => {
    e.preventDefault()
    setLoading(true)
    setLookupError(null)
    setLookupResult(null)

    try {
      const response = await fetch(`/api/user/sanctity?username=${encodeURIComponent(lookupUsername)}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || `HTTP ${response.status}`)
      }

      const result = await response.json()
      setLookupResult(result)
    } catch (err) {
      console.error('Failed to lookup sanctity:', err)
      setLookupError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="silver-trinkets">
      <div className="silver-trinkets__message">
        {sanctity <= 0 ? (
          <em>You are not feeling very special right now.</em>
        ) : (
          <>
            You feel validated -- every day, your fellow users look upon you and approve -- you have
            collected {sanctity} of their{' '}
            <LinkNode title="sanctify" type="document" display="Silver Trinkets" />
          </>
        )}
      </div>

      {isAdmin && (
        <div className="silver-trinkets__admin-box">
          <h3 className="silver-trinkets__admin-title">Admin Lookup</h3>

          <form onSubmit={handleLookup}>
            <div className="silver-trinkets__form-row">
              <input
                type="text"
                value={lookupUsername}
                onChange={(e) => setLookupUsername(e.target.value)}
                placeholder="Enter username"
                className="silver-trinkets__input"
              />
              <button
                type="submit"
                disabled={loading || !lookupUsername}
                className="silver-trinkets__submit-btn"
              >
                {loading ? 'Looking up...' : 'Lookup'}
              </button>
            </div>
          </form>

          {lookupError && (
            <div className="silver-trinkets__error-box">
              <em>{lookupError}</em>
            </div>
          )}

          {lookupResult && (
            <div className="silver-trinkets__result-box">
              <LinkNode
                title={lookupResult.username}
                type="user"
              />'s sanctity: {lookupResult.sanctity}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default SilverTrinkets

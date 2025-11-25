import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Silver Trinkets - Display user's sanctity (silver trinkets received)
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
    <div className="silver-trinkets" style={{ padding: '40px 20px', textAlign: 'center' }}>
      <div style={{ fontSize: '16px', marginBottom: '40px' }}>
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
        <div style={{
          marginTop: '40px',
          padding: '20px',
          backgroundColor: '#f8f9fa',
          border: '1px solid #dee2e6',
          borderRadius: '5px',
          maxWidth: '500px',
          margin: '40px auto'
        }}>
          <h3 style={{ marginTop: 0 }}>Admin Lookup</h3>

          <form onSubmit={handleLookup}>
            <div style={{ marginBottom: '10px' }}>
              <input
                type="text"
                value={lookupUsername}
                onChange={(e) => setLookupUsername(e.target.value)}
                placeholder="Enter username"
                style={{
                  padding: '8px 12px',
                  fontSize: '14px',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  width: '200px'
                }}
              />
              <button
                type="submit"
                disabled={loading || !lookupUsername}
                style={{
                  marginLeft: '10px',
                  padding: '8px 16px',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  color: '#fff',
                  backgroundColor: loading ? '#ccc' : '#38495e',
                  border: 'none',
                  borderRadius: '3px',
                  cursor: loading ? 'not-allowed' : 'pointer'
                }}
              >
                {loading ? 'Looking up...' : 'Lookup'}
              </button>
            </div>
          </form>

          {lookupError && (
            <div style={{
              marginTop: '10px',
              padding: '10px',
              backgroundColor: '#fff3cd',
              border: '1px solid #ffc107',
              borderRadius: '3px',
              color: '#856404'
            }}>
              <em>{lookupError}</em>
            </div>
          )}

          {lookupResult && (
            <div style={{
              marginTop: '10px',
              padding: '10px',
              backgroundColor: '#d4edda',
              border: '1px solid #c3e6cb',
              borderRadius: '3px',
              color: '#155724'
            }}>
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

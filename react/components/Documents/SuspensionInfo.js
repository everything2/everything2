import React, { useState, useEffect } from 'react'
import ParseLinks from '../ParseLinks'

/**
 * SuspensionInfo - Manage user suspensions for Chanops, Editors, and Admins
 *
 * Migrated from document.pm suspension_info() delegation function
 *
 * Permissions:
 * - Chanops: Can manage chat, room, and topic suspensions
 * - Editors/Admins: Can manage all suspension types
 *
 * Props:
 * - user: Current user object
 */
const SuspensionInfo = ({ user }) => {
  // Check for suspendee query parameter to pre-fill username
  const urlParams = new URLSearchParams(window.location.search)
  const initialUsername = urlParams.get('suspendee') || ''

  const [username, setUsername] = useState(initialUsername)
  const [lookupData, setLookupData] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [successMessage, setSuccessMessage] = useState(null)

  const isChanop = user?.chanop || false
  const isEditor = user?.editor || false
  const isAdmin = user?.is_admin || false
  const hasAccess = isChanop || isEditor || isAdmin

  // Auto-lookup if suspendee was provided in URL
  useEffect(() => {
    if (initialUsername && hasAccess) {
      // Trigger initial lookup
      handleLookupByUsername(initialUsername)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleLookupByUsername = async (lookupUsername) => {
    if (!lookupUsername.trim()) return

    setLoading(true)
    setError(null)
    setSuccessMessage(null)

    try {
      const response = await fetch(`/api/suspension/user/${encodeURIComponent(lookupUsername)}`)
      const data = await response.json()

      if (response.ok) {
        setLookupData(data)
      } else {
        setError(data.error || 'Failed to fetch suspension info')
        setLookupData(null)
      }
    } catch (err) {
      setError('Network error: ' + err.message)
      setLookupData(null)
    } finally {
      setLoading(false)
    }
  }

  const handleLookup = async (e) => {
    e.preventDefault()
    handleLookupByUsername(username)
  }

  const handleSuspend = async (typeId, typeName) => {
    setLoading(true)
    setError(null)
    setSuccessMessage(null)

    try {
      const response = await fetch('/api/suspension/suspend', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: lookupData.username,
          sustype_id: typeId
        })
      })

      const data = await response.json()

      if (response.ok) {
        setSuccessMessage(data.message)
        // Refresh the data
        const refreshResponse = await fetch(`/api/suspension/user/${encodeURIComponent(lookupData.username)}`)
        const refreshData = await refreshResponse.json()
        if (refreshResponse.ok) {
          setLookupData(refreshData)
        }
      } else {
        setError(data.error || 'Failed to suspend user')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleUnsuspend = async (typeId, typeName) => {
    setLoading(true)
    setError(null)
    setSuccessMessage(null)

    try {
      const response = await fetch('/api/suspension/unsuspend', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: lookupData.username,
          sustype_id: typeId
        })
      })

      const data = await response.json()

      if (response.ok) {
        setSuccessMessage(data.message)
        // Refresh the data
        const refreshResponse = await fetch(`/api/suspension/user/${encodeURIComponent(lookupData.username)}`)
        const refreshData = await refreshResponse.json()
        if (refreshResponse.ok) {
          setLookupData(refreshData)
        }
      } else {
        setError(data.error || 'Failed to unsuspend user')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateStr) => {
    if (!dateStr) return ''
    const match = dateStr.match(/(\d{4})-?(\d{2})-?(\d{2})\s*(\d{2}):?(\d{2}):?(\d{2})/)
    if (!match) return dateStr
    return `${match[2]}-${match[3]}-${match[1]} at ${match[4]}:${match[5]}:${match[6]}`
  }

  if (!hasAccess) {
    return (
      <div style={{ maxWidth: '800px', margin: '20px auto', padding: '20px' }}>
        <p>Looks like you stumbled upon a page you can't access. Try the <ParseLinks text="[Welcome to Everything|front page]" />.</p>
      </div>
    )
  }

  return (
    <div style={{ maxWidth: '1200px', margin: '20px auto', padding: '20px' }}>
      <p style={{ marginBottom: '20px' }}>
        <strong>See also:</strong> <ParseLinks text="[Node Forbiddance]" /> to suspend writeup posting privileges.
      </p>

      <form onSubmit={handleLookup} style={{ marginBottom: '20px' }}>
        <label style={{ marginRight: '10px' }}>
          Check suspension info for:
        </label>
        <input
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Username"
          disabled={loading}
          style={{
            padding: '5px 10px',
            border: '1px solid #d3d3d3',
            borderRadius: '3px',
            marginRight: '10px',
            width: '200px'
          }}
        />
        <button
          type="submit"
          disabled={loading || !username.trim()}
          style={{
            padding: '5px 15px',
            backgroundColor: loading ? '#c5cdd7' : '#38495e',
            color: '#fff',
            border: 'none',
            borderRadius: '3px',
            cursor: loading || !username.trim() ? 'not-allowed' : 'pointer'
          }}
        >
          {loading ? 'Loading...' : 'Check info'}
        </button>
      </form>

      {successMessage && (
        <div style={{
          padding: '15px',
          marginBottom: '20px',
          backgroundColor: '#f8f9f9',
          border: '2px solid #38495e',
          borderRadius: '4px',
          color: '#38495e',
          fontSize: '18px',
          fontWeight: 'bold'
        }}>
          {successMessage}
        </div>
      )}

      {error && (
        <div style={{
          padding: '15px',
          marginBottom: '20px',
          backgroundColor: '#fff5f5',
          border: '1px solid #ff0000',
          borderRadius: '4px',
          color: '#8b0000'
        }}>
          {error}
        </div>
      )}

      {lookupData && (
        <div style={{ marginBottom: '30px' }}>
          <table style={{
            width: '100%',
            borderCollapse: 'collapse',
            border: '1px solid #d3d3d3'
          }}>
            <tbody>
              <tr>
                <td style={{
                  padding: '15px',
                  verticalAlign: 'center',
                  backgroundColor: '#f8f9f9',
                  fontWeight: 'bold',
                  borderRight: '1px solid #d3d3d3'
                }}>
                  Suspension info for:<br />
                  <strong style={{ fontSize: '18px', color: '#38495e' }}>
                    {lookupData.username}
                  </strong>
                </td>

                {lookupData.suspensions.map((suspension, index) => (
                  <React.Fragment key={suspension.type_id}>
                    <td style={{
                      padding: '15px',
                      textAlign: 'center',
                      borderRight: index < lookupData.suspensions.length - 1 ? '1px solid #d3d3d3' : 'none'
                    }}>
                      <p style={{ fontWeight: 'bold', marginBottom: '10px' }}>
                        {suspension.type} suspension
                      </p>

                      {suspension.suspended ? (
                        <>
                          <p style={{ fontSize: '12px', color: '#507898', marginBottom: '5px' }}>
                            Suspended by <ParseLinks text={`[${suspension.suspended_by}]`} />
                          </p>
                          <p style={{ fontSize: '11px', color: '#507898', marginBottom: '10px' }}>
                            on {formatDate(suspension.started)}
                          </p>
                          <p style={{ fontSize: '12px' }}>
                            <button
                              onClick={() => handleUnsuspend(suspension.type_id, suspension.type)}
                              disabled={loading}
                              style={{
                                padding: '5px 10px',
                                backgroundColor: loading ? '#c5cdd7' : '#4060b0',
                                color: '#fff',
                                border: 'none',
                                borderRadius: '3px',
                                cursor: loading ? 'not-allowed' : 'pointer',
                                fontSize: '12px'
                              }}
                            >
                              Unsuspend
                            </button>
                          </p>
                        </>
                      ) : (
                        <>
                          <p style={{ fontSize: '12px', fontStyle: 'italic', color: '#507898', marginBottom: '10px' }}>
                            No restriction
                          </p>
                          <p style={{ fontSize: '12px' }}>
                            <button
                              onClick={() => handleSuspend(suspension.type_id, suspension.type)}
                              disabled={loading}
                              style={{
                                padding: '5px 10px',
                                backgroundColor: loading ? '#c5cdd7' : '#8b0000',
                                color: '#fff',
                                border: 'none',
                                borderRadius: '3px',
                                cursor: loading ? 'not-allowed' : 'pointer',
                                fontSize: '12px'
                              }}
                            >
                              Suspend
                            </button>
                          </p>
                        </>
                      )}
                    </td>
                  </React.Fragment>
                ))}
              </tr>
            </tbody>
          </table>
        </div>
      )}

      <hr style={{ margin: '30px 0', border: 'none', borderTop: '1px solid #d3d3d3' }} />

      <div style={{ fontSize: '14px', lineHeight: '1.6' }}>
        <strong>General Information:</strong>
        <p>
          Each type of suspension carries its own weight. More can be added later, but for right
          now, this works. Borging and account locking may eventually move to this one interface.
        </p>

        {lookupData && lookupData.available_types.length > 0 && (
          <dl style={{ marginTop: '20px' }}>
            {lookupData.available_types.map((type) => (
              <React.Fragment key={type.node_id}>
                <dt style={{ fontWeight: 'bold', marginTop: '10px', color: '#38495e' }}>
                  {type.title}
                </dt>
                <dd style={{ marginLeft: '20px', color: '#507898' }}>
                  <ParseLinks text={type.description} />
                </dd>
              </React.Fragment>
            ))}
          </dl>
        )}

        <p style={{ marginTop: '20px', color: '#507898' }}>
          Keep in mind that the punishment should fit the crime, and that systematic downvoting is
          not a "crime" at all, regardless of what an asshole thing to do that it is. Autovoters,
          C! abusers, etc. Use these sparingly, but as needed.
        </p>
      </div>
    </div>
  )
}

export default SuspensionInfo

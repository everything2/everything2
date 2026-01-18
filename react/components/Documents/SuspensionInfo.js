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
      <div className="suspension-info suspension-info--denied">
        <p>Looks like you stumbled upon a page you can't access. Try the <ParseLinks text="[Welcome to Everything|front page]" />.</p>
      </div>
    )
  }

  return (
    <div className="suspension-info">
      <p className="suspension-info__see-also">
        <strong>See also:</strong> <ParseLinks text="[Node Forbiddance]" /> to suspend writeup posting privileges.
      </p>

      <form onSubmit={handleLookup} className="suspension-info__form">
        <label className="suspension-info__form-label">
          Check suspension info for:
        </label>
        <input
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Username"
          disabled={loading}
          className="suspension-info__input"
        />
        <button
          type="submit"
          disabled={loading || !username.trim()}
          className="suspension-info__btn"
        >
          {loading ? 'Loading...' : 'Check info'}
        </button>
      </form>

      {successMessage && (
        <div className="suspension-info__success">
          {successMessage}
        </div>
      )}

      {error && (
        <div className="suspension-info__error">
          {error}
        </div>
      )}

      {lookupData && (
        <div className="suspension-info__results">
          <table className="suspension-info__table">
            <tbody>
              <tr>
                <td className="suspension-info__header-cell">
                  Suspension info for:<br />
                  <strong className="suspension-info__username">
                    {lookupData.username}
                  </strong>
                </td>

                {lookupData.suspensions.map((suspension, index) => (
                  <React.Fragment key={suspension.type_id}>
                    <td className={`suspension-info__status-cell${index < lookupData.suspensions.length - 1 ? ' suspension-info__status-cell--bordered' : ''}`}>
                      <p className="suspension-info__type-label">
                        {suspension.type} suspension
                      </p>

                      {suspension.suspended ? (
                        <>
                          <p className="suspension-info__meta">
                            Suspended by <ParseLinks text={`[${suspension.suspended_by}]`} />
                          </p>
                          <p className="suspension-info__meta suspension-info__meta--small">
                            on {formatDate(suspension.started)}
                          </p>
                          <p className="suspension-info__action">
                            <button
                              onClick={() => handleUnsuspend(suspension.type_id, suspension.type)}
                              disabled={loading}
                              className="suspension-info__btn--action suspension-info__btn--unsuspend"
                            >
                              Unsuspend
                            </button>
                          </p>
                        </>
                      ) : (
                        <>
                          <p className="suspension-info__no-restriction">
                            No restriction
                          </p>
                          <p className="suspension-info__action">
                            <button
                              onClick={() => handleSuspend(suspension.type_id, suspension.type)}
                              disabled={loading}
                              className="suspension-info__btn--action suspension-info__btn--suspend"
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

      <hr className="suspension-info__divider" />

      <div className="suspension-info__help">
        <strong>General Information:</strong>
        <p>
          Each type of suspension carries its own weight. More can be added later, but for right
          now, this works. Borging and account locking may eventually move to this one interface.
        </p>

        {lookupData && lookupData.available_types.length > 0 && (
          <dl className="suspension-info__types">
            {lookupData.available_types.map((type) => (
              <React.Fragment key={type.node_id}>
                <dt className="suspension-info__type-title">
                  {type.title}
                </dt>
                <dd className="suspension-info__type-desc">
                  <ParseLinks text={type.description} />
                </dd>
              </React.Fragment>
            ))}
          </dl>
        )}

        <p className="suspension-info__note">
          Keep in mind that the punishment should fit the crime, and that systematic downvoting is
          not a "crime" at all, regardless of what an asshole thing to do that it is. Autovoters,
          C! abusers, etc. Use these sparingly, but as needed.
        </p>
      </div>
    </div>
  )
}

export default SuspensionInfo

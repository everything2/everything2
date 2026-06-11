import React, { useState, useCallback } from 'react'

/**
 * Recalculate XP - XP recalculation tool
 * Styles in CSS: .recalculate-xp__*
 *
 * Converts user XP total to the new system calculation.
 * Excess XP is converted to GP bonus.
 */
const RecalculateXp = ({ data }) => {
  const xpData = data?.recalculateXp || {}
  const {
    isAdmin,
    username,
    canRecalculate,
    ineligibleReason,
    currentXP,
    writeupCount,
    upvotesReceived,
    coolsReceived,
    recalculatedXP,
    gpBonus,
  } = xpData

  const [confirmed, setConfirmed] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [result, setResult] = useState(null)
  const [targetUsername, setTargetUsername] = useState('')
  const [stats, setStats] = useState(null)
  const [statsLoading, setStatsLoading] = useState(false)

  const handleLookup = useCallback(async () => {
    if (!targetUsername.trim()) return

    setStatsLoading(true)
    setError(null)
    setStats(null)

    try {
      const response = await fetch('/api/xp/stats', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ username: targetUsername.trim() }),
      })

      const data = await response.json()

      if (data.success) {
        setStats(data)
      } else {
        setError(data.error || 'Failed to look up user')
      }
    } catch (err) {
      setError('Failed to connect to the server')
    } finally {
      setStatsLoading(false)
    }
  }, [targetUsername])

  const handleRecalculate = useCallback(async () => {
    if (!confirmed) return

    setLoading(true)
    setError(null)

    try {
      const body = { confirmed: true }
      if (stats?.username) {
        body.username = stats.username
      }

      const response = await fetch('/api/xp/recalculate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(body),
      })

      const data = await response.json()

      if (data.success) {
        setResult(data)
      } else {
        setError(data.error || 'Recalculation failed')
      }
    } catch (err) {
      setError('Failed to connect to the server')
    } finally {
      setLoading(false)
    }
  }, [confirmed, stats])

  // Determine which stats to display
  const displayStats = stats || {
    username,
    canRecalculate,
    ineligibleReason,
    currentXP,
    writeupCount,
    upvotesReceived,
    coolsReceived,
    recalculatedXP,
    gpBonus,
  }

  // Show success result
  if (result) {
    return (
      <div className="recalculate-xp">
        <div className="recalculate-xp__header">
          <h1 className="recalculate-xp__title">Recalculate XP</h1>
        </div>
        <div className="recalculate-xp__success">
          <p><strong>{result.message}</strong></p>
          <p>You now have <strong>{result.newXP} XP</strong>
          {result.gpBonus > 0 && (
            <> and <strong>{result.newGP} GP</strong> (including a bonus of {result.gpBonus} GP)</>
          )}.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="recalculate-xp">
      <div className="recalculate-xp__header">
        <h1 className="recalculate-xp__title">Recalculate XP</h1>
      </div>

      <div className="recalculate-xp__intro">
        <p>This tool converts your current XP total to the XP total you would have
        if the new system had been in place since the start of your time as a noder.
        Any excess XP will be converted into GP.</p>
        <p>Conversion is permanent; once you recalculate, you cannot go back.
        Each user can only recalculate their XP one time.</p>
      </div>

      {error && <div className="recalculate-xp__error">{error}</div>}

      {/* Admin lookup */}
      {!!isAdmin && (
        <div className="recalculate-xp__admin-box">
          <strong>Admin: Look up another user</strong>
          <div className="recalculate-xp__admin-row">
            <input
              type="text"
              value={targetUsername}
              onChange={(e) => setTargetUsername(e.target.value)}
              placeholder="Username"
              className="recalculate-xp__input"
              disabled={statsLoading}
            />
            <button
              onClick={handleLookup}
              disabled={statsLoading || !targetUsername.trim()}
              className={`recalculate-xp__button recalculate-xp__lookup-button ${statsLoading || !targetUsername.trim() ? 'recalculate-xp__button--disabled' : ''}`}
            >
              {statsLoading ? 'Looking up...' : 'Look Up'}
            </button>
          </div>
        </div>
      )}

      {/* Stats display */}
      {displayStats.username && (
        <>
          <div className="recalculate-xp__username">User: {displayStats.username}</div>

          <table className="recalculate-xp__table">
            <tbody>
              <tr className="recalculate-xp__row--odd">
                <td className="recalculate-xp__td">Current XP:</td>
                <td className="recalculate-xp__td--right">{displayStats.currentXP}</td>
              </tr>
              <tr className="recalculate-xp__row--even">
                <td className="recalculate-xp__td">Writeups:</td>
                <td className="recalculate-xp__td--right">{displayStats.writeupCount}</td>
              </tr>
              <tr className="recalculate-xp__row--odd">
                <td className="recalculate-xp__td">Upvotes Received:</td>
                <td className="recalculate-xp__td--right">{displayStats.upvotesReceived}</td>
              </tr>
              <tr className="recalculate-xp__row--even">
                <td className="recalculate-xp__td">C!s Received:</td>
                <td className="recalculate-xp__td--right">{displayStats.coolsReceived}</td>
              </tr>
              <tr className="recalculate-xp__row--odd">
                <td className="recalculate-xp__td"><strong>Recalculated XP:</strong></td>
                <td className="recalculate-xp__td--right"><strong>{displayStats.recalculatedXP}</strong></td>
              </tr>
            </tbody>
          </table>

          {displayStats.gpBonus > 0 && (
            <div className="recalculate-xp__bonus-box">
              <strong>Recalculation Bonus!</strong> Your current XP is greater than your recalculated XP,
              so if you choose to recalculate you will be awarded a one-time bonus of{' '}
              <strong>{displayStats.gpBonus} GP!</strong>
            </div>
          )}

          {!displayStats.canRecalculate ? (
            <div className="recalculate-xp__ineligible">
              <strong>Not Eligible:</strong> {displayStats.ineligibleReason}
            </div>
          ) : (
            <div className="recalculate-xp__form">
              <label className="recalculate-xp__label">
                <input
                  type="checkbox"
                  checked={confirmed}
                  onChange={(e) => setConfirmed(e.target.checked)}
                  className="recalculate-xp__checkbox"
                  disabled={loading}
                />
                <span className="recalculate-xp__label-text">
                  I understand that recalculating my stats is permanent, and that I can never go back once I have done so.
                </span>
              </label>
              <button
                onClick={handleRecalculate}
                disabled={loading || !confirmed}
                className={`recalculate-xp__button ${loading || !confirmed ? 'recalculate-xp__button--disabled' : ''}`}
              >
                {loading ? 'Recalculating...' : 'Recalculate!'}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default RecalculateXp

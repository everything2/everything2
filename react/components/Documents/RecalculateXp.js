import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '700px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  intro: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  username: {
    fontWeight: 'bold',
    marginBottom: '15px',
    fontSize: '1.1rem',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px',
  },
  th: {
    textAlign: 'left',
    padding: '10px',
    border: '1px solid silver',
    backgroundColor: '#f8f9fa',
  },
  td: {
    padding: '10px',
    border: '1px solid silver',
  },
  tdRight: {
    padding: '10px',
    border: '1px solid silver',
    textAlign: 'right',
  },
  oddRow: {
    backgroundColor: '#ffffff',
  },
  evenRow: {
    backgroundColor: '#f8f9fa',
  },
  bonusBox: {
    padding: '15px',
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  ineligible: {
    padding: '15px',
    backgroundColor: '#f8d7da',
    border: '1px solid #f5c6cb',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  form: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffeeba',
    borderRadius: '8px',
  },
  checkbox: {
    marginRight: '10px',
  },
  label: {
    display: 'flex',
    alignItems: 'flex-start',
    marginBottom: '15px',
    cursor: 'pointer',
  },
  labelText: {
    flex: 1,
    lineHeight: '1.5',
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  buttonDisabled: {
    backgroundColor: '#999',
    cursor: 'not-allowed',
  },
  error: {
    padding: '10px',
    backgroundColor: '#f8d7da',
    color: '#721c24',
    borderRadius: '4px',
    marginBottom: '15px',
  },
  success: {
    padding: '15px',
    backgroundColor: '#d4edda',
    color: '#155724',
    borderRadius: '8px',
    marginBottom: '15px',
  },
  adminBox: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#cce5ff',
    borderRadius: '8px',
  },
  input: {
    padding: '8px',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    marginRight: '10px',
  },
}

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
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Recalculate XP</h1>
        </div>
        <div style={styles.success}>
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
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Recalculate XP</h1>
      </div>

      <div style={styles.intro}>
        <p>This tool converts your current XP total to the XP total you would have
        if the new system had been in place since the start of your time as a noder.
        Any excess XP will be converted into GP.</p>
        <p>Conversion is permanent; once you recalculate, you cannot go back.
        Each user can only recalculate their XP one time.</p>
      </div>

      {error && <div style={styles.error}>{error}</div>}

      {/* Admin lookup */}
      {isAdmin && (
        <div style={styles.adminBox}>
          <strong>Admin: Look up another user</strong>
          <div style={{ marginTop: '10px' }}>
            <input
              type="text"
              value={targetUsername}
              onChange={(e) => setTargetUsername(e.target.value)}
              placeholder="Username"
              style={styles.input}
              disabled={statsLoading}
            />
            <button
              onClick={handleLookup}
              disabled={statsLoading || !targetUsername.trim()}
              style={{
                ...styles.button,
                ...(statsLoading || !targetUsername.trim() ? styles.buttonDisabled : {}),
                padding: '8px 15px',
              }}
            >
              {statsLoading ? 'Looking up...' : 'Look Up'}
            </button>
          </div>
        </div>
      )}

      {/* Stats display */}
      {displayStats.username && (
        <>
          <div style={styles.username}>User: {displayStats.username}</div>

          <table style={styles.table}>
            <tbody>
              <tr style={styles.oddRow}>
                <td style={styles.td}>Current XP:</td>
                <td style={styles.tdRight}>{displayStats.currentXP}</td>
              </tr>
              <tr style={styles.evenRow}>
                <td style={styles.td}>Writeups:</td>
                <td style={styles.tdRight}>{displayStats.writeupCount}</td>
              </tr>
              <tr style={styles.oddRow}>
                <td style={styles.td}>Upvotes Received:</td>
                <td style={styles.tdRight}>{displayStats.upvotesReceived}</td>
              </tr>
              <tr style={styles.evenRow}>
                <td style={styles.td}>C!s Received:</td>
                <td style={styles.tdRight}>{displayStats.coolsReceived}</td>
              </tr>
              <tr style={styles.oddRow}>
                <td style={styles.td}><strong>Recalculated XP:</strong></td>
                <td style={styles.tdRight}><strong>{displayStats.recalculatedXP}</strong></td>
              </tr>
            </tbody>
          </table>

          {displayStats.gpBonus > 0 && (
            <div style={styles.bonusBox}>
              <strong>Recalculation Bonus!</strong> Your current XP is greater than your recalculated XP,
              so if you choose to recalculate you will be awarded a one-time bonus of{' '}
              <strong>{displayStats.gpBonus} GP!</strong>
            </div>
          )}

          {!displayStats.canRecalculate ? (
            <div style={styles.ineligible}>
              <strong>Not Eligible:</strong> {displayStats.ineligibleReason}
            </div>
          ) : (
            <div style={styles.form}>
              <label style={styles.label}>
                <input
                  type="checkbox"
                  checked={confirmed}
                  onChange={(e) => setConfirmed(e.target.checked)}
                  style={styles.checkbox}
                  disabled={loading}
                />
                <span style={styles.labelText}>
                  I understand that recalculating my stats is permanent, and that I can never go back once I have done so.
                </span>
              </label>
              <button
                onClick={handleRecalculate}
                disabled={loading || !confirmed}
                style={{
                  ...styles.button,
                  ...(loading || !confirmed ? styles.buttonDisabled : {}),
                }}
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

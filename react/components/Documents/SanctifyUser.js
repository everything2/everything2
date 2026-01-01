import React, { useState, useCallback, useEffect } from 'react'
import LinkNode from '../LinkNode'

const styles = {
  container: {
    maxWidth: '800px',
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
  section: {
    marginBottom: '20px',
  },
  paragraph: {
    marginBottom: '10px',
    lineHeight: '1.5',
  },
  highlight: {
    fontWeight: 'bold',
    color: '#006400',
  },
  form: {
    marginTop: '15px',
    padding: '15px',
    backgroundColor: '#f9f9f9',
    borderRadius: '4px',
  },
  formRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    marginBottom: '10px',
  },
  label: {
    minWidth: '100px',
    fontWeight: 'bold',
  },
  input: {
    padding: '8px 12px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    fontSize: '14px',
    width: '200px',
  },
  checkboxRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '15px',
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#006400',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
  },
  buttonDisabled: {
    backgroundColor: '#999',
    cursor: 'not-allowed',
  },
  message: {
    padding: '10px 15px',
    borderRadius: '4px',
    marginTop: '15px',
  },
  success: {
    backgroundColor: '#d4edda',
    color: '#155724',
    border: '1px solid #c3e6cb',
  },
  error: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
  },
  infoBox: {
    padding: '15px',
    backgroundColor: '#e7f3ff',
    border: '1px solid #b8daff',
    borderRadius: '4px',
    marginBottom: '20px',
  },
  warningBox: {
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    marginBottom: '20px',
  },
  gpDisplay: {
    fontSize: '1.2rem',
    fontWeight: 'bold',
    color: '#006400',
    marginBottom: '15px',
  },
  backLink: {
    marginTop: '20px',
    paddingTop: '15px',
    borderTop: '1px solid #eee',
  },
}

const SanctifyUser = ({ data }) => {
  const initialData = data.sanctify || {}
  const [sanctifyData, setSanctifyData] = useState(initialData)
  const [recipient, setRecipient] = useState('')
  const [anonymous, setAnonymous] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { canSanctify, reason, gp, level, sanctifyAmount, minLevel, gpOptOut, userSanctity } = sanctifyData

  // Pre-fill recipient from query parameter if provided
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search)
    const recipientParam = urlParams.get('recipient')
    if (recipientParam) {
      setRecipient(recipientParam)
    }
  }, [])

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/sanctify/give', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          recipient: recipient.trim(),
          anonymous,
        }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message })
        setSanctifyData(prev => ({
          ...prev,
          gp: result.newGP,
          canSanctify: result.newGP >= sanctifyAmount,
        }))
        setRecipient('')
        setAnonymous(false)

        // Update epicenter
        window.dispatchEvent(new CustomEvent('e2:userUpdate', {
          detail: { gp: result.newGP }
        }))
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }, [recipient, anonymous, sanctifyAmount])

  // Cannot sanctify - show the reason from the Page controller
  // The Page controller handles all permission checks including:
  // - GP optout
  // - Level requirement (with editor bypass)
  // - Insufficient GP
  if (!canSanctify && reason) {
    const isLevelIssue = reason.includes('Level')
    const isGpIssue = reason.includes('GP') && !reason.includes('opted out')
    const isOptOut = reason.includes('opted out')

    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Sanctify User</h1>
        </div>
        <div style={styles.warningBox}>
          {isLevelIssue && (
            <p style={styles.paragraph}>
              Who do you think you are? The Pope or something?
            </p>
          )}
          <p style={styles.paragraph}>
            {isLevelIssue ? (
              <>
                Sorry, but you will have to come back when you reach{' '}
                <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display={`Level ${minLevel}`} />.
              </>
            ) : isGpIssue ? (
              <>
                Sorry, but you don't have at least <span style={styles.highlight}>{sanctifyAmount} GP</span> to give away.
                Please come back when you have more GP.
              </>
            ) : isOptOut ? (
              <>
                Sorry, this tool can only be used by people who have{' '}
                <LinkNode type="superdoc" title="Settings" display="opted in" /> to the GP system.
              </>
            ) : (
              reason
            )}
          </p>
        </div>
        <div style={styles.backLink}>
          <p>Return to the <LinkNode type="superdoc" title="E2 Gift Shop" />.</p>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Sanctify User</h1>
      </div>

      <div style={styles.infoBox}>
        <p style={styles.paragraph}>
          This tool lets you give <span style={styles.highlight}>{sanctifyAmount} GP</span> at a time to any user of your choice.
          The GP is transferred from your own account to theirs.
        </p>
        <p style={{ ...styles.paragraph, marginBottom: 0 }}>
          Please use it for the good of Everything2!
        </p>
      </div>

      <div style={styles.gpDisplay}>
        You currently have: {gp} GP
      </div>

      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <label style={styles.label}>Recipient:</label>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            style={styles.input}
            placeholder="Username"
            required
            disabled={loading}
          />
        </div>

        <div style={styles.checkboxRow}>
          <input
            type="checkbox"
            id="anonymous"
            checked={anonymous}
            onChange={(e) => setAnonymous(e.target.checked)}
            disabled={loading}
          />
          <label htmlFor="anonymous">Remain anonymous</label>
        </div>

        <button
          type="submit"
          style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
          disabled={loading || !recipient.trim()}
        >
          {loading ? 'Sanctifying...' : 'Sanctify!'}
        </button>
      </form>

      {message && (
        <div style={{ ...styles.message, ...(message.type === 'success' ? styles.success : styles.error) }}>
          {message.text}
          {message.type === 'success' && (
            <p style={{ marginTop: '10px', marginBottom: 0 }}>
              You have <strong>{sanctifyData.gp} GP</strong> left.
              Would you like to sanctify someone else?
            </p>
          )}
        </div>
      )}

      <div style={styles.backLink}>
        <p>Return to the <LinkNode type="superdoc" title="E2 Gift Shop" />.</p>
      </div>
    </div>
  )
}

export default SanctifyUser

import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '600px',
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
  message: {
    padding: '20px',
    marginBottom: '20px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    lineHeight: '1.6',
  },
  closedMessage: {
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    textAlign: 'center',
    fontStyle: 'italic',
  },
  currentCostume: {
    padding: '15px',
    backgroundColor: '#d4edda',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  form: {
    marginTop: '20px',
  },
  inputGroup: {
    display: 'flex',
    gap: '10px',
    marginBottom: '15px',
  },
  input: {
    flex: 1,
    padding: '10px',
    fontSize: '16px',
    border: '1px solid #ccc',
    borderRadius: '4px',
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#ff6600',
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
  cost: {
    fontSize: '14px',
    color: '#666',
  },
  error: {
    padding: '10px',
    backgroundColor: '#f8d7da',
    color: '#721c24',
    borderRadius: '4px',
    marginBottom: '15px',
  },
  success: {
    padding: '10px',
    backgroundColor: '#d4edda',
    color: '#155724',
    borderRadius: '4px',
    marginBottom: '15px',
  },
  adminNote: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#cce5ff',
    borderRadius: '8px',
    fontSize: '14px',
  },
}

const TheCostumeShop = ({ data }) => {
  const shop = data?.costumeShop || {}
  const {
    isHalloween,
    isAdmin,
    userGP,
    costumeCost,
    currentCostume,
    hasCostume,
    canAfford,
  } = shop

  const [costume, setCostume] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [newCostume, setNewCostume] = useState(currentCostume)

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    setSuccess(null)

    try {
      const response = await fetch('/api/costumes/buy', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ costume: costume.trim() }),
      })

      const result = await response.json()

      if (result.success) {
        setSuccess(result.message)
        setNewCostume(result.newCostume)
        setCostume('')
      } else {
        setError(result.error || 'Something went wrong')
      }
    } catch (err) {
      setError('Failed to connect to the server')
    } finally {
      setLoading(false)
    }
  }, [costume])

  if (!isHalloween) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>The Costume Shop</h1>
        </div>
        <div style={{...styles.message, ...styles.closedMessage}}>
          Sorry, shop's closed. Check back on All Hallows' Eve...
        </div>
      </div>
    )
  }

  if (!canAfford && !hasCostume) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>The Costume Shop</h1>
        </div>
        <div style={styles.message}>
          Sorry - a costume don't come free. Go start a lemonade stand or something.
        </div>
        <div style={styles.cost}>
          Cost: {costumeCost} GP | Your GP: {userGP}
        </div>
      </div>
    )
  }

  if (!canAfford && hasCostume) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>The Costume Shop</h1>
        </div>
        <div style={styles.currentCostume}>
          You're currently dressed as: <strong>{newCostume}</strong>
        </div>
        <div style={styles.message}>
          Alright, you've got your costume. Wanna change it? Bring me back some cold, hard cash money!
        </div>
        <div style={styles.cost}>
          Cost to change: {costumeCost} GP | Your GP: {userGP}
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>The Costume Shop</h1>
      </div>

      {newCostume && (
        <div style={styles.currentCostume}>
          Current costume: <strong>{newCostume}</strong>
        </div>
      )}

      <div style={styles.message}>
        {newCostume ? (
          <>Want a new costume? Give me {costumeCost > 0 ? `${costumeCost} GP` : 'your best idea'} and I'll hook you up!</>
        ) : (
          <>Well, I see you've scrounged up some cash. So I tell you what. You give me {costumeCost > 0 ? `${costumeCost} GP` : 'nothing (admin perk)'} and I'll give you a costume. Whaddya say?</>
        )}
      </div>

      {error && <div style={styles.error}>{error}</div>}
      {success && <div style={styles.success}>{success}</div>}

      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.inputGroup}>
          <input
            type="text"
            value={costume}
            onChange={(e) => setCostume(e.target.value)}
            placeholder="Enter your costume name..."
            style={styles.input}
            maxLength={40}
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !costume.trim()}
            style={{
              ...styles.button,
              ...(loading || !costume.trim() ? styles.buttonDisabled : {})
            }}
          >
            {loading ? 'Dressing...' : 'Dress Me Up'}
          </button>
        </div>
        <div style={styles.cost}>
          Cost: {costumeCost} GP | Your GP: {userGP}
        </div>
      </form>

      {isAdmin && (
        <div style={styles.adminNote}>
          Note: Since you are an administrator, costumes are free and you can also remove abusive costumes at the{' '}
          <a href="/title/Costume Remover">Costume Remover</a>.
        </div>
      )}
    </div>
  )
}

export default TheCostumeShop

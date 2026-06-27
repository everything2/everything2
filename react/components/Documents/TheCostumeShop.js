import React, { useState, useCallback } from 'react'

/**
 * TheCostumeShop - Halloween costume purchasing interface
 * Styles in CSS: .costume-shop__*
 */
const TheCostumeShop = ({ data, user }) => {
  const shop = data?.costumeShop || {}
  const {
    isHalloween,
    costumeCost,
    currentCostume,
    hasCostume,
    canAfford,
  } = shop
  // Viewer identity reads from the global user prop, not page contentData (#4390)
  const isAdmin = !!user?.admin
  const userGP = user?.gp ?? 0

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
      <div className="costume-shop">
        <div className="costume-shop__message costume-shop__message--closed">
          Sorry, shop's closed. Check back on All Hallows' Eve...
        </div>
      </div>
    )
  }

  if (!canAfford && !hasCostume) {
    return (
      <div className="costume-shop">
        <div className="costume-shop__message">
          Sorry - a costume don't come free. Go start a lemonade stand or something.
        </div>
        <div className="costume-shop__cost">
          Cost: {costumeCost} GP | Your GP: {userGP}
        </div>
      </div>
    )
  }

  if (!canAfford && hasCostume) {
    return (
      <div className="costume-shop">
        <div className="costume-shop__current-costume">
          You're currently dressed as: <strong>{newCostume}</strong>
        </div>
        <div className="costume-shop__message">
          Alright, you've got your costume. Wanna change it? Bring me back some cold, hard cash money!
        </div>
        <div className="costume-shop__cost">
          Cost to change: {costumeCost} GP | Your GP: {userGP}
        </div>
      </div>
    )
  }

  return (
    <div className="costume-shop">

      {newCostume && (
        <div className="costume-shop__current-costume">
          Current costume: <strong>{newCostume}</strong>
        </div>
      )}

      <div className="costume-shop__message">
        {newCostume ? (
          <>Want a new costume? Give me {costumeCost > 0 ? `${costumeCost} GP` : 'your best idea'} and I'll hook you up!</>
        ) : (
          <>Well, I see you've scrounged up some cash. So I tell you what. You give me {costumeCost > 0 ? `${costumeCost} GP` : 'nothing (admin perk)'} and I'll give you a costume. Whaddya say?</>
        )}
      </div>

      {error && <div className="costume-shop__error">{error}</div>}
      {success && <div className="costume-shop__success">{success}</div>}

      <form onSubmit={handleSubmit} className="costume-shop__form">
        <div className="costume-shop__input-group">
          <input
            type="text"
            value={costume}
            onChange={(e) => setCostume(e.target.value)}
            placeholder="Enter your costume name..."
            className="costume-shop__input"
            maxLength={40}
            disabled={loading}
          />
          <button
            type="submit"
            disabled={loading || !costume.trim()}
            className={`costume-shop__button ${loading || !costume.trim() ? 'costume-shop__button--disabled' : ''}`}
          >
            {loading ? 'Dressing...' : 'Dress Me Up'}
          </button>
        </div>
        <div className="costume-shop__cost">
          Cost: {costumeCost} GP | Your GP: {userGP}
        </div>
      </form>

      {isAdmin && (
        <div className="costume-shop__admin-note">
          Note: Since you are an administrator, costumes are free and you can also remove abusive costumes at the{' '}
          <a href="/title/Costume Remover">Costume Remover</a>.
        </div>
      )}
    </div>
  )
}

export default TheCostumeShop

import React, { useState } from 'react'
import ParseLinks from '../ParseLinks'

/**
 * Wheel of Surprise - Gamble 5 GP for random prizes
 *
 * Phase 4a migration from delegation/document.pm
 * Awards: GP, easter eggs, tokens, C!s, or nothing
 */
const WheelOfSurprise = ({ data, user }) => {
  const [result, setResult] = useState(data.result || null)
  const [spinning, setSpinning] = useState(false)
  const [error, setError] = useState(null)

  const handleSpin = async () => {
    setSpinning(true)
    setError(null)

    try {
      const response = await fetch('/api/wheel/spin', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || `HTTP ${response.status}`)
      }

      const resultData = await response.json()
      setResult(resultData.message)

      // Reload page to update GP/stats in sidebar
      // TODO: Eventually move to state management to avoid full reload
      setTimeout(() => {
        window.location.reload()
      }, 3000)
    } catch (err) {
      console.error('Failed to spin wheel:', err)
      setError(err.message)
    } finally {
      setSpinning(false)
    }
  }

  const isGuest = user?.guest
  const isHalloween = data.isHalloween || false
  const spinCost = isHalloween ? 0 : 5

  // Guest users
  if (isGuest) {
    return (
      <div className="wheel-of-surprise">
        <p>You must be logged in to be surprised.</p>
      </div>
    )
  }

  // GP opt-out users
  if (data.hasGPOptout) {
    return (
      <div className="wheel-of-surprise">
        <p>
          Your vow of poverty does not allow you to gamble. You need to{' '}
          <ParseLinks text="[User Settings|opt in to]" /> the GP System in order to spin the wheel.
        </p>
      </div>
    )
  }

  // Insufficient GP
  if (!isHalloween && data.userGP < spinCost) {
    return (
      <div className="wheel-of-surprise">
        <p>
          Sorry, you don't have enough GP to spin the wheel. You need {spinCost} GP, but you only have{' '}
          {data.userGP} GP.
        </p>
      </div>
    )
  }

  return (
    <div className="wheel-of-surprise">
      <h3>
        {isHalloween ? (
          <>
            Welcome, welcome, one and all. Tonight we're offering a Trick or Treat Special - and it's
            free to spin, all night long! Who knows what mysterious wonders will emerge?
          </>
        ) : (
          <>
            Welcome, welcome, one and all. Step right up, put your{' '}
            <ParseLinks text="[5 GP|nickel]" /> in the hat and spin the wonderful Wheel of Surprise! Who
            knows what mysterious wonders will emerge?
          </>
        )}
      </h3>

      <p style={{ fontSize: '11px', color: '#666' }}>
        <small>
          {isHalloween
            ? 'Guarantee void in Transylvania.'
            : 'All rights reserved. Must be 18 to play (19 in Quebec and Alabama). Contest open to legal residents of Earth and overseas territories only. Wash cold, tumble dry low. Guarantee void in Tennessee.'}
        </small>
      </p>

      {result && (
        <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f0f8ff', border: '1px solid #4a90e2', borderRadius: '5px' }}>
          <ParseLinks text={result} />
        </div>
      )}

      {error && (
        <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#fff3cd', border: '1px solid #ffc107', borderRadius: '5px', color: '#856404' }}>
          Error: {error}
        </div>
      )}

      <form onSubmit={(e) => { e.preventDefault(); handleSpin(); }}>
        <button
          type="submit"
          disabled={spinning}
          style={{
            padding: '10px 20px',
            fontSize: '14px',
            fontWeight: 'bold',
            color: '#fff',
            backgroundColor: spinning ? '#ccc' : '#4a90e2',
            border: 'none',
            borderRadius: '5px',
            cursor: spinning ? 'not-allowed' : 'pointer'
          }}
        >
          {spinning ? 'Spinning...' : 'Spin'}
        </button>
      </form>

      <p style={{ marginTop: '15px', fontSize: '12px', color: '#666' }}>
        Current GP: {data.userGP} | Cost per spin: {spinCost} GP
      </p>
    </div>
  )
}

export default WheelOfSurprise

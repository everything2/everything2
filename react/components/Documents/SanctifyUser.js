import React, { useState, useCallback, useEffect } from 'react'
import LinkNode from '../LinkNode'

/**
 * SanctifyUser - GP gifting tool
 * Styles in CSS: .sanctify-user__*
 *
 * Allows users to transfer GP to other users, optionally anonymously.
 */
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
      <div className="sanctify-user">
        <div className="sanctify-user__header">
          <h1 className="sanctify-user__title">Sanctify User</h1>
        </div>
        <div className="sanctify-user__warning-box">
          {isLevelIssue && (
            <p className="sanctify-user__paragraph">
              Who do you think you are? The Pope or something?
            </p>
          )}
          <p className="sanctify-user__paragraph">
            {isLevelIssue ? (
              <>
                Sorry, but you will have to come back when you reach{' '}
                <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display={`Level ${minLevel}`} />.
              </>
            ) : isGpIssue ? (
              <>
                Sorry, but you don't have at least <span className="sanctify-user__highlight">{sanctifyAmount} GP</span> to give away.
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
        <div className="sanctify-user__back-link">
          <p>Return to the <LinkNode type="superdoc" title="E2 Gift Shop" />.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="sanctify-user">
      <div className="sanctify-user__header">
        <h1 className="sanctify-user__title">Sanctify User</h1>
      </div>

      <div className="sanctify-user__info-box">
        <p className="sanctify-user__paragraph">
          This tool lets you give <span className="sanctify-user__highlight">{sanctifyAmount} GP</span> at a time to any user of your choice.
          The GP is transferred from your own account to theirs.
        </p>
        <p className="sanctify-user__paragraph sanctify-user__paragraph--no-margin">
          Please use it for the good of Everything2!
        </p>
      </div>

      <div className="sanctify-user__gp-display">
        You currently have: {gp} GP
      </div>

      <form onSubmit={handleSubmit} className="sanctify-user__form">
        <div className="sanctify-user__form-row">
          <label className="sanctify-user__label">Recipient:</label>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            className="sanctify-user__input"
            placeholder="Username"
            required
            disabled={loading}
          />
        </div>

        <div className="sanctify-user__checkbox-row">
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
          className={`sanctify-user__button ${loading ? 'sanctify-user__button--disabled' : ''}`}
          disabled={loading || !recipient.trim()}
        >
          {loading ? 'Sanctifying...' : 'Sanctify!'}
        </button>
      </form>

      {message && (
        <div className={`sanctify-user__message ${message.type === 'success' ? 'sanctify-user__message--success' : 'sanctify-user__message--error'}`}>
          {message.text}
          {message.type === 'success' && (
            <p className="sanctify-user__message-followup">
              You have <strong>{sanctifyData.gp} GP</strong> left.
              Would you like to sanctify someone else?
            </p>
          )}
        </div>
      )}

      <div className="sanctify-user__back-link">
        <p>Return to the <LinkNode type="superdoc" title="E2 Gift Shop" />.</p>
      </div>
    </div>
  )
}

export default SanctifyUser

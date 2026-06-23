import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * Render a message that may contain [username] bracket notation as React elements.
 * Converts [username] to LinkNode components for direct rendering.
 */
const renderMessageWithLinks = (message) => {
  if (!message) return null

  const parts = []
  let lastIndex = 0
  let key = 0

  const bracketPattern = /\[([^\[\]]+)\]/g
  let match

  while ((match = bracketPattern.exec(message)) !== null) {
    if (match.index > lastIndex) {
      parts.push(message.substring(lastIndex, match.index))
    }
    const username = match[1]
    parts.push(<LinkNode key={`user-${key++}`} title={username} type="user" />)
    lastIndex = match.index + match[0].length
  }

  if (lastIndex < message.length) {
    parts.push(message.substring(lastIndex))
  }

  return parts.length > 0 ? parts : message
}

/**
 * EverythingsMostWanted - Bounty system for filling nodeshells.
 * Styles in CSS: .emw__*
 *
 * Mutations go through the level/sheriff-gated POST /api/bounties endpoints
 * (post / remove / reward / award / yank); the read model is refreshed from
 * GET /api/bounties after each action. Replaces the old server-side form POST +
 * verifyRequest form-CSRF. #4198
 */
const EverythingsMostWanted = ({ data }) => {
  const [state, setState] = useState(data)
  const [message, setMessage] = useState(null)
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)

  const [showModal, setShowModal] = useState(false)
  const [showRewardModal, setShowRewardModal] = useState(false)
  const [showAwardModal, setShowAwardModal] = useState(false)
  const [outlawNode, setOutlawNode] = useState('')
  const [gpReward, setGpReward] = useState('')
  const [comment, setComment] = useState('')
  const [rewardee, setRewardee] = useState('')
  const [awardee, setAwardee] = useState('')
  const [awarded, setAwarded] = useState('')
  const [removee, setRemovee] = useState('')

  const {
    min_level,
    is_sheriff,
    is_admin,
    bounty_limit,
    has_bounty,
    current_bounty,
    gp_optout,
    bounties,
    justice_served,
    can_post
  } = state

  const refresh = async () => {
    try {
      const res = await fetch('/api/bounties', { credentials: 'same-origin' })
      const d = await res.json()
      if (d.success) setState(d)
    } catch (e) {
      /* leave stale state; the message/error already told the user the outcome */
    }
  }

  // POST an action, surface its message/error, refresh the read model.
  const doAction = async (path, body, onDone) => {
    setBusy(true)
    setError(null)
    setMessage(null)
    try {
      const res = await fetch(`/api/bounties${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify(body || {})
      })
      const r = await res.json()
      if (r.success) {
        setMessage(r.message)
        if (onDone) onDone()
        await refresh()
      } else {
        setError(r.error || r.message || 'Request failed')
      }
    } catch (e) {
      setError('Failed to reach the bounty office: ' + e.message)
    } finally {
      setBusy(false)
    }
  }

  const submit = (handler) => (e) => {
    e.preventDefault()
    handler()
  }

  const postBounty = () =>
    doAction('', { outlaw: outlawNode, reward: gpReward, comment }, () => {
      setShowModal(false)
      setOutlawNode('')
      setGpReward('')
      setComment('')
    })

  const removeBounty = () => doAction('/remove', {})

  const rewardBounty = () =>
    doAction('/reward', { winner: rewardee }, () => {
      setShowRewardModal(false)
      setRewardee('')
    })

  const awardBounty = () =>
    doAction('/award', { winner: awardee, prize: awarded }, () => {
      setShowAwardModal(false)
      setAwardee('')
      setAwarded('')
    })

  const yankBounty = () =>
    doAction('/yank', { removee }, () => setRemovee(''))

  return (
    <div className="emw">
      {message && (
        <div className="emw__message">
          <p>{renderMessageWithLinks(message)}</p>
        </div>
      )}
      {error && (
        <div className="emw__error" role="alert">
          <p>{error}</p>
        </div>
      )}

      <div className="emw__intro">
        <p>
          Howdy stranger! Reckon you have the cojones to take down some of the meanest nodes this
          side of the Rio Grande? Below is a list of the most dangerously unfilled nodes ever to
          wander the lawless plains of the nodegel. Track one down, hogtie it, and fill it up with
          good content, and you might end up earning yourself a shiny silver sheriff&apos;s star.
        </p>
        <p>
          Any user can fill a posted node and claim the posted bounty. If you think you have
          captured one of these fugitives, contact the requesting sheriff. If they judge your
          writeup worthy, you will get your reward!
        </p>
        <p>Check back often for new bounties. Happy hunting!</p>
      </div>

      {/* User bounty management section */}
      {can_post && (
        <div className="emw__section">
          <hr className="emw__hr" />

          {has_bounty ? (
            <div>
              <p>
                You have already posted a bounty. Would you like to remove it (either because it has
                been filled by a user, or because you just want to take it down)?
              </p>
              {current_bounty && (
                <p className="emw__current-bounty">
                  Your bounty: <strong><ParseLinks text={current_bounty.outlaw} /></strong> - Reward:{' '}
                  <strong>{current_bounty.reward} GP</strong>
                </p>
              )}
              <div className="emw__button-row">
                {!gp_optout && current_bounty?.reward > 0 && (
                  <button
                    type="button"
                    onClick={() => setShowRewardModal(true)}
                    className="emw__button"
                  >
                    Pay out GP reward
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setShowAwardModal(true)}
                  className="emw__button"
                >
                  Pay out custom reward
                </button>
                <button type="button" onClick={removeBounty} disabled={busy} className="emw__button">
                  Just remove it
                </button>
              </div>
            </div>
          ) : (
            <div>
              <p>
                You are high enough level to place a bounty.{' '}
                <button
                  type="button"
                  onClick={() => setShowModal(true)}
                  className="emw__button"
                >
                  Add a Bounty
                </button>
              </p>
            </div>
          )}
        </div>
      )}

      {/* Bounty creation modal */}
      {showModal && (
        <div className="emw__modal-overlay" onClick={() => setShowModal(false)}>
          <div className="emw__modal" onClick={e => e.stopPropagation()}>
            <h3 className="emw__modal-title">Post a Bounty</h3>
            <form onSubmit={submit(postBounty)}>
              <div className="emw__form-group">
                <label className="emw__label">
                  Outlaw Node (nodeshell to be filled):
                  <input
                    type="text"
                    value={outlawNode}
                    onChange={e => setOutlawNode(e.target.value)}
                    className="emw__input-full"
                    placeholder="Enter nodeshell title"
                    required
                  />
                </label>
              </div>

              <div className="emw__form-group">
                <label className="emw__label">
                  GP Reward (max {bounty_limit} GP, or 0 for non-GP reward):
                  <input
                    type="number"
                    value={gpReward}
                    onChange={e => setGpReward(e.target.value)}
                    className="emw__input-full"
                    min="0"
                    max={bounty_limit}
                    placeholder="0"
                  />
                </label>
              </div>

              <div className="emw__form-group">
                <label className="emw__label">
                  Comment (describe conditions, other rewards, etc.):
                  <textarea
                    value={comment}
                    onChange={e => setComment(e.target.value)}
                    className="emw__textarea"
                    rows={3}
                    placeholder="Optional: describe any conditions or non-GP rewards"
                  />
                </label>
              </div>

              <div className="emw__button-row">
                <button type="submit" disabled={busy} className="emw__button">
                  Post Bounty
                </button>
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="emw__cancel-button"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Reward GP modal */}
      {showRewardModal && (
        <div className="emw__modal-overlay" onClick={() => setShowRewardModal(false)}>
          <div className="emw__modal" onClick={e => e.stopPropagation()}>
            <h3 className="emw__modal-title">Pay Out GP Reward</h3>
            <form onSubmit={submit(rewardBounty)}>
              <div className="emw__form-group">
                <label className="emw__label">
                  Who filled this bounty?
                  <input
                    type="text"
                    value={rewardee}
                    onChange={e => setRewardee(e.target.value)}
                    className="emw__input-full"
                    placeholder="Enter username"
                    required
                  />
                </label>
              </div>

              <div className="emw__button-row">
                <button type="submit" disabled={busy} className="emw__button">
                  Pay {current_bounty?.reward || 0} GP
                </button>
                <button
                  type="button"
                  onClick={() => setShowRewardModal(false)}
                  className="emw__cancel-button"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Award custom prize modal */}
      {showAwardModal && (
        <div className="emw__modal-overlay" onClick={() => setShowAwardModal(false)}>
          <div className="emw__modal" onClick={e => e.stopPropagation()}>
            <h3 className="emw__modal-title">Pay Out Custom Reward</h3>
            <form onSubmit={submit(awardBounty)}>
              <div className="emw__form-group">
                <label className="emw__label">
                  Who filled this bounty?
                  <input
                    type="text"
                    value={awardee}
                    onChange={e => setAwardee(e.target.value)}
                    className="emw__input-full"
                    placeholder="Enter username"
                    required
                  />
                </label>
              </div>

              <div className="emw__form-group">
                <label className="emw__label">
                  What are you awarding them?
                  <input
                    type="text"
                    value={awarded}
                    onChange={e => setAwarded(e.target.value)}
                    className="emw__input-full"
                    placeholder="e.g., a C!, postcard, node audit"
                    required
                  />
                </label>
              </div>

              <p className="emw__note">
                {current_bounty?.reward > 0
                  ? `They will also receive ${current_bounty.reward} GP.`
                  : 'No GP reward will be given.'}
              </p>

              <div className="emw__button-row">
                <button type="submit" disabled={busy} className="emw__button">
                  Award Prize
                </button>
                <button
                  type="button"
                  onClick={() => setShowAwardModal(false)}
                  className="emw__cancel-button"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Sheriff/admin bounty removal section */}
      {(is_sheriff || is_admin) && (
        <div className="emw__section">
          <hr className="emw__hr" />
          {is_admin ? (
            <p>
              Since you are an administrator, you have the authority to delete bounties if
              necessary.
            </p>
          ) : (
            <p>
              Since you are a member of the sheriffs usergroup, you have the authority to delete
              bounties if necessary.
            </p>
          )}
          <form onSubmit={submit(yankBounty)}>
            <label>
              Enter the name of a user whose bounty you need to remove:{' '}
              <input
                type="text"
                value={removee}
                onChange={e => setRemovee(e.target.value)}
                className="emw__input"
              />
            </label>{' '}
            <button type="submit" disabled={busy} className="emw__button">
              Remove Bounty
            </button>
          </form>
        </div>
      )}

      {/* Bounty table */}
      <hr className="emw__hr" />
      <table className="emw__table">
        <thead>
          <tr>
            <th className="emw__th">Requesting Sheriff</th>
            <th className="emw__th">Outlaw Node</th>
            <th className="emw__th">Details of the Crime</th>
            <th className="emw__th">GP Reward (if any)</th>
          </tr>
        </thead>
        <tbody>
          {bounties.length > 0 ? (
            bounties.map((bounty, idx) => (
              <tr key={bounty.number} className={idx % 2 === 1 ? 'emw__row--even' : 'emw__row--odd'}>
                <td className="emw__td">
                  <ParseLinks text={`[${bounty.requester}]`} />
                </td>
                <td className="emw__td">
                  <ParseLinks text={bounty.outlaw} />
                </td>
                <td
                  className="emw__td"
                  dangerouslySetInnerHTML={{
                    __html: renderE2Content(bounty.comment || ' ').html
                  }}
                />
                <td className="emw__td">{bounty.reward}</td>
              </tr>
            ))
          ) : (
            <tr>
              <td colSpan={4} className="emw__td">
                <em>No active bounties at this time.</em>
              </td>
            </tr>
          )}
        </tbody>
      </table>

      {/* Justice served section */}
      {justice_served.length > 0 && (
        <div className="emw__section">
          <hr className="emw__hr" />
          <h3 className="emw__subtitle">Justice Served</h3>
          <ul className="emw__justice-list">
            {justice_served.map((entry, idx) => (
              <li key={idx}><ParseLinks text={entry} /></li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

export default EverythingsMostWanted

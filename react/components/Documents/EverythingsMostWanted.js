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

  // Match [username] pattern (simple bracket syntax for usernames)
  const bracketPattern = /\[([^\[\]]+)\]/g
  let match

  while ((match = bracketPattern.exec(message)) !== null) {
    // Add text before this match
    if (match.index > lastIndex) {
      parts.push(message.substring(lastIndex, match.index))
    }

    // Add LinkNode for the username
    const username = match[1]
    parts.push(<LinkNode key={`user-${key++}`} title={username} type="user" />)

    lastIndex = match.index + match[0].length
  }

  // Add remaining text
  if (lastIndex < message.length) {
    parts.push(message.substring(lastIndex))
  }

  return parts.length > 0 ? parts : message
}

/**
 * EverythingsMostWanted - Bounty system for filling nodeshells.
 * Users can post bounties, sheriffs/admins can manage them.
 */
const EverythingsMostWanted = ({ data }) => {
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
    can_post,
    message,
    csrf_nonce,
    csrf_seed
  } = data

  const nodeId = window.e2?.node_id || ''
  const [showModal, setShowModal] = useState(false)
  const [showRewardModal, setShowRewardModal] = useState(false)
  const [showAwardModal, setShowAwardModal] = useState(false)
  const [outlawNode, setOutlawNode] = useState('')
  const [gpReward, setGpReward] = useState('')
  const [comment, setComment] = useState('')
  const [rewardee, setRewardee] = useState('')
  const [awardee, setAwardee] = useState('')
  const [awarded, setAwarded] = useState('')

  return (
    <div style={styles.container}>
      {message && (
        <div style={styles.message}>
          <p>{renderMessageWithLinks(message)}</p>
        </div>
      )}

      <div style={styles.header}>
        <p style={styles.title}>
          <strong>Welcome to Everything&apos;s Most Wanted</strong>
        </p>
      </div>

      <div style={styles.intro}>
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
        <div style={styles.section}>
          <hr style={styles.hr} />

          {has_bounty ? (
            <div>
              <p>
                You have already posted a bounty. Would you like to remove it (either because it has
                been filled by a user, or because you just want to take it down)?
              </p>
              {current_bounty && (
                <p style={styles.currentBounty}>
                  Your bounty: <strong><ParseLinks text={current_bounty.outlaw} /></strong> - Reward:{' '}
                  <strong>{current_bounty.reward} GP</strong>
                </p>
              )}
              <div style={styles.buttonRow}>
                {!gp_optout && current_bounty?.reward > 0 && (
                  <button
                    type="button"
                    onClick={() => setShowRewardModal(true)}
                    style={styles.button}
                  >
                    Pay out GP reward
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setShowAwardModal(true)}
                  style={styles.button}
                >
                  Pay out custom reward
                </button>
                <form method="POST" style={{ display: 'inline' }}>
                  <input type="hidden" name="node_id" value={nodeId} />
                  <input type="hidden" name="emw_nonce" value={csrf_nonce} />
                  <input type="hidden" name="emw_seed" value={csrf_seed} />
                  <button type="submit" name="Remove" value="1" style={styles.button}>
                    Just remove it
                  </button>
                </form>
              </div>
            </div>
          ) : (
            <div>
              <p>
                You are high enough level to place a bounty.{' '}
                <button
                  type="button"
                  onClick={() => setShowModal(true)}
                  style={styles.button}
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
        <div style={styles.modalOverlay} onClick={() => setShowModal(false)}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Post a Bounty</h3>
            <form method="POST">
              <input type="hidden" name="node_id" value={nodeId} />
              <input type="hidden" name="emw_nonce" value={csrf_nonce} />
              <input type="hidden" name="emw_seed" value={csrf_seed} />
              <input type="hidden" name="Yes" value="1" />

              <div style={styles.formGroup}>
                <label style={styles.label}>
                  Outlaw Node (nodeshell to be filled):
                  <input
                    type="text"
                    name="outlaw"
                    value={outlawNode}
                    onChange={e => setOutlawNode(e.target.value)}
                    style={styles.inputFull}
                    placeholder="Enter nodeshell title"
                    required
                  />
                </label>
              </div>

              <div style={styles.formGroup}>
                <label style={styles.label}>
                  GP Reward (max {bounty_limit} GP, or 0 for non-GP reward):
                  <input
                    type="number"
                    name="bountyreward"
                    value={gpReward}
                    onChange={e => setGpReward(e.target.value)}
                    style={styles.inputFull}
                    min="0"
                    max={bounty_limit}
                    placeholder="0"
                  />
                </label>
              </div>

              <div style={styles.formGroup}>
                <label style={styles.label}>
                  Comment (describe conditions, other rewards, etc.):
                  <textarea
                    name="bountycomment"
                    value={comment}
                    onChange={e => setComment(e.target.value)}
                    style={styles.textarea}
                    rows={3}
                    placeholder="Optional: describe any conditions or non-GP rewards"
                  />
                </label>
              </div>

              <div style={styles.buttonRow}>
                <button type="submit" style={styles.button}>
                  Post Bounty
                </button>
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  style={styles.cancelButton}
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
        <div style={styles.modalOverlay} onClick={() => setShowRewardModal(false)}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Pay Out GP Reward</h3>
            <form method="POST">
              <input type="hidden" name="node_id" value={nodeId} />
              <input type="hidden" name="emw_nonce" value={csrf_nonce} />
              <input type="hidden" name="emw_seed" value={csrf_seed} />
              <input type="hidden" name="Reward" value="1" />

              <div style={styles.formGroup}>
                <label style={styles.label}>
                  Who filled this bounty?
                  <input
                    type="text"
                    name="rewardee"
                    value={rewardee}
                    onChange={e => setRewardee(e.target.value)}
                    style={styles.inputFull}
                    placeholder="Enter username"
                    required
                  />
                </label>
              </div>

              <div style={styles.buttonRow}>
                <button type="submit" style={styles.button}>
                  Pay {current_bounty?.reward || 0} GP
                </button>
                <button
                  type="button"
                  onClick={() => setShowRewardModal(false)}
                  style={styles.cancelButton}
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
        <div style={styles.modalOverlay} onClick={() => setShowAwardModal(false)}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Pay Out Custom Reward</h3>
            <form method="POST">
              <input type="hidden" name="node_id" value={nodeId} />
              <input type="hidden" name="emw_nonce" value={csrf_nonce} />
              <input type="hidden" name="emw_seed" value={csrf_seed} />
              <input type="hidden" name="Award" value="1" />

              <div style={styles.formGroup}>
                <label style={styles.label}>
                  Who filled this bounty?
                  <input
                    type="text"
                    name="awardee"
                    value={awardee}
                    onChange={e => setAwardee(e.target.value)}
                    style={styles.inputFull}
                    placeholder="Enter username"
                    required
                  />
                </label>
              </div>

              <div style={styles.formGroup}>
                <label style={styles.label}>
                  What are you awarding them?
                  <input
                    type="text"
                    name="awarded"
                    value={awarded}
                    onChange={e => setAwarded(e.target.value)}
                    style={styles.inputFull}
                    placeholder="e.g., a C!, postcard, node audit"
                    required
                  />
                </label>
              </div>

              <p style={styles.note}>
                {current_bounty?.reward > 0
                  ? `They will also receive ${current_bounty.reward} GP.`
                  : 'No GP reward will be given.'}
              </p>

              <div style={styles.buttonRow}>
                <button type="submit" style={styles.button}>
                  Award Prize
                </button>
                <button
                  type="button"
                  onClick={() => setShowAwardModal(false)}
                  style={styles.cancelButton}
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
        <div style={styles.section}>
          <hr style={styles.hr} />
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
          <form method="POST">
            <input type="hidden" name="node_id" value={nodeId} />
            <input type="hidden" name="emw_nonce" value={csrf_nonce} />
            <input type="hidden" name="emw_seed" value={csrf_seed} />
            <label>
              Enter the name of a user whose bounty you need to remove:{' '}
              <input type="text" name="removee" style={styles.input} />
            </label>{' '}
            <button type="submit" name="yankify" value="1" style={styles.button}>
              Remove Bounty
            </button>
          </form>
        </div>
      )}

      {/* Bounty table */}
      <hr style={styles.hr} />
      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.th}>Requesting Sheriff</th>
            <th style={styles.th}>Outlaw Node</th>
            <th style={styles.th}>Details of the Crime</th>
            <th style={styles.th}>GP Reward (if any)</th>
          </tr>
        </thead>
        <tbody>
          {bounties.length > 0 ? (
            bounties.map((bounty, idx) => (
              <tr key={bounty.number} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <ParseLinks text={`[${bounty.requester}]`} />
                </td>
                <td style={styles.td}>
                  <ParseLinks text={bounty.outlaw} />
                </td>
                <td
                  style={styles.td}
                  dangerouslySetInnerHTML={{
                    __html: renderE2Content(bounty.comment || '\u00A0').html
                  }}
                />
                <td style={styles.td}>{bounty.reward}</td>
              </tr>
            ))
          ) : (
            <tr>
              <td colSpan={4} style={styles.td}>
                <em>No active bounties at this time.</em>
              </td>
            </tr>
          )}
        </tbody>
      </table>

      {/* Justice served section */}
      {justice_served.length > 0 && (
        <div style={styles.section}>
          <hr style={styles.hr} />
          <h3 style={styles.subtitle}>Justice Served</h3>
          <ul style={styles.justiceList}>
            {justice_served.map((entry, idx) => (
              <li key={idx}><ParseLinks text={entry} /></li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  header: {
    textAlign: 'center',
    marginBottom: '15px'
  },
  title: {
    fontSize: '16px',
    margin: '0'
  },
  intro: {
    marginBottom: '20px'
  },
  section: {
    marginTop: '15px',
    marginBottom: '15px'
  },
  hr: {
    width: '50%',
    border: 'none',
    borderTop: '1px solid #d3d3d3',
    margin: '20px auto'
  },
  currentBounty: {
    backgroundColor: '#f8f9f9',
    padding: '10px',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px',
    textAlign: 'left',
    border: '1px solid silver'
  },
  td: {
    padding: '8px',
    border: '1px solid silver'
  },
  oddRow: {
    backgroundColor: '#ffffff'
  },
  evenRow: {
    backgroundColor: '#f8f9f9'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '200px'
  },
  button: {
    padding: '6px 15px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px',
    marginRight: '5px'
  },
  subtitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    margin: '10px 0',
    color: '#38495e'
  },
  justiceList: {
    margin: '10px 0',
    paddingLeft: '20px'
  },
  modalOverlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000
  },
  modal: {
    backgroundColor: '#ffffff',
    padding: '20px',
    borderRadius: '8px',
    width: '90%',
    maxWidth: '450px',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)'
  },
  modalTitle: {
    margin: '0 0 15px 0',
    fontSize: '16px',
    color: '#38495e'
  },
  formGroup: {
    marginBottom: '15px'
  },
  label: {
    display: 'block',
    fontSize: '13px',
    color: '#111'
  },
  inputFull: {
    display: 'block',
    width: '100%',
    padding: '8px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    marginTop: '5px',
    boxSizing: 'border-box'
  },
  textarea: {
    display: 'block',
    width: '100%',
    padding: '8px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    marginTop: '5px',
    boxSizing: 'border-box',
    resize: 'vertical'
  },
  buttonRow: {
    display: 'flex',
    gap: '10px',
    marginTop: '20px'
  },
  cancelButton: {
    padding: '6px 15px',
    backgroundColor: '#d3d3d3',
    color: '#111',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  message: {
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '4px',
    padding: '10px 15px',
    marginBottom: '15px',
    color: '#155724'
  },
  note: {
    fontSize: '12px',
    color: '#507898',
    fontStyle: 'italic',
    marginBottom: '10px'
  }
}

export default EverythingsMostWanted

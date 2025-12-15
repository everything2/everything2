import React, { useState } from 'react'
import { FaCaretUp, FaCaretDown, FaEnvelope } from 'react-icons/fa'
import ParseLinks from './ParseLinks'
import LinkNode from './LinkNode'
import AdminModal from './AdminModal'
import MessageModal from './MessageModal'
import ConfirmModal from './ConfirmModal'
import { renderE2Content } from './Editor/E2HtmlSanitizer'

/**
 * WriteupDisplay - Renders a full writeup with E2 HTML sanitization
 *
 * Uses renderE2Content() which:
 * - Sanitizes HTML to E2-approved tags/attributes
 * - Parses E2 [link] syntax
 * - Returns safe HTML string
 *
 * Structure matches legacy htmlcode 'show content' + 'displayWriteupInfo':
 * - .item wrapper with .contentheader (table with wu_header row)
 * - .content for doctext
 * - .contentfooter (table with wu_footer row) for voting/C!s
 *
 * Usage:
 *   <WriteupDisplay writeup={writeupData} user={userData} />
 */
const WriteupDisplay = ({ writeup, user, showVoting = true, showMetadata = true }) => {
  if (!writeup) return null

  const {
    node_id,
    title,
    author,
    parent,
    doctext,
    writeuptype,
    createtime
  } = writeup

  // State for reputation/votes (can be updated without page reload)
  const [voteState, setVoteState] = useState({
    reputation: writeup.reputation,
    upvotes: writeup.upvotes,
    downvotes: writeup.downvotes,
    userVote: writeup.vote || null
  })

  // State for C!s
  const [coolState, setCoolState] = useState({
    cools: writeup.cools || [],
    hasCooled: writeup.cools && writeup.cools.some(c => c.node_id === user?.node_id)
  })

  // State for admin modal
  const [adminModalOpen, setAdminModalOpen] = useState(false)

  // State for message modal
  const [messageModalOpen, setMessageModalOpen] = useState(false)

  // State for vote/cool confirmation modals
  const [pendingVote, setPendingVote] = useState(null) // { weight: 1 or -1 }
  const [pendingCool, setPendingCool] = useState(false)

  // Render doctext with E2 HTML sanitization and link parsing
  const renderDoctext = (text) => {
    if (!text) return null

    // Use E2HtmlSanitizer to sanitize HTML and parse E2 links
    const { html } = renderE2Content(text)

    // Return raw HTML - outer .content div provides styling
    return <div dangerouslySetInnerHTML={{ __html: html }} />
  }

  const isGuest = !user || user.is_guest
  // Use == for comparison since node_id may be string or number
  const isAuthor = user && author && String(user.node_id) === String(author.node_id)
  const isEditor = user?.is_editor
  const canVote = !isGuest && !isAuthor
  // Use Boolean() to avoid rendering "0" when can_cool is Perl's numeric 0
  const canCool = Boolean(user && user.can_cool && !isAuthor && !isGuest)
  const coolCount = coolState.cools?.length || 0
  // Show admin tools for editors or the writeup author
  const showAdminTools = isEditor || isAuthor
  // Can message author if logged in and not messaging yourself
  const canMessage = !isGuest && !isAuthor && author

  // Format date like legacy htmlcode parsetimestamp
  const formatDate = (timestamp) => {
    if (!timestamp) return null
    // Handle both ISO strings and epoch seconds
    const date = typeof timestamp === 'string' ? new Date(timestamp) : new Date(timestamp * 1000)
    if (isNaN(date.getTime())) return null
    return date.toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric'
    })
  }

  // Format time since last seen (matches legacy htmlcode timesince)
  const formatTimeSince = (timestamp) => {
    if (!timestamp) return null
    const date = typeof timestamp === 'string' ? new Date(timestamp) : new Date(timestamp * 1000)
    if (isNaN(date.getTime())) return null

    const now = new Date()
    const seconds = Math.floor((now - date) / 1000)

    if (seconds < 60) return 'moments ago'
    if (seconds < 3600) {
      const mins = Math.floor(seconds / 60)
      return `${mins} minute${mins === 1 ? '' : 's'} ago`
    }
    if (seconds < 86400) {
      const hours = Math.floor(seconds / 3600)
      return `${hours} hour${hours === 1 ? '' : 's'} ago`
    }
    if (seconds < 604800) {
      const days = Math.floor(seconds / 86400)
      return `${days} day${days === 1 ? '' : 's'} ago`
    }
    if (seconds < 2592000) {
      const weeks = Math.floor(seconds / 604800)
      return `${weeks} week${weeks === 1 ? '' : 's'} ago`
    }
    if (seconds < 31536000) {
      const months = Math.floor(seconds / 2592000)
      return `${months} month${months === 1 ? '' : 's'} ago`
    }
    const years = Math.floor(seconds / 31536000)
    return `${years} year${years === 1 ? '' : 's'} ago`
  }

  // Determine if we should show author's last seen time
  // Conditions: not a bot, user hasn't disabled it, and author allows it (or viewer is editor)
  const shouldShowAuthorSince = () => {
    if (!author?.lasttime) return false
    if (author.is_bot) return false
    if (user?.info_authorsince_off) return false
    if (author.hidelastseen && !isEditor) return false
    if (isGuest) return false
    return true
  }

  return (
    // Use .item class for consistent styling with legacy CSS
    <div className="item writeup" id={`writeup_${node_id}`}>
      {/* Writeup header - matches legacy 'show content' with displayWriteupInfo */}
      {/* Structure: .contentinfo.contentheader > table > tr.wu_header > td cells */}
      <div className="contentinfo contentheader">
        <table border="0" cellPadding="0" cellSpacing="0" width="100%">
          <tbody>
            <tr className="wu_header">
              {/* Type: (writeuptype) linking to this writeup */}
              <td className="wu_type">
                <span className="type">
                  (<LinkNode id={node_id} display={writeuptype || 'writeup'} />)
                </span>
              </td>
              {/* Author with anchor for hash links */}
              <td className="wu_author">
                by <a name={author?.title}></a>
                <strong>
                  <LinkNode type="user" title={author?.title} className="author" />
                </strong>
                {shouldShowAuthorSince() && (
                  <small style={{ marginLeft: '4px', color: '#888' }}>
                    ({formatTimeSince(author.lasttime)})
                  </small>
                )}
              </td>
              {/* Creation date */}
              <td style={{ textAlign: 'right' }} className="wu_dtcreate">
                <small className="date" title={formatDate(createtime)}>
                  {formatDate(createtime)}
                </small>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      {/* Writeup content - uses .content class for legacy CSS compatibility */}
      <div className="content">
        {renderDoctext(doctext)}
      </div>

      {/* Writeup footer with voting/C!s - matches legacy displayWriteupInfo footer */}
      {/* Structure: .contentinfo.contentfooter > table > tr.wu_footer > td cells */}
      {showMetadata && (
        <div className="contentinfo contentfooter">
          <table border="0" cellPadding="0" cellSpacing="0" width="100%">
            <tbody>
              <tr className="wu_footer">
                {/* Tools cell - admin gear and message icon on left */}
                {(showAdminTools || canMessage) && (
                  <td style={{ textAlign: 'left' }} className="wu_tools">
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '2px' }}>
                      {showAdminTools && (
                        <button
                          onClick={() => setAdminModalOpen(true)}
                          title="Admin tools"
                          className="admin-gear"
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            fontSize: '16px',
                            color: '#507898',
                            padding: '2px 4px',
                            display: 'inline-flex',
                            alignItems: 'center',
                            justifyContent: 'center'
                          }}
                        >
                          &#9881;
                        </button>
                      )}
                      {canMessage && (
                        <button
                          onClick={() => setMessageModalOpen(true)}
                          title={`Message ${author.title}`}
                          className="message-icon"
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            fontSize: '14px',
                            color: '#507898',
                            padding: '2px 4px',
                            display: 'inline-flex',
                            alignItems: 'center',
                            justifyContent: 'center'
                          }}
                        >
                          <FaEnvelope />
                        </button>
                      )}
                    </span>
                  </td>
                )}
                {/* Voting controls - modern icon buttons */}
                {showVoting && canVote && (
                  <td className="wu_vote">
                    <span className="vote_buttons">
                      <button
                        onClick={() => {
                          if (user?.votesafety) {
                            setPendingVote({ weight: 1 })
                          } else {
                            handleVote(node_id, 1, setVoteState)
                          }
                        }}
                        disabled={voteState.userVote !== null}
                        title="Upvote"
                        style={{
                          background: 'none',
                          border: 'none',
                          cursor: voteState.userVote !== null ? 'default' : 'pointer',
                          padding: '0 2px',
                          color: voteState.userVote === 1 ? '#4a4' : '#507898',
                          opacity: voteState.userVote !== null && voteState.userVote !== 1 ? 0.4 : 1,
                          fontSize: '20px',
                          verticalAlign: 'middle'
                        }}
                      >
                        <FaCaretUp />
                      </button>
                      <button
                        onClick={() => {
                          if (user?.votesafety) {
                            setPendingVote({ weight: -1 })
                          } else {
                            handleVote(node_id, -1, setVoteState)
                          }
                        }}
                        disabled={voteState.userVote !== null}
                        title="Downvote"
                        style={{
                          background: 'none',
                          border: 'none',
                          cursor: voteState.userVote !== null ? 'default' : 'pointer',
                          padding: '0 2px',
                          color: voteState.userVote === -1 ? '#a44' : '#507898',
                          opacity: voteState.userVote !== null && voteState.userVote !== -1 ? 0.4 : 1,
                          fontSize: '20px',
                          verticalAlign: 'middle'
                        }}
                      >
                        <FaCaretDown />
                      </button>
                    </span>
                  </td>
                )}

                {/* C! display and button - matches legacy writeupcools htmlcode */}
                <td className="wu_cfull">
                  {/* Show C! count with coolers if any exist */}
                  {Boolean(coolCount > 0) && (
                    <span id={`cools${node_id}`}>
                      {coolCount} <b>C!</b>{coolCount === 1 ? '' : 's'}
                      {' '}
                      {coolState.cools.map((cool, index) => (
                        <span key={cool.node_id}>
                          {index > 0 && ', '}
                          <LinkNode type="user" title={cool.title} />
                        </span>
                      ))}
                    </span>
                  )}
                  {/* C? button for eligible users who haven't cooled yet */}
                  {canCool && !coolState.hasCooled && (
                    <>
                      {Boolean(coolCount > 0) && ' · '}
                      <b>
                        <a
                          href="#"
                          className="action"
                          title={`C! ${author?.title || 'this'}'s writeup`}
                          onClick={(e) => {
                            e.preventDefault()
                            if (user?.coolsafety) {
                              setPendingCool(true)
                            } else {
                              handleCool(node_id, user, setCoolState)
                            }
                          }}
                        >
                          C?
                        </a>
                      </b>
                    </>
                  )}
                </td>

                {/* Reputation display */}
                {voteState.reputation !== undefined && (
                  <td style={{ textAlign: 'right' }} className="wu_rep">
                    <small>
                      Rep: {voteState.reputation > 0 && '+'}{voteState.reputation}
                    </small>
                  </td>
                )}
              </tr>
            </tbody>
          </table>
        </div>
      )}

      {/* Admin modal */}
      {showAdminTools && (
        <AdminModal
          writeup={writeup}
          user={user}
          isOpen={adminModalOpen}
          onClose={() => setAdminModalOpen(false)}
        />
      )}

      {/* Message modal for messaging the author */}
      {canMessage && (
        <MessageModal
          isOpen={messageModalOpen}
          onClose={() => setMessageModalOpen(false)}
          replyTo={{ author_user: { title: author.title, type: 'user' } }}
          onSend={async (recipient, message) => {
            const response = await fetch('/api/messages', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ recipient, message })
            })
            const data = await response.json()
            if (!data.success) {
              throw new Error(data.error || 'Failed to send message')
            }
            return data
          }}
          currentUser={user}
        />
      )}

      {/* Vote confirmation modal */}
      <ConfirmModal
        isOpen={pendingVote !== null}
        onClose={() => setPendingVote(null)}
        onConfirm={() => {
          handleVote(node_id, pendingVote.weight, setVoteState)
          setPendingVote(null)
        }}
        title={pendingVote?.weight === 1 ? 'Confirm Upvote' : 'Confirm Downvote'}
        message={`Are you sure you want to ${pendingVote?.weight === 1 ? 'upvote' : 'downvote'} this writeup by ${author?.title || 'this author'}?`}
        confirmText={pendingVote?.weight === 1 ? 'Upvote' : 'Downvote'}
        confirmColor={pendingVote?.weight === 1 ? '#4a4' : '#a44'}
      />

      {/* Cool confirmation modal */}
      <ConfirmModal
        isOpen={pendingCool}
        onClose={() => setPendingCool(false)}
        onConfirm={() => {
          handleCool(node_id, user, setCoolState)
          setPendingCool(false)
        }}
        title="Confirm C!"
        message={`Are you sure you want to C! this writeup by ${author?.title || 'this author'}? This action cannot be undone.`}
        confirmText="C!"
        confirmColor="#667eea"
      />
    </div>
  )
}

// Vote handling function - updates state without page reload
const handleVote = async (writeupId, weight, setVoteState) => {
  try {
    const response = await fetch('/api/vote', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ writeup_id: writeupId, weight })
    })

    const data = await response.json()

    if (!data.success) {
      throw new Error(data.error || 'Vote failed')
    }

    // Update local state with new vote
    setVoteState(prev => ({
      ...prev,
      userVote: weight,
      reputation: prev.reputation + weight,
      upvotes: weight === 1 ? prev.upvotes + 1 : prev.upvotes,
      downvotes: weight === -1 ? prev.downvotes + 1 : prev.downvotes
    }))
  } catch (error) {
    console.error('Error voting:', error)
    alert(`Failed to cast vote: ${error.message}`)
  }
}

// C! (cool) handling function
const handleCool = async (writeupId, user, setCoolState) => {
  try {
    const response = await fetch('/api/cool', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ writeup_id: writeupId })
    })

    const data = await response.json()

    if (!data.success) {
      throw new Error(data.error || 'Failed to award C!')
    }

    // Update local state to show the C! was awarded
    setCoolState(prev => ({
      cools: [...prev.cools, { node_id: user.node_id, title: user.title }],
      hasCooled: true
    }))

    // Optionally show success message
    // Could use a toast notification instead of alert
  } catch (error) {
    console.error('Error awarding C!:', error)
    alert(`Failed to award C!: ${error.message}`)
  }
}

export default WriteupDisplay

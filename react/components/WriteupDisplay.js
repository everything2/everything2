import React from 'react'
import ParseLinks from './ParseLinks'
import LinkNode from './LinkNode'
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
  const [voteState, setVoteState] = React.useState({
    reputation: writeup.reputation,
    upvotes: writeup.upvotes,
    downvotes: writeup.downvotes,
    userVote: writeup.vote || null
  })

  // State for C!s
  const [coolState, setCoolState] = React.useState({
    cools: writeup.cools || [],
    hasCooled: writeup.cools && writeup.cools.some(c => c.node_id === user?.node_id)
  })

  // Render doctext with E2 HTML sanitization and link parsing
  const renderDoctext = (text) => {
    if (!text) return null

    // Use E2HtmlSanitizer to sanitize HTML and parse E2 links
    const { html } = renderE2Content(text)

    // Return raw HTML - outer .content div provides styling
    return <div dangerouslySetInnerHTML={{ __html: html }} />
  }

  const isGuest = !user || user.is_guest
  const isAuthor = user && author && user.node_id === author.node_id
  const canVote = !isGuest && !isAuthor
  // Use Boolean() to avoid rendering "0" when can_cool is Perl's numeric 0
  const canCool = Boolean(user && user.can_cool && !isAuthor && !isGuest)
  const coolCount = coolState.cools?.length || 0

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
                  (<LinkNode nodeId={node_id} title={writeuptype || 'writeup'} />)
                </span>
              </td>
              {/* Author with anchor for hash links */}
              <td className="wu_author">
                by <a name={author?.title}></a>
                <strong>
                  <LinkNode type="user" title={author?.title} className="author" />
                </strong>
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
                {/* Voting controls - matches legacy voteit htmlcode */}
                {showVoting && canVote && (
                  <td className="wu_vote">
                    <small>
                      <span className="vote_buttons">
                        <input
                          type="radio"
                          name={`vote_${node_id}`}
                          value="1"
                          id={`vote_${node_id}_up`}
                          checked={voteState.userVote === 1}
                          disabled={voteState.userVote !== null}
                          onChange={() => handleVote(node_id, 1, setVoteState)}
                        />
                        <label htmlFor={`vote_${node_id}_up`}>+</label>
                        <input
                          type="radio"
                          name={`vote_${node_id}`}
                          value="-1"
                          id={`vote_${node_id}_down`}
                          checked={voteState.userVote === -1}
                          disabled={voteState.userVote !== null}
                          onChange={() => handleVote(node_id, -1, setVoteState)}
                        />
                        <label htmlFor={`vote_${node_id}_down`}>-</label>
                      </span>
                    </small>
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
                            handleCool(node_id, user, setCoolState)
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

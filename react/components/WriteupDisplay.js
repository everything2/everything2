import React, { useState, useRef, useEffect } from 'react'
import { FaCaretUp, FaCaretDown, FaEnvelope, FaStar, FaBookmark, FaFacebookSquare, FaTwitterSquare, FaRedditSquare } from 'react-icons/fa'
import ParseLinks from './ParseLinks'
import LinkNode from './LinkNode'
import AdminModal from './AdminModal'
import MessageModal from './MessageModal'
import ConfirmModal from './ConfirmModal'
import { renderE2Content } from './Editor/E2HtmlSanitizer'

/**
 * CoolTooltip - Shows who C!ed a writeup on hover or click
 * Displays immediately on hover (no browser delay) and can be clicked to toggle
 * Click to lock open and show full list when there are many C!s
 */
const CoolTooltip = ({ cools, coolCount, nodeId }) => {
  const [showTooltip, setShowTooltip] = useState(false)
  const [isClickLocked, setIsClickLocked] = useState(false)
  const [showAll, setShowAll] = useState(false)
  const tooltipRef = useRef(null)
  const triggerRef = useRef(null)

  // Close tooltip when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (isClickLocked && tooltipRef.current && !tooltipRef.current.contains(event.target) &&
          triggerRef.current && !triggerRef.current.contains(event.target)) {
        setShowTooltip(false)
        setIsClickLocked(false)
        setShowAll(false)
      }
    }

    if (isClickLocked) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isClickLocked])

  const handleClick = (e) => {
    e.preventDefault()
    if (isClickLocked) {
      // Already locked open - close it
      setShowTooltip(false)
      setIsClickLocked(false)
      setShowAll(false)
    } else {
      // Lock it open
      setShowTooltip(true)
      setIsClickLocked(true)
    }
  }

  const handleMouseEnter = () => {
    if (!isClickLocked) {
      setShowTooltip(true)
    }
  }

  const handleMouseLeave = () => {
    if (!isClickLocked) {
      setShowTooltip(false)
      setShowAll(false)
    }
  }

  const handleShowAll = (e) => {
    e.preventDefault()
    e.stopPropagation()
    setShowAll(true)
  }

  // Determine how many users to show
  const displayLimit = showAll ? cools.length : 5
  const hasMore = cools.length > 5

  return (
    <span
      ref={triggerRef}
      id={`cools${nodeId}`}
      style={{
        cursor: 'pointer',
        borderBottom: '1px dotted currentColor',
        position: 'relative',
        display: 'inline-block'
      }}
      onClick={handleClick}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {coolCount} <b>C!</b>{coolCount === 1 ? '' : 's'}

      {/* Tooltip popup - uses Kernel Blue theme colors */}
      {showTooltip && cools && cools.length > 0 && (
        <span
          ref={tooltipRef}
          onClick={(e) => e.stopPropagation()}
          style={{
            position: 'absolute',
            bottom: '100%',
            left: '50%',
            transform: 'translateX(-50%)',
            marginBottom: '6px',
            backgroundColor: '#f8f9fa',
            color: '#333',
            padding: '8px 12px',
            borderRadius: '4px',
            fontSize: '12px',
            lineHeight: '1.4',
            zIndex: 1000,
            boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
            border: '1px solid #507898',
            minWidth: '120px',
            maxWidth: showAll ? '400px' : '300px',
            width: 'max-content',
            textAlign: 'left'
          }}
        >
          {/* Arrow pointing down */}
          <span
            style={{
              position: 'absolute',
              top: '100%',
              left: '50%',
              transform: 'translateX(-50%)',
              borderLeft: '6px solid transparent',
              borderRight: '6px solid transparent',
              borderTop: '6px solid #507898'
            }}
          />
          {/* Show users up to displayLimit */}
          {cools.slice(0, displayLimit).map((c, i) => (
            <span key={c.node_id || i}>
              {i > 0 && ', '}
              <LinkNode type="user" title={c.title} style={{ color: '#507898' }} />
            </span>
          ))}
          {/* Show "and X others" or "show all" link */}
          {hasMore && !showAll && (
            <span>
              {' '}
              <a
                href="#"
                onClick={handleShowAll}
                style={{
                  color: '#507898',
                  fontStyle: 'italic',
                  textDecoration: 'underline'
                }}
              >
                and {cools.length - 5} other{cools.length - 5 === 1 ? '' : 's'}...
              </a>
            </span>
          )}
        </span>
      )}
    </span>
  )
}

/**
 * DraftStatusBadge - Shows the publication status with appropriate styling
 * Used when displaying draft content via WriteupDisplay
 */
const DraftStatusBadge = ({ status }) => {
  const statusStyles = {
    private: { backgroundColor: '#6c757d', color: '#fff' },
    findable: { backgroundColor: '#17a2b8', color: '#fff' },
    review: { backgroundColor: '#ffc107', color: '#212529' },
    removed: { backgroundColor: '#dc3545', color: '#fff' },
    unknown: { backgroundColor: '#6c757d', color: '#fff' }
  }

  const style = statusStyles[status] || statusStyles.unknown

  return (
    <span
      style={{
        ...style,
        padding: '2px 8px',
        borderRadius: '4px',
        fontSize: '12px',
        fontWeight: 'bold',
        textTransform: 'uppercase',
        marginLeft: '4px'
      }}
    >
      {status}
    </span>
  )
}

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
 * Props:
 *   writeup - writeup or draft data object
 *   user - current user object
 *   showVoting - whether to show voting controls (default true, should be false for drafts)
 *   showMetadata - whether to show footer with C!s/rep (default true)
 *   onEdit - callback for edit action
 *   isDraft - if true, display as draft with status badge instead of writeuptype
 *   publicationStatus - draft publication status (private, findable, review, removed)
 *
 * Usage:
 *   <WriteupDisplay writeup={writeupData} user={userData} />
 *   <WriteupDisplay writeup={draftData} user={userData} isDraft publicationStatus="private" />
 */
const WriteupDisplay = ({ writeup, user, showVoting = true, showMetadata = true, onEdit, isDraft = false, publicationStatus }) => {
  if (!writeup) return null

  const {
    node_id,
    title,
    author,
    parent,
    doctext,
    writeuptype,
    createtime,
    publishtime
  } = writeup

  // Use publishtime if available, otherwise fall back to createtime (for legacy writeups)
  const displayDate = publishtime || createtime

  // State for reputation/votes (can be updated without page reload)
  const [voteState, setVoteState] = useState({
    reputation: writeup.reputation || 0,
    upvotes: writeup.upvotes || 0,
    downvotes: writeup.downvotes || 0,
    userVote: writeup.vote || null
  })

  // State for C!s
  const [coolState, setCoolState] = useState({
    cools: writeup.cools || [],
    hasCooled: writeup.cools && writeup.cools.some(c => String(c.node_id) === String(user?.node_id))
  })

  // State for admin modal
  const [adminModalOpen, setAdminModalOpen] = useState(false)

  // State for writeup metadata that can change (insured status, etc.)
  const [writeupState, setWriteupState] = useState({
    insured: writeup.insured || false,
    insured_by: writeup.insured_by || null,
    notnew: writeup.notnew || false,
    edcooled: writeup.edcooled || false,
    bookmarked: writeup.bookmarked || false
  })

  // State for message modal
  const [messageModalOpen, setMessageModalOpen] = useState(false)

  // State for vote/cool confirmation modals
  const [pendingVote, setPendingVote] = useState(null) // { weight: 1 or -1 }
  const [pendingCool, setPendingCool] = useState(false)

  // State for error messages (vote/cool failures)
  const [errorMessage, setErrorMessage] = useState(null)

  // Get sanitized HTML for doctext (used in dangerouslySetInnerHTML)
  const getSanitizedHtml = (text) => {
    if (!text) return ''
    // Use E2HtmlSanitizer to sanitize HTML and parse E2 links
    const { html } = renderE2Content(text)
    return html
  }

  const isGuest = !user || user.guest || user.is_guest
  // Use String() for comparison since node_id may be string or number
  const isAuthor = !!(user && author && String(user.node_id) === String(author.node_id))
  // Use !! to ensure boolean (not 0) since user.editor/is_editor may be 0
  const isEditor = !!(user?.editor || user?.is_editor)
  const canVote = !isGuest && !isAuthor
  // Check coolsleft directly - user needs to have cools remaining and not be guest/author
  const canCool = !isGuest && !isAuthor && (user?.coolsleft || 0) > 0
  const coolCount = coolState.cools?.length || 0
  // Show admin tools for editors or the writeup author (for "Return to drafts")
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

  // Generate accessible label for the article
  const articleLabel = isDraft
    ? `Draft: ${title}`
    : `${title} by ${author?.title || 'unknown'}`

  return (
    <>
      {/* Use <article> element for semantic HTML (Chrome reading mode) with .item class for styling */}
      {/* Note: Modals are outside <article> so they don't appear in reading mode */}
      {/* aria-label provides accessible name for screen readers and reading mode */}
      {/* itemscope/itemtype provide Schema.org Article microdata for reading mode detection */}
      <article className="item writeup" id={`writeup_${node_id}`} aria-label={articleLabel} itemScope itemType="https://schema.org/Article">
        {/* Writeup header - matches legacy 'show content' with displayWriteupInfo */}
        {/* Structure: .contentinfo.contentheader > table > tr.wu_header > td cells */}
        {/* data-reader-ignore on header since it's navigation/metadata, not content */}
        <header className="contentinfo contentheader" data-reader-ignore="true">
        <table border="0" cellPadding="0" cellSpacing="0" width="100%">
          <tbody>
            <tr className="wu_header">
              {/* Type: (writeuptype) linking to this writeup, or (draft) with status badge */}
              <td className="wu_type">
                <span className="type">
                  {isDraft ? (
                    <>
                      (<span style={{ fontStyle: 'inherit' }}>draft</span>)
                      <DraftStatusBadge status={publicationStatus || 'unknown'} />
                    </>
                  ) : (
                    <>(<LinkNode id={node_id} display={writeuptype || 'writeup'} />)</>
                  )}
                </span>
              </td>
              {/* Author with anchor for hash links */}
              <td className="wu_author">
                by <a name={author?.title}></a>
                <strong>
                  {author ? (
                    <LinkNode type="user" title={author.title} className="author" />
                  ) : (
                    <span className="author">(no owner)</span>
                  )}
                </strong>
                {shouldShowAuthorSince() && (
                  <small style={{ marginLeft: '4px', color: '#888' }}>
                    ({formatTimeSince(author.lasttime)})
                  </small>
                )}
              </td>
              {/* Publication/creation date */}
              <td style={{ textAlign: 'right' }} className="wu_dtcreate">
                <small className="date" title={formatDate(displayDate)}>
                  {formatDate(displayDate)}
                </small>
              </td>
            </tr>
          </tbody>
        </table>
      </header>



      {/* Writeup content - uses .content class for legacy CSS compatibility */}
      {/* itemProp="articleBody" helps Chrome reading mode identify this as main content */}
      {/* dangerouslySetInnerHTML directly on this div avoids extra wrapper that confuses reading mode */}
      <div className="content" itemProp="articleBody" dangerouslySetInnerHTML={{ __html: getSanitizedHtml(doctext) }} />

      {/* Writeup footer with voting/C!s - matches legacy displayWriteupInfo footer */}
      {/* Using <footer> element so reading mode parsers exclude it from article content */}
      {/* Structure: .contentinfo.contentfooter > table > tr.wu_footer > td cells */}
      {showMetadata && (
        <footer className="contentinfo contentfooter" data-reader-ignore="true">
          <table border="0" cellPadding="0" cellSpacing="0" width="100%">
            <tbody>
              <tr className="wu_footer">
                {/* Draft message - show instead of tools/voting/C!s for drafts */}
                {isDraft && (
                  <td style={{ textAlign: 'left' }} className="wu_tools">
                    <small style={{ color: '#888' }}>
                      This is an unpublished draft. Only you and any collaborators can see it.
                    </small>
                  </td>
                )}
                {/* Tools cell - admin gear and message icon on left (not for drafts) */}
                {!isDraft && (showAdminTools || canMessage) && (
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
                {/* Voting controls - modern icon buttons (not for drafts) */}
                {!isDraft && showVoting && canVote && (
                  <td className="wu_vote">
                    <span className="vote_buttons">
                      <button
                        onClick={() => handleVote(node_id, 1, setVoteState, setErrorMessage)}
                        disabled={voteState.userVote === 1}
                        title="Upvote"
                        style={{
                          background: 'none',
                          border: 'none',
                          cursor: voteState.userVote === 1 ? 'default' : 'pointer',
                          padding: '0 2px',
                          color: voteState.userVote === 1 ? '#4a4' : '#507898',
                          opacity: voteState.userVote === 1 ? 1 : (voteState.userVote === -1 ? 0.4 : 1),
                          fontSize: '20px',
                          verticalAlign: 'middle'
                        }}
                      >
                        <FaCaretUp />
                      </button>
                      <button
                        onClick={() => handleVote(node_id, -1, setVoteState, setErrorMessage)}
                        disabled={voteState.userVote === -1}
                        title="Downvote"
                        style={{
                          background: 'none',
                          border: 'none',
                          cursor: voteState.userVote === -1 ? 'default' : 'pointer',
                          padding: '0 2px',
                          color: voteState.userVote === -1 ? '#a44' : '#507898',
                          opacity: voteState.userVote === -1 ? 1 : (voteState.userVote === 1 ? 0.4 : 1),
                          fontSize: '20px',
                          verticalAlign: 'middle'
                        }}
                      >
                        <FaCaretDown />
                      </button>
                    </span>
                  </td>
                )}

                {/* C! display and button - matches legacy writeupcools htmlcode (not for drafts) */}
                {!isDraft && (
                <td className="wu_cfull" style={{ verticalAlign: 'middle' }}>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', flexWrap: 'wrap' }}>
                    {/* Show C! count with tooltip showing coolers on hover/click */}
                    {Boolean(coolCount > 0) && (
                      <CoolTooltip cools={coolState.cools} coolCount={coolCount} nodeId={node_id} />
                    )}
                    {/* C? button for eligible users who haven't cooled yet */}
                    {canCool && !coolState.hasCooled && (
                      <>
                        {Boolean(coolCount > 0) && <span>·</span>}
                        <b>
                          <a
                            href="#"
                            className="action"
                            title={`C! ${author?.title || 'this'}'s writeup`}
                            onClick={(e) => {
                              e.preventDefault()
                              handleCool(node_id, user, setCoolState, setErrorMessage)
                            }}
                          >
                            C?
                          </a>
                        </b>
                      </>
                    )}
                    {/* Social sharing links */}
                    {writeup.social_share && (
                      <>
                        {(Boolean(coolCount > 0) || (canCool && !coolState.hasCooled)) && <span>·</span>}
                        <a
                          href={`https://www.facebook.com/sharer.php?u=${encodeURIComponent(writeup.social_share.short_url)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title="Share on Facebook"
                          style={{ color: '#507898', fontSize: '14px', display: 'inline-flex', alignItems: 'center', lineHeight: 1 }}
                        >
                          <FaFacebookSquare />
                        </a>
                        <a
                          href={`https://x.com/intent/post?text=${encodeURIComponent(writeup.social_share.title + ' ' + writeup.social_share.short_url)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title="Share on X (Twitter)"
                          style={{ color: '#507898', fontSize: '14px', display: 'inline-flex', alignItems: 'center', lineHeight: 1 }}
                        >
                          <FaTwitterSquare />
                        </a>
                        <a
                          href={`https://reddit.com/submit?title=${encodeURIComponent(writeup.social_share.title)}&url=${encodeURIComponent(writeup.social_share.short_url)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title="Share on Reddit"
                          style={{ color: '#507898', fontSize: '14px', display: 'inline-flex', alignItems: 'center', lineHeight: 1 }}
                        >
                          <FaRedditSquare />
                        </a>
                      </>
                    )}
                  </div>
                </td>
                )}

                {/* Reputation display - show if user has voted OR is the author (not for drafts) */}
                {!isDraft && (
                <td style={{ textAlign: 'right' }} className="wu_rep">
                  {(isAuthor || (voteState.userVote !== null && voteState.userVote !== undefined)) && (
                    <small>
                      Rep: {voteState.reputation > 0 && '+'}{voteState.reputation} (+{voteState.upvotes}/-{voteState.downvotes})
                    </small>
                  )}
                </td>
                )}
              </tr>
            </tbody>
          </table>

          {/* Error message - red, positioned under C! buttons */}
          {errorMessage && (
            <div style={{
              backgroundColor: '#fee',
              color: '#c00',
              padding: '8px',
              marginTop: '8px',
              fontSize: '12px',
              borderLeft: '3px solid #c00'
            }}>
              {errorMessage}
            </div>
          )}
        </footer>
      )}
      </article>

      {/* Modals are outside <article> so they don't appear in Chrome reading mode */}

      {/* Admin modal (writeups only, not drafts) */}
      {!isDraft && showAdminTools && (
        <AdminModal
          writeup={{ ...writeup, ...writeupState, ...voteState, vote: voteState.userVote, cools: coolState.cools }}
          user={user}
          isOpen={adminModalOpen}
          onClose={() => setAdminModalOpen(false)}
          onEdit={onEdit}
          onWriteupUpdate={(updatedWriteup) => {
            setWriteupState(prev => ({
              ...prev,
              insured: updatedWriteup.insured !== undefined ? updatedWriteup.insured : prev.insured,
              insured_by: updatedWriteup.insured_by !== undefined ? updatedWriteup.insured_by : prev.insured_by,
              notnew: updatedWriteup.notnew !== undefined ? updatedWriteup.notnew : prev.notnew,
              edcooled: updatedWriteup.edcooled !== undefined ? updatedWriteup.edcooled : prev.edcooled,
              bookmarked: updatedWriteup.bookmarked !== undefined ? updatedWriteup.bookmarked : prev.bookmarked
            }))

            // Handle vote state updates
            if (updatedWriteup.vote !== undefined) {
              setVoteState(prev => ({
                ...prev,
                userVote: updatedWriteup.vote,
                reputation: updatedWriteup.reputation !== undefined ? updatedWriteup.reputation : prev.reputation,
                upvotes: updatedWriteup.upvotes !== undefined ? updatedWriteup.upvotes : prev.upvotes,
                downvotes: updatedWriteup.downvotes !== undefined ? updatedWriteup.downvotes : prev.downvotes
              }))
            }

            // Handle cool state updates
            if (updatedWriteup.cools !== undefined) {
              setCoolState({
                cools: updatedWriteup.cools,
                hasCooled: updatedWriteup.cools.some(c => c.node_id === user?.node_id)
              })
            }
          }}
        />
      )}

      {/* Message modal for messaging the author (writeups only, not drafts) */}
      {!isDraft && canMessage && (
        <MessageModal
          isOpen={messageModalOpen}
          onClose={() => setMessageModalOpen(false)}
          replyTo={{ author_user: { title: author.title, type: 'user' } }}
          initialMessage={parent?.title ? `re: ${parent.title}\n\n` : ''}
          onSend={async (recipient, message) => {
            const response = await fetch('/api/messages/create', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ for: recipient, message })
            })
            const data = await response.json()

            // API returns {successes: N, errors: N, ignores: N} for success
            // Check for actual errors or complete ignore/block
            if (data.errors && data.errors.length > 0) {
              throw new Error(data.errors[0] || 'Failed to send message')
            }
            if (data.ignores && !data.successes) {
              // Completely blocked
              throw new Error('User is blocking you')
            }

            // Return data with success flag for MessageModal compatibility
            return { success: true, ...data }
          }}
          currentUser={user}
        />
      )}

      {/* Vote confirmation modal (writeups only, not drafts) */}
      {!isDraft && (
        <ConfirmModal
          isOpen={pendingVote !== null}
          onClose={() => setPendingVote(null)}
          onConfirm={() => {
            handleVote(node_id, pendingVote.weight, setVoteState, setErrorMessage)
            setPendingVote(null)
          }}
          title={pendingVote?.weight === 1 ? 'Confirm Upvote' : 'Confirm Downvote'}
          message={`Are you sure you want to ${pendingVote?.weight === 1 ? 'upvote' : 'downvote'} this writeup by ${author?.title || 'this author'}?`}
          confirmText={pendingVote?.weight === 1 ? 'Upvote' : 'Downvote'}
          confirmColor={pendingVote?.weight === 1 ? '#4a4' : '#a44'}
        />
      )}

      {/* Cool confirmation modal (writeups only, not drafts) */}
      {!isDraft && (
        <ConfirmModal
          isOpen={pendingCool}
          onClose={() => setPendingCool(false)}
          onConfirm={() => {
            handleCool(node_id, user, setCoolState, setErrorMessage)
            setPendingCool(false)
          }}
          title="Confirm C!"
          message={`Are you sure you want to C! this writeup by ${author?.title || 'this author'}? This action cannot be undone.`}
          confirmText="C!"
          confirmColor="#667eea"
        />
      )}
    </>
  )
}

// Vote handling function - updates state without page reload
const handleVote = async (writeupId, weight, setVoteState, setErrorMessage) => {
  try {
    const response = await fetch(`/api/vote/writeup/${writeupId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ weight })
    })

    const data = await response.json()

    if (!data.success) {
      throw new Error(data.message || data.error || 'Vote failed')
    }

    // Update local state with new vote and server-returned reputation
    setVoteState(prev => ({
      ...prev,
      userVote: weight,
      reputation: data.reputation,
      upvotes: data.upvotes,
      downvotes: data.downvotes
    }))

    // Update epicenter with new votes remaining
    if (data.votes_remaining !== undefined) {
      window.dispatchEvent(new CustomEvent('e2:userUpdate', {
        detail: { votesleft: data.votes_remaining }
      }))
    }
  } catch (error) {
    console.error('Error voting:', error)
    setErrorMessage(`Failed to cast vote: ${error.message}`)
    // Auto-dismiss after 5 seconds
    setTimeout(() => setErrorMessage(null), 5000)
  }
}

// C! (cool) handling function
const handleCool = async (writeupId, user, setCoolState, setErrorMessage) => {
  try {
    const response = await fetch(`/api/cool/writeup/${writeupId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
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

    // Update epicenter with new C!s remaining
    if (data.cools_remaining !== undefined) {
      window.dispatchEvent(new CustomEvent('e2:userUpdate', {
        detail: { coolsleft: data.cools_remaining }
      }))
    }
  } catch (error) {
    console.error('Error awarding C!:', error)
    setErrorMessage(`Failed to award C!: ${error.message}`)
    // Auto-dismiss after 5 seconds
    setTimeout(() => setErrorMessage(null), 5000)
  }
}

// Editor cool handling function
const handleEdcool = async (writeupId, setWriteupState) => {
  try {
    const response = await fetch(`/api/cool/writeup/${writeupId}/edcool`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    })

    console.log('[handleEdcool] Response status:', response.status, response.statusText)

    if (!response.ok) {
      const text = await response.text()
      console.error('[handleEdcool] Error response:', text)
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }

    const data = await response.json()
    console.log('[handleEdcool] Response data:', data)

    if (!data.success) {
      throw new Error(data.error || 'Failed to toggle editor cool')
    }

    // Update local state
    setWriteupState(prev => ({
      ...prev,
      edcooled: data.edcooled
    }))
  } catch (error) {
    console.error('[handleEdcool] Error:', error)
    alert(`Failed to toggle editor cool: ${error.message}`)
  }
}

// Bookmark handling function
const handleBookmark = async (writeupId, setWriteupState) => {
  try {
    const response = await fetch(`/api/cool/writeup/${writeupId}/bookmark`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    })

    const data = await response.json()

    if (!data.success) {
      throw new Error(data.error || 'Failed to toggle bookmark')
    }

    // Update local state
    setWriteupState(prev => ({
      ...prev,
      bookmarked: data.bookmarked
    }))
  } catch (error) {
    console.error('Error toggling bookmark:', error)
    alert(`Failed to toggle bookmark: ${error.message}`)
  }
}

export default WriteupDisplay

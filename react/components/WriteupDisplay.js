import React, { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { FaCaretUp, FaCaretDown, FaEnvelope, FaFacebookSquare, FaTwitterSquare, FaRedditSquare } from 'react-icons/fa'
import ParseLinks from './ParseLinks'
import LinkNode from './LinkNode'
import AdminModal from './AdminModal'
import MessageModal from './MessageModal'
import ConfirmActionModal from './ConfirmActionModal'
import { renderE2Content } from './Editor/E2HtmlSanitizer'
import { formatDate } from '../utils/dateFormat'

/**
 * CoolTooltip - Shows who C!ed a writeup on hover or click
 * Displays immediately on hover (no browser delay) and can be clicked to toggle
 * Click to lock open and show full list when there are many C!s
 */
const CoolTooltip = ({ cools, coolCount, nodeId }) => {
  const [showTooltip, setShowTooltip] = useState(false)
  const [isClickLocked, setIsClickLocked] = useState(false)
  const [showAll, setShowAll] = useState(false)
  const [tooltipPos, setTooltipPos] = useState(null)
  const tooltipRef = useRef(null)
  const triggerRef = useRef(null)

  // Tooltip is portaled into document.body so ancestor overflow:auto on the
  // writeup footer table can't clip it (#4139). Because the popup escapes
  // the trigger's DOM ancestry, we compute its absolute viewport position
  // from the trigger's bounding rect each time the popup opens or its size
  // changes. position: fixed avoids being shifted by document scroll.
  useEffect(() => {
    if (!showTooltip || !triggerRef.current) {
      setTooltipPos(null)
      return
    }
    const compute = () => {
      const trig = triggerRef.current
      if (!trig) return
      const t = trig.getBoundingClientRect()
      const tip = tooltipRef.current
      const tipW = tip ? tip.offsetWidth : 240
      const tipH = tip ? tip.offsetHeight : 60
      // Center on trigger horizontally; clamp 8px from viewport edges.
      let left = t.left + t.width / 2 - tipW / 2
      left = Math.max(8, Math.min(left, window.innerWidth - tipW - 8))
      // Prefer above the trigger; flip below if there's no room.
      let top = t.top - tipH - 6
      if (top < 8) top = t.bottom + 6
      setTooltipPos({ top, left })
    }
    compute()
    // Recompute on resize/scroll because position: fixed coords are viewport-relative.
    window.addEventListener('resize', compute)
    window.addEventListener('scroll', compute, true)
    return () => {
      window.removeEventListener('resize', compute)
      window.removeEventListener('scroll', compute, true)
    }
  }, [showTooltip, showAll, cools && cools.length])

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
      className="writeup-cool-tooltip-trigger"
      onClick={handleClick}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {coolCount} <b>C!</b>{coolCount === 1 ? '' : 's'}

      {/* Tooltip popup — portaled into document.body so the writeup footer
          table's overflow:auto (and any other clipping ancestor) can't
          obscure it on mobile (#4139). JS-computed position because we've
          escaped the trigger's DOM ancestry. */}
      {showTooltip && cools && cools.length > 0 && createPortal(
        <span
          ref={tooltipRef}
          onClick={(e) => e.stopPropagation()}
          className={`writeup-cool-tooltip writeup-cool-tooltip--portaled${showAll ? ' writeup-cool-tooltip--expanded' : ''}`}
          style={tooltipPos ? { top: `${tooltipPos.top}px`, left: `${tooltipPos.left}px` } : { visibility: 'hidden' }}
        >
          {/* Show users up to displayLimit */}
          {cools.slice(0, displayLimit).map((c, i) => (
            <span key={c.node_id || i}>
              {i > 0 && ', '}
              <LinkNode type="user" title={c.title} className="writeup-cool-tooltip-link" />
            </span>
          ))}
          {/* Show "and X others" or "show all" link */}
          {hasMore && !showAll && (
            <span>
              {' '}
              <a
                href="#"
                onClick={handleShowAll}
                className="writeup-cool-tooltip-link"
              >
                and {cools.length - 5} other{cools.length - 5 === 1 ? '' : 's'}...
              </a>
            </span>
          )}
        </span>,
        document.body
      )}
    </span>
  )
}

/**
 * DraftStatusBadge - Shows the publication status with appropriate styling
 * Used when displaying draft content via WriteupDisplay
 */
const DraftStatusBadge = ({ status }) => {
  const statusClass = ['private', 'findable', 'review', 'removed'].includes(status)
    ? status
    : 'private'

  return (
    <span className={`writeup-status-badge writeup-status-badge--${statusClass}`}>
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
 *   showAdminToolsOverride - override to force showing admin tools (for drafts with admin actions)
 *   onAdminGearClick - callback for admin gear click (for drafts to open their own modal)
 *
 * Usage:
 *   <WriteupDisplay writeup={writeupData} user={userData} />
 *   <WriteupDisplay writeup={draftData} user={userData} isDraft publicationStatus="private" />
 *   <WriteupDisplay writeup={draftData} isDraft showAdminToolsOverride onAdminGearClick={() => openModal()} />
 */
const WriteupDisplay = ({ writeup, user, showVoting = true, showMetadata = true, onEdit, isDraft = false, publicationStatus, showAdminToolsOverride, onAdminGearClick }) => {
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
  // Note: edcooled and bookmarked are handled by PageActions component
  const [writeupState, setWriteupState] = useState({
    insured: writeup.insured || false,
    insured_by: writeup.insured_by || null,
    notnew: writeup.notnew || false
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

  // Use !! to ensure boolean (not 0) since user.guest/is_guest may be 0 from Perl
  const isGuest = !user || !!user.guest || !!user.is_guest
  // Use String() for comparison since node_id may be string or number
  const isAuthor = !!(user && author && String(user.node_id) === String(author.node_id))
  // Use !! to ensure boolean (not 0) since user.editor/is_editor may be 0
  const isEditor = !!(user?.editor || user?.is_editor)
  const canVote = !isGuest && !isAuthor
  // Check coolsleft directly - user needs to have cools remaining and not be guest/author
  const canCool = !isGuest && !isAuthor && (user?.coolsleft || 0) > 0
  const coolCount = coolState.cools?.length || 0
  // Show admin tools (gear menu).
  // - On non-drafts: any logged-in viewer gets a gear; the modal itself
  //   decides which actions the user can actually take (editor-only,
  //   author-only, etc).
  // - On drafts: the gear only renders when the parent (Draft.js) explicitly
  //   opts in via showAdminToolsOverride. The DraftAdminModal is republish-
  //   for-removed-drafts only — without this gate, editors viewing a review-
  //   status draft saw a gear that opened nothing.
  const showAdminTools = isDraft
    ? Boolean(showAdminToolsOverride)
    : (isEditor || isAuthor || !isGuest)
  // Can message author if logged in and not messaging yourself
  const canMessage = !isGuest && !isAuthor && author

  // Date formatting delegates to shared UTC-aware utility (utils/dateFormat).

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
        {/* Uses CSS classes for responsive layout (see 1882070.css media queries) */}
        {/* data-reader-ignore on header since it's navigation/metadata, not content */}
        <header className="contentinfo contentheader" data-reader-ignore="true">
          <div className="wu_header">
            {/* Type: (writeuptype) linking to this writeup, or (draft) with status badge */}
            <span className="wu_type">
              <span className="type">
                {isDraft ? (
                  <>
                    (<span className="writeup-type-draft">draft</span>)
                    <DraftStatusBadge status={publicationStatus || 'unknown'} />
                  </>
                ) : (
                  <>(<LinkNode id={node_id} display={writeuptype || 'writeup'} />)</>
                )}
              </span>
            </span>
            {/* Author with anchor for hash links */}
            <span className="wu_author">
              by <a name={author?.title}></a>
              <strong>
                {author ? (
                  <LinkNode type="user" title={author.title} className="author" />
                ) : (
                  <span className="author">(no owner)</span>
                )}
              </strong>
              {shouldShowAuthorSince() && (
                <small className="wu_author_lastseen">
                  ({formatTimeSince(author.lasttime)})
                </small>
              )}
            </span>
            {/* Publication/creation date */}
            <span className="wu_dtcreate">
              <small className="date" title={formatDate(displayDate)}>
                {formatDate(displayDate)}
              </small>
            </span>
          </div>
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
                {/* Draft message and admin tools - show for drafts */}
                {isDraft && (
                  <td className="wu_tools wu_tools--left">
                    <span className="wu_tools_inline">
                      {/* Admin gear for drafts when callback provided */}
                      {showAdminTools && onAdminGearClick && (
                        <button
                          onClick={onAdminGearClick}
                          title="Draft tools"
                          className="writeup-tool-btn"
                        >
                          &#9881;
                        </button>
                      )}
                      {/* Message-draft-author button. Surfaces the same
                          feedback flow editors get on published writeups so
                          a draft in review can be commented on without
                          jumping out to the messaging UI. Shows the feedback
                          checkbox (default-off) so the editor can opt in to
                          also record the message as a nodenote on the draft. */}
                      {canMessage && (
                        <button
                          onClick={() => setMessageModalOpen(true)}
                          title={`Send feedback to ${author.title}`}
                          className="writeup-tool-btn"
                        >
                          <FaEnvelope />
                        </button>
                      )}
                      <small className="writeup-draft-notice">
                        This is an unpublished draft. Only you and any collaborators can see it.
                      </small>
                    </span>
                  </td>
                )}
                {/* Tools cell - action buttons on left (not for drafts) */}
                {!isDraft && (
                  <td className="wu_tools wu_tools--left">
                    <span className="wu_tools_inline wu_tools_inline--tight">
                      {/* Admin gear */}
                      {showAdminTools && (
                        <button
                          onClick={() => setAdminModalOpen(true)}
                          title="Admin tools"
                          className="writeup-tool-btn"
                        >
                          &#9881;
                        </button>
                      )}
                      {/* Message author */}
                      {canMessage && (
                        <button
                          onClick={() => setMessageModalOpen(true)}
                          title={`Message ${author.title}`}
                          className="writeup-tool-btn"
                        >
                          <FaEnvelope />
                        </button>
                      )}
                      {/* Note: Editor cool, bookmark, category, and weblog buttons are now in PageActions component */}
                    </span>
                  </td>
                )}
                {/* Voting controls - modern icon buttons (not for drafts) */}
                {/* Note: Caret icons are naturally smaller, so use 28px to get ~20px visual height */}
                {!isDraft && showVoting && canVote && (
                  <td className="wu_vote">
                    <span className="vote_buttons">
                      <button
                        onClick={() => {
                          if (user?.votesafety) {
                            setPendingVote({ weight: 1 })
                          } else {
                            handleVote(node_id, 1, setVoteState, setErrorMessage)
                          }
                        }}
                        disabled={voteState.userVote === 1}
                        title="Upvote"
                        className={`writeup-vote-btn${voteState.userVote === 1 ? ' writeup-vote-btn--upvote-active' : ''}${voteState.userVote === -1 ? ' writeup-vote-btn--faded' : ''}`}
                      >
                        <FaCaretUp />
                      </button>
                      <button
                        onClick={() => {
                          if (user?.votesafety) {
                            setPendingVote({ weight: -1 })
                          } else {
                            handleVote(node_id, -1, setVoteState, setErrorMessage)
                          }
                        }}
                        disabled={voteState.userVote === -1}
                        title="Downvote"
                        className={`writeup-vote-btn${voteState.userVote === -1 ? ' writeup-vote-btn--downvote-active' : ''}${voteState.userVote === 1 ? ' writeup-vote-btn--faded' : ''}`}
                      >
                        <FaCaretDown />
                      </button>
                    </span>
                  </td>
                )}

                {/* C! display and button (not for drafts) */}
                {!isDraft && (
                <td className="wu_cfull">
                  <div className="wu_cfull_content">
                    {/* Show C! count with tooltip showing coolers on hover/click */}
                    {Boolean(coolCount > 0) && (
                      <CoolTooltip cools={coolState.cools} coolCount={coolCount} nodeId={node_id} />
                    )}
                    {/* C? button for eligible users who haven't cooled yet */}
                    {canCool && !coolState.hasCooled && (
                      <>
                        {Boolean(coolCount > 0) && <span className="writeup-separator">·</span>}
                        <a
                          href="#"
                          className="writeup-cool-action"
                          title={`C! ${author?.title || 'this'}'s writeup`}
                          onClick={(e) => {
                            e.preventDefault()
                            if (user?.coolsafety) {
                              setPendingCool(true)
                            } else {
                              handleCool(node_id, user, setCoolState, setErrorMessage)
                            }
                          }}
                        >
                          C?
                        </a>
                      </>
                    )}
                    {/* Social sharing links */}
                    {writeup.social_share && (
                      <>
                        {(Boolean(coolCount > 0) || (canCool && !coolState.hasCooled)) && <span className="writeup-separator">·</span>}
                        <a
                          href={`https://www.facebook.com/sharer.php?u=${encodeURIComponent(writeup.social_share.short_url)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title="Share on Facebook"
                          className="writeup-social-link"
                        >
                          <FaFacebookSquare />
                        </a>
                        <a
                          href={`https://x.com/intent/post?text=${encodeURIComponent(writeup.social_share.title + ' ' + writeup.social_share.short_url)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title="Share on X (Twitter)"
                          className="writeup-social-link"
                        >
                          <FaTwitterSquare />
                        </a>
                        <a
                          href={`https://reddit.com/submit?title=${encodeURIComponent(writeup.social_share.title)}&url=${encodeURIComponent(writeup.social_share.short_url)}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          title="Share on Reddit"
                          className="writeup-social-link"
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
                <td className="wu_rep">
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
            <div className="writeup-error">
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
          availableGroups={window.e2?.usergroupData?.availableGroups || []}
          onWriteupUpdate={(updatedWriteup) => {
            setWriteupState(prev => ({
              ...prev,
              insured: updatedWriteup.insured !== undefined ? updatedWriteup.insured : prev.insured,
              insured_by: updatedWriteup.insured_by !== undefined ? updatedWriteup.insured_by : prev.insured_by,
              notnew: updatedWriteup.notnew !== undefined ? updatedWriteup.notnew : prev.notnew
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

      {/* Message modal for messaging the author. Renders on both writeups
          and drafts — on drafts it doubles as the feedback flow for editors
          reviewing a draft in 'review' status. */}
      {canMessage && (
        <MessageModal
          isOpen={messageModalOpen}
          onClose={() => setMessageModalOpen(false)}
          replyTo={{ author_user: { title: author.title, type: 'user' } }}
          initialMessage={parent?.title ? `re: ${parent.title}\n\n` : (isDraft && title ? `re: ${title}\n\n` : '')}
          // Editors get a "post this feedback as a node note" checkbox
          // (default off). When checked, the same text is also persisted as a
          // nodenote on the writeup/draft so the review thread survives past
          // the message inbox (which the author may purge). Non-editor
          // messagers don't see the checkbox — the nodenote API rejects
          // non-editors anyway.
          showFeedbackOption={Boolean(user?.is_editor || user?.editor)}
          onSend={async (recipient, message, meta = {}) => {
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

            // If the editor opted to record this as writeup feedback, also
            // drop a nodenote on the writeup. We don't fail the modal close
            // if the nodenote call fails — the message went out, that's the
            // user-visible action; the nodenote is the audit trail and a
            // failure there is logged but doesn't block.
            if (meta.isFeedback && (user?.is_editor || user?.editor)) {
              try {
                const noteResponse = await fetch(`/api/nodenotes/${node_id}/create`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ notetext: message })
                })
                if (!noteResponse.ok) {
                  // Surface as a warning so the editor knows the note didn't
                  // attach, but don't reject the whole modal action.
                  return { success: true, ...data, warning: 'Message sent, but failed to record as node note.' }
                }
              } catch (err) {
                return { success: true, ...data, warning: 'Message sent, but failed to record as node note: ' + (err.message || 'unknown error') }
              }
            }

            // Return data with success flag for MessageModal compatibility
            return { success: true, ...data }
          }}
          currentUser={user}
        />
      )}

      {/* Vote confirmation modal (writeups only, not drafts) */}
      {!isDraft && (
        <ConfirmActionModal
          isOpen={pendingVote !== null}
          onClose={() => setPendingVote(null)}
          onConfirm={() => handleVote(node_id, pendingVote.weight, setVoteState, setErrorMessage)}
          title={pendingVote?.weight === 1 ? 'Confirm Upvote' : 'Confirm Downvote'}
          message={`Are you sure you want to ${pendingVote?.weight === 1 ? 'upvote' : 'downvote'} this writeup by ${author?.title || 'this author'}?`}
          confirmLabel={pendingVote?.weight === 1 ? 'Upvote' : 'Downvote'}
          confirmStyle="default"
          closeOnConfirm
        />
      )}

      {/* Cool confirmation modal (writeups only, not drafts) */}
      {!isDraft && (
        <ConfirmActionModal
          isOpen={pendingCool}
          onClose={() => setPendingCool(false)}
          onConfirm={() => handleCool(node_id, user, setCoolState, setErrorMessage)}
          title="Confirm C!"
          message={`Are you sure you want to C! this writeup by ${author?.title || 'this author'}? This action cannot be undone.`}
          confirmLabel="C!"
          confirmStyle="default"
          closeOnConfirm
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

// Note: Editor cool and bookmark handling are now in PageActions component

export default WriteupDisplay

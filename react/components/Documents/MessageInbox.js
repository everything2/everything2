import React from 'react'
import DOMPurify from 'dompurify'
import LinkNode from '../LinkNode'
import MessageList from '../MessageList'
import MessageModal from '../MessageModal'
import ParseLinks from '../ParseLinks'
import UserSearchInput from '../UserSearchInput'
import ConfirmActionModal from '../ConfirmActionModal'
import { formatMessageTimestamp } from '../../utils/dateFormat'

// Sanitize legacy HTML messages - only allow <a> tags with href attribute
// Legacy messages from sendPrivateMessage htmlcode contain pre-parsed HTML links
const sanitizeMessageHtml = (html) => {
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['a', 'em', 'strong', 'b', 'i'],
    ALLOWED_ATTR: ['href', 'title'],
    ALLOW_DATA_ATTR: false
  })
}

/**
 * MessageInbox - Full-page message management
 *
 * Combines inbox and outbox functionality with:
 * - Tab-based navigation (Inbox/Sent)
 * - Archive/Unarchive toggle for inbox only
 * - Bot inbox access for authorized users
 * - Usergroup filtering
 * - Pagination for large message lists
 * - Modal reply system with send-as-bot support
 *
 * Uses the same visual patterns as the Messages nodelet for consistency.
 */
const MessageInbox = ({ data }) => {
  // Handle guest users
  if (data.error === 'guest') {
    return (
      <div className="message-inbox-guest">
        <h2 className="message-inbox-guest-title">Message Inbox</h2>
        <p>{data.message}</p>
        <a href="/title/Login" className="message-inbox-guest-login">
          Log In
        </a>
      </div>
    )
  }

  // Core state - default to inbox unless page specifies outbox
  const defaultTab = data.defaultTab || 'inbox'
  const [activeTab, setActiveTab] = React.useState(defaultTab)
  const [showArchived, setShowArchived] = React.useState(false)
  const [messages, setMessages] = React.useState(
    defaultTab === 'outbox' ? (data.outbox?.messages || []) : (data.inbox?.messages || [])
  )
  const [totalCount, setTotalCount] = React.useState(
    defaultTab === 'outbox' ? (data.outbox?.count || 0) : (data.inbox?.count || 0)
  )
  const [archivedCount, setArchivedCount] = React.useState(
    defaultTab === 'outbox' ? (data.outbox?.archivedCount || 0) : (data.inbox?.archivedCount || 0)
  )
  const [outboxCount, setOutboxCount] = React.useState(data.outbox?.count || 0)
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState(null)
  const [page, setPage] = React.useState(0)
  const pageSize = data.pageSize || 25

  // Filtering state
  const [viewingBot, setViewingBot] = React.useState(data.viewingBot || null) // Bot user being viewed (from spy_user param)
  const [filterUsergroup, setFilterUsergroup] = React.useState(null) // Usergroup filter
  const [fromUser, setFromUser] = React.useState(data.fromUser || null) // Sender filter from "/msgs from me" link (#4042)
  const [showFilters, setShowFilters] = React.useState(false) // Collapsible filter panel

  // Bot and usergroup data from server
  const accessibleBots = data.accessibleBots || []
  // The usergroup picker now offers any group the user is in or has received
  // mail from — server pre-computes the union to avoid suggesting groups
  // they couldn't reasonably want to filter on.
  const accessibleUsergroups = data.accessibleUsergroups
    || data.usergroupsWithMessages
    || []
  const currentUser = data.currentUser || {}

  // Modal state
  const [modalOpen, setModalOpen] = React.useState(false)
  const [replyingTo, setReplyingTo] = React.useState(null)
  const [isReplyAll, setIsReplyAll] = React.useState(false)
  const [sendAsUser, setSendAsUser] = React.useState(null) // For sending as bot

  // Delete confirmation state
  const [deleteConfirmOpen, setDeleteConfirmOpen] = React.useState(false)
  const [messageToDelete, setMessageToDelete] = React.useState(null)
  const [isOutboxDelete, setIsOutboxDelete] = React.useState(false)

  // Build API params based on current filters.
  // The same `fromUser` state powers both tabs: it's the "other party" in
  // the message, so it maps to `from_user` on inbox (sender) and `to_user`
  // on outbox (recipient). `viewingBot` maps to `for_user` on BOTH tabs:
  // on inbox it's "show that bot's inbox", on outbox it's "show that
  // bot's sent items" (server uses target_user for both paths).
  const buildApiParams = React.useCallback((tab, archived, pageNum) => {
    const params = new URLSearchParams()
    params.set('limit', pageSize.toString())

    if (tab === 'outbox') {
      params.set('outbox', '1')
      if (viewingBot) params.set('for_user', viewingBot.node_id.toString())
      if (fromUser) params.set('to_user', fromUser.node_id.toString())
      if (filterUsergroup) params.set('for_usergroup', filterUsergroup.node_id.toString())
    } else {
      if (archived) params.set('archive', '1')
      if (viewingBot) params.set('for_user', viewingBot.node_id.toString())
      if (filterUsergroup) params.set('for_usergroup', filterUsergroup.node_id.toString())
      if (fromUser) params.set('from_user', fromUser.node_id.toString())
    }

    if (pageNum > 0) params.set('offset', (pageNum * pageSize).toString())

    return params.toString()
  }, [pageSize, viewingBot, filterUsergroup, fromUser])

  // Load messages when tab, archive filter, or page changes
  const loadMessages = React.useCallback(async (tab, archived, pageNum, botUser = viewingBot, ugFilter = filterUsergroup, senderFilter = fromUser) => {
    setLoading(true)
    setError(null)

    try {
      const params = new URLSearchParams()
      params.set('limit', pageSize.toString())

      if (tab === 'outbox') {
        params.set('outbox', '1')
        // botUser surfaces the bot's outbox (mirrors the inbox path);
        // senderFilter doubles as the recipient filter on Sent —
        // see buildApiParams comment for the rationale.
        if (botUser) params.set('for_user', botUser.node_id.toString())
        if (senderFilter) params.set('to_user', senderFilter.node_id.toString())
        if (ugFilter) params.set('for_usergroup', ugFilter.node_id.toString())
      } else {
        if (archived) params.set('archive', '1')
        if (botUser) params.set('for_user', botUser.node_id.toString())
        if (ugFilter) params.set('for_usergroup', ugFilter.node_id.toString())
        if (senderFilter) params.set('from_user', senderFilter.node_id.toString())
      }

      if (pageNum > 0) params.set('offset', (pageNum * pageSize).toString())

      const response = await fetch(
        `/api/messages/?${params.toString()}`,
        {
          credentials: 'include',
          headers: { 'X-Ajax-Idle': '1' }
        }
      )

      if (!response.ok) {
        throw new Error('Failed to load messages')
      }

      const messageData = await response.json()
      setMessages(messageData)

      // Always refresh BOTH tabs' counts so the inactive tab's badge
      // doesn't go stale when filters change. The three count requests
      // are independent — fire them in parallel.
      const inboxParams = new URLSearchParams()
      if (botUser) inboxParams.set('for_user', botUser.node_id.toString())
      if (ugFilter) inboxParams.set('for_usergroup', ugFilter.node_id.toString())
      if (senderFilter) inboxParams.set('from_user', senderFilter.node_id.toString())

      const inboxArchivedParams = new URLSearchParams(inboxParams)
      inboxArchivedParams.set('archive', '1')

      const outboxParams = new URLSearchParams()
      outboxParams.set('outbox', '1')
      if (botUser) outboxParams.set('for_user', botUser.node_id.toString())
      if (senderFilter) outboxParams.set('to_user', senderFilter.node_id.toString())
      if (ugFilter) outboxParams.set('for_usergroup', ugFilter.node_id.toString())

      const [inboxResp, inboxArchivedResp, outboxResp] = await Promise.all([
        fetch(`/api/messages/count?${inboxParams.toString()}`, { credentials: 'include' }),
        fetch(`/api/messages/count?${inboxArchivedParams.toString()}`, { credentials: 'include' }),
        fetch(`/api/messages/count?${outboxParams.toString()}`, { credentials: 'include' }),
      ])

      if (inboxResp.ok) {
        const data = await inboxResp.json()
        setTotalCount(data.count)
      }
      if (inboxArchivedResp.ok) {
        const data = await inboxArchivedResp.json()
        setArchivedCount(data.count)
      }
      if (outboxResp.ok) {
        const data = await outboxResp.json()
        setOutboxCount(data.count)
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [pageSize, viewingBot, filterUsergroup, fromUser])

  // Handle tab change. All three filters persist across tabs now:
  // - fromUser doubles as recipient filter on Sent
  // - filterUsergroup applies on both
  // - viewingBot surfaces the bot's inbox OR outbox depending on tab —
  //   editors moderating a shared bot account get both halves of the
  //   conversation view.
  const handleTabChange = (tab) => {
    if (tab !== activeTab) {
      setActiveTab(tab)
      setShowArchived(false)
      setPage(0)
      loadMessages(tab, false, 0, viewingBot, filterUsergroup, fromUser)
    }
  }

  // Handle archive toggle (inbox only)
  const handleArchiveToggle = (archived) => {
    if (archived !== showArchived && activeTab === 'inbox') {
      setShowArchived(archived)
      setPage(0)
      loadMessages('inbox', archived, 0)
    }
  }

  // Handle bot inbox selection
  const handleBotChange = (bot) => {
    setViewingBot(bot)
    setPage(0)
    setShowArchived(false)
    // When viewing-as a bot, default the compose "send as" to that bot
    // so replies go out under the bot's identity, matching the inbox/outbox
    // view the editor is looking at.
    setSendAsUser(bot)
    // Apply to whichever tab is open — viewingBot is meaningful on both
    // now (bot's inbox vs. bot's sent items).
    loadMessages(activeTab, false, 0, bot, filterUsergroup, fromUser)
  }

  // Handle usergroup filter — applies to whichever tab is active. On Sent
  // the outbox path switches to the `message` table so the for_usergroup
  // column is queryable; `message_outbox` doesn't carry that field.
  const handleUsergroupFilter = (ug) => {
    setFilterUsergroup(ug)
    setPage(0)
    loadMessages(activeTab, showArchived, 0, viewingBot, ug)
  }

  // Clear the sender/recipient filter (#4042 — originally only set by
  // /msgs from me on homenodes; now also settable via the autosuggest).
  // Strip ?fromuser=... from the URL so a refresh doesn't bring it back
  // when the user has explicitly cleared it.
  const handleClearFromUser = () => {
    setFromUser(null)
    setPage(0)
    if (typeof window !== 'undefined' && window.history?.replaceState) {
      const url = new URL(window.location.href)
      url.searchParams.delete('fromuser')
      window.history.replaceState({}, '', url.toString())
    }
    loadMessages(activeTab, showArchived, 0, viewingBot, filterUsergroup, null)
  }

  // Pick a sender (or recipient on Sent) from the autosuggest in the
  // filter panel. UserSearchInput hands us {node_id, title} (node_id may
  // be null if typed text didn't resolve — guard against that).
  const handleFromUserSelect = (selected) => {
    if (!selected || !selected.node_id) return
    const next = { node_id: selected.node_id, title: selected.title }
    setFromUser(next)
    setPage(0)
    loadMessages(activeTab, showArchived, 0, viewingBot, filterUsergroup, next)
  }

  // Handle pagination
  const handlePageChange = (newPage) => {
    setPage(newPage)
    loadMessages(activeTab, showArchived, newPage)
  }

  // Archive a message (inbox)
  const handleArchive = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/archive`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) throw new Error('Failed to archive message')

      setMessages(messages.filter(m => m.message_id !== messageId))
      setTotalCount(prev => Math.max(0, prev - 1))
      setArchivedCount(prev => prev + 1)
    } catch (err) {
      setError(err.message)
    }
  }

  // Unarchive a message (inbox)
  const handleUnarchive = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/unarchive`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) throw new Error('Failed to unarchive message')

      setMessages(messages.filter(m => m.message_id !== messageId))
      setArchivedCount(prev => Math.max(0, prev - 1))
      setTotalCount(prev => prev + 1)
    } catch (err) {
      setError(err.message)
    }
  }

  // Handle delete (both inbox and outbox)
  const handleDelete = (messageId, isOutbox = false) => {
    setMessageToDelete(messageId)
    setIsOutboxDelete(isOutbox)
    setDeleteConfirmOpen(true)
  }

  const confirmDelete = async () => {
    try {
      const endpoint = isOutboxDelete
        ? `/api/messages/${messageToDelete}/action/delete_outbox`
        : `/api/messages/${messageToDelete}/action/delete`

      const response = await fetch(endpoint, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) throw new Error('Failed to delete message')

      setMessages(messages.filter(m => m.message_id !== messageToDelete))
      if (isOutboxDelete) {
        setOutboxCount(prev => Math.max(0, prev - 1))
      } else if (showArchived) {
        setArchivedCount(prev => Math.max(0, prev - 1))
      } else {
        setTotalCount(prev => Math.max(0, prev - 1))
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setDeleteConfirmOpen(false)
      setMessageToDelete(null)
      setIsOutboxDelete(false)
    }
  }

  const cancelDelete = () => {
    setDeleteConfirmOpen(false)
    setMessageToDelete(null)
    setIsOutboxDelete(false)
  }

  // Reply handlers
  const handleReply = (message, replyAll = false) => {
    setReplyingTo(message)
    setIsReplyAll(replyAll)
    // If viewing bot inbox, default to replying as that bot
    if (viewingBot) {
      setSendAsUser(viewingBot)
    } else {
      setSendAsUser(null)
    }
    setModalOpen(true)
  }

  const handleNewMessage = () => {
    setReplyingTo(null)
    setIsReplyAll(false)
    // If viewing bot inbox, default to sending as that bot
    if (viewingBot) {
      setSendAsUser(viewingBot)
    } else {
      setSendAsUser(null)
    }
    setModalOpen(true)
  }

  const handleSendMessage = async (recipient, messageText, sendAs = null) => {
    try {
      const body = {
        for: recipient,
        message: messageText
      }

      // Add send_as if sending as a bot
      if (sendAs && sendAs.node_id !== currentUser.node_id) {
        body.send_as = sendAs.node_id
      }

      const response = await fetch('/api/messages/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify(body)
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      // Check response body for blocking/error indicators
      const data = await response.json()

      // Check if user is being ignored (complete block)
      if (data.ignores) {
        throw new Error(`${recipient} is ignoring you`)
      }

      // Check for partial usergroup blocks (warnings, not errors)
      if (data.errors && Array.isArray(data.errors) && data.errors.length > 0) {
        // Count blocked members
        const blockedCount = data.errors.length
        const warningMsg = blockedCount === 1
          ? `Message sent, but 1 user is blocking you`
          : `Message sent, but ${blockedCount} users are blocking you`

        // Refresh if on sent messages tab
        if (activeTab === 'outbox') {
          loadMessages('outbox', false, page)
        }

        // Return warning for partial success
        return { success: true, warning: warningMsg }
      }

      // Check for other errors (complete failures)
      if (data.errortext) {
        throw new Error(data.errortext)
      }

      // Refresh if on sent messages tab
      if (activeTab === 'outbox') {
        loadMessages('outbox', false, page)
      }

      return true
    } catch (err) {
      console.error('Failed to send message:', err)
      throw err
    }
  }

  // Calculate pagination
  const currentCount = activeTab === 'outbox'
    ? outboxCount
    : (showArchived ? archivedCount : totalCount)
  const totalPages = Math.ceil(currentCount / pageSize)
  const hasNextPage = page < totalPages - 1
  const hasPrevPage = page > 0

  // Pagination controls component (reused top and bottom)
  const PaginationControls = () => {
    if (totalPages <= 1) return null

    return (
      <div className="message-inbox-pagination">
        <button
          onClick={() => handlePageChange(page - 1)}
          disabled={!hasPrevPage || loading}
          className="message-inbox-pagination-btn"
        >
          ← Previous
        </button>
        <span className="message-inbox-pagination-info">
          Page {page + 1} of {totalPages}
        </span>
        <button
          onClick={() => handlePageChange(page + 1)}
          disabled={!hasNextPage || loading}
          className="message-inbox-pagination-btn"
        >
          Next →
        </button>
      </div>
    )
  }

  // Render a sent message (outbox) - simplified, no archive
  const renderSentMessage = (message) => {
    // Recipient line — populated server-side from the message table when
    // available. For group sends we show the group; for 1:1 we show the
    // recipient user; for unrecoverable rows (recipient deleted their
    // copy and the original `message` row is gone) we fall back to a
    // plain "Sent" so the row still renders.
    const groupRef = message.for_usergroup && message.for_usergroup.node_id > 0
      ? message.for_usergroup
      : null
    const userRef = !groupRef
      && message.for_user
      && message.for_user.node_id > 0
      ? message.for_user
      : null

    return (
      <div key={message.message_id} className="message-inbox-sent-item">
        <div className="message-inbox-sent-header">
          <strong className="message-inbox-sent-recipient">
            {groupRef ? (
              <>To group: <LinkNode id={groupRef.node_id} display={groupRef.title} /></>
            ) : userRef ? (
              <>To: <LinkNode id={userRef.node_id} display={userRef.title} /></>
            ) : (
              <span className="message-inbox-sent-recipient--unknown">Sent</span>
            )}
          </strong>
          <span className="message-inbox-sent-timestamp">
            {formatMessageTimestamp(message.timestamp)}
          </span>
        </div>

        <div className="message-inbox-sent-text">
          {/* Legacy messages contain HTML, new messages use bracket syntax */}
          {message.msgtext && message.msgtext.includes('<a ') ? (
            <span dangerouslySetInnerHTML={{ __html: sanitizeMessageHtml(message.msgtext) }} />
          ) : (
            <ParseLinks>{message.msgtext}</ParseLinks>
          )}
        </div>

        <div className="message-inbox-sent-actions">
          <button
            onClick={() => handleDelete(message.message_id, true)}
            className="message-inbox-delete-btn"
            title="Delete sent message"
          >
            🗑
          </button>
        </div>
      </div>
    )
  }

  // Determine inbox label
  const getInboxLabel = () => {
    if (viewingBot) {
      return `${viewingBot.title}'s Inbox`
    }
    return 'Inbox'
  }

  return (
    <div className="message-inbox">
      {/* Error display */}
      {error && (
        <div className="message-inbox-error">
          {error}
        </div>
      )}

      {/* Filters bar — always visible to any logged-in viewer. Previously
          we hid the entire panel unless the user was an editor (bot inbox)
          or had pre-existing usergroup messages, which meant regular users
          couldn't reach the sender filter at all. */}
      <div className="message-inbox-filters">
        <button
          onClick={() => setShowFilters(!showFilters)}
          className="message-inbox-filters-toggle"
        >
          <span>
            <strong>Filters</strong>
            {(viewingBot || filterUsergroup || fromUser) && (
              <span className="message-inbox-filters-active">
                {[
                  viewingBot && `Viewing: ${viewingBot.title}`,
                  fromUser && `${activeTab === 'outbox' ? 'To' : 'From'}: ${fromUser.title}`,
                  filterUsergroup && `Group: ${filterUsergroup.title}`,
                ].filter(Boolean).join(' • ')}
              </span>
            )}
          </span>
          <span>{showFilters ? '▲' : '▼'}</span>
        </button>

        {showFilters && (
          <div className="message-inbox-filters-panel">
            {/* Bot inbox selector — editors / admins only */}
            {accessibleBots.length > 0 && (
              <div className="message-inbox-filter-group">
                <label className="message-inbox-filter-label">
                  View Inbox For:
                </label>
                <select
                  value={viewingBot?.node_id || ''}
                  onChange={(e) => {
                    const botId = e.target.value
                    if (botId === '') {
                      handleBotChange(null)
                    } else {
                      const bot = accessibleBots.find(b => b.node_id.toString() === botId)
                      handleBotChange(bot)
                    }
                  }}
                  className="message-inbox-filter-select"
                >
                  <option value="">{currentUser.title} (me)</option>
                  {accessibleBots.map(bot => (
                    <option key={bot.node_id} value={bot.node_id}>
                      {bot.title}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {/* Other-party filter — autosuggest against /api/node_search?scope=users.
                The label swaps to match the active tab: Sender on Inbox
                (filter by message author), Recipient on Sent (filter by
                message destination). The underlying state persists across
                tabs so switching keeps the filter applied. */}
            <div className="message-inbox-filter-group">
              <label className="message-inbox-filter-label">
                {activeTab === 'outbox' ? 'Filter by Recipient:' : 'Filter by Sender:'}
              </label>
              <UserSearchInput
                key={fromUser?.node_id || 'no-from-user'}
                onSelect={handleFromUserSelect}
                placeholder="Type a username..."
                clearOnSelect={false}
                showButton={false}
              />
            </div>

            {/* Sent to Usergroup filter — bounded to groups the user is
                in or has received messages from (computed server-side as
                accessibleUsergroups). Hidden if they have none. */}
            {accessibleUsergroups.length > 0 && (
              <div className="message-inbox-filter-group">
                <label className="message-inbox-filter-label">
                  Sent to Usergroup:
                </label>
                <select
                  value={filterUsergroup?.node_id || ''}
                  onChange={(e) => {
                    const ugId = e.target.value
                    if (ugId === '') {
                      handleUsergroupFilter(null)
                    } else {
                      const ug = accessibleUsergroups.find(u => u.node_id.toString() === ugId)
                      handleUsergroupFilter(ug)
                    }
                  }}
                  className="message-inbox-filter-select"
                >
                  <option value="">All groups</option>
                  {accessibleUsergroups.map(ug => (
                    <option key={ug.node_id} value={ug.node_id}>
                      {ug.title}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Active-filter chip row. Surfaces whichever filters are currently
          in effect so the user can see at a glance why the list is narrowed
          and clear any filter independently. Persists across pagination
          and tab switches. The fromUser chip swaps "From" → "To" on the
          Sent tab since the same state means recipient there. */}
      {(viewingBot || fromUser || filterUsergroup) && (
        <div className="message-inbox-filter-chips">
          {viewingBot && (
            <div className="message-inbox-filter-chip">
              Viewing as <strong>{viewingBot.title}</strong>
              <button
                type="button"
                onClick={() => handleBotChange(null)}
                className="message-inbox-filter-chip-clear"
                title={`Switch back to ${currentUser.title}'s ${activeTab === 'outbox' ? 'sent items' : 'inbox'}`}
                aria-label="Clear bot inbox selection"
              >
                ×
              </button>
            </div>
          )}
          {fromUser && (
            <div className="message-inbox-filter-chip">
              {activeTab === 'outbox' ? 'To ' : 'From '}
              <strong>{fromUser.title}</strong>
              <button
                type="button"
                onClick={handleClearFromUser}
                className="message-inbox-filter-chip-clear"
                title={activeTab === 'outbox'
                  ? 'Show messages sent to anyone'
                  : 'Show messages from all senders'}
                aria-label={activeTab === 'outbox'
                  ? 'Clear recipient filter'
                  : 'Clear sender filter'}
              >
                ×
              </button>
            </div>
          )}
          {filterUsergroup && (
            <div className="message-inbox-filter-chip">
              Group <strong>{filterUsergroup.title}</strong>
              <button
                type="button"
                onClick={() => handleUsergroupFilter(null)}
                className="message-inbox-filter-chip-clear"
                title="Show messages from all usergroups"
                aria-label="Clear usergroup filter"
              >
                ×
              </button>
            </div>
          )}
        </div>
      )}

      {/* Tab navigation */}
      <div className="message-inbox-tabs">
        <button
          onClick={() => handleTabChange('inbox')}
          className={`message-inbox-tab${activeTab === 'inbox' ? ' message-inbox-tab--active' : ''}`}
        >
          📥 {getInboxLabel()}
          <span className="message-inbox-tab-count">
            ({totalCount})
          </span>
        </button>
        <button
          onClick={() => handleTabChange('outbox')}
          className={`message-inbox-tab${activeTab === 'outbox' ? ' message-inbox-tab--active' : ''}`}
        >
          📤 Sent
          <span className="message-inbox-tab-count">
            ({outboxCount})
          </span>
        </button>
      </div>

      {/* Archive toggle - only show for inbox */}
      {activeTab === 'inbox' && (
        <div className="message-inbox-archive-toggle">
          <button
            onClick={() => handleArchiveToggle(false)}
            disabled={loading || !showArchived}
            className={`message-inbox-archive-btn message-inbox-archive-btn--left${!showArchived ? ' message-inbox-archive-btn--active' : ''}`}
          >
            Active ({totalCount})
          </button>
          <button
            onClick={() => handleArchiveToggle(true)}
            disabled={loading || showArchived}
            className={`message-inbox-archive-btn message-inbox-archive-btn--right${showArchived ? ' message-inbox-archive-btn--active' : ''}`}
          >
            Archived ({archivedCount})
          </button>
        </div>
      )}

      {/* Loading indicator */}
      {loading && (
        <div className="message-inbox-loading">
          Loading messages...
        </div>
      )}

      {/* Top pagination */}
      <PaginationControls />

      {/* Message list */}
      {!loading && (
        <>
          {activeTab === 'inbox' ? (
            <MessageList
              messages={messages}
              onReply={handleReply}
              onReplyAll={handleReply}
              onArchive={handleArchive}
              onUnarchive={handleUnarchive}
              onDelete={(id) => handleDelete(id, false)}
              compact={false}
              showActions={{
                reply: true,
                replyAll: true,
                archive: true,
                unarchive: true,
                delete: true
              }}
            />
          ) : (
            <div>
              {messages.length === 0 ? (
                <div className="message-inbox-empty">
                  No sent messages
                </div>
              ) : (
                messages.map(msg => renderSentMessage(msg))
              )}
            </div>
          )}
        </>
      )}

      {/* Bottom pagination */}
      <PaginationControls />

      {/* Message composition modal with send-as support */}
      <MessageModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        replyTo={replyingTo}
        onSend={(recipient, text) => handleSendMessage(recipient, text, sendAsUser)}
        initialReplyAll={isReplyAll}
        sendAsUser={sendAsUser}
        accessibleBots={accessibleBots}
        currentUser={currentUser}
        onSendAsChange={setSendAsUser}
      />

      {/* Delete confirmation modal. Was a hand-rolled overlay div using
          message-inbox-modal-* classes that never had matching CSS rules
          after the Jan 2026 inline-styles → BEM refactor (commit 9c6e30ab6) —
          which is why the modal rendered inline at the bottom of the page
          instead of as a centered overlay. Swapped to the shared
          ConfirmActionModal so this can't drift out of sync again. */}
      <ConfirmActionModal
        isOpen={deleteConfirmOpen}
        onClose={cancelDelete}
        onConfirm={confirmDelete}
        title="Delete Message"
        message="Are you sure you want to permanently delete this message? This action cannot be undone."
        confirmLabel="Delete"
        confirmStyle="danger"
      />
    </div>
  )
}

export default MessageInbox

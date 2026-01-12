import React from 'react'
import DOMPurify from 'dompurify'
import MessageList from '../MessageList'
import MessageModal from '../MessageModal'
import ParseLinks from '../ParseLinks'

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
  const [showFilters, setShowFilters] = React.useState(false) // Collapsible filter panel

  // Bot and usergroup data from server
  const accessibleBots = data.accessibleBots || []
  const usergroupsWithMessages = data.usergroupsWithMessages || []
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

  // Build API params based on current filters
  const buildApiParams = React.useCallback((tab, archived, pageNum) => {
    const params = new URLSearchParams()
    params.set('limit', pageSize.toString())

    if (tab === 'outbox') {
      params.set('outbox', '1')
    } else {
      if (archived) params.set('archive', '1')
      if (viewingBot) params.set('for_user', viewingBot.node_id.toString())
      if (filterUsergroup) params.set('for_usergroup', filterUsergroup.node_id.toString())
    }

    if (pageNum > 0) params.set('offset', (pageNum * pageSize).toString())

    return params.toString()
  }, [pageSize, viewingBot, filterUsergroup])

  // Load messages when tab, archive filter, or page changes
  const loadMessages = React.useCallback(async (tab, archived, pageNum, botUser = viewingBot, ugFilter = filterUsergroup) => {
    setLoading(true)
    setError(null)

    try {
      const params = new URLSearchParams()
      params.set('limit', pageSize.toString())

      if (tab === 'outbox') {
        params.set('outbox', '1')
      } else {
        if (archived) params.set('archive', '1')
        if (botUser) params.set('for_user', botUser.node_id.toString())
        if (ugFilter) params.set('for_usergroup', ugFilter.node_id.toString())
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

      // Fetch counts based on tab
      if (tab === 'inbox') {
        const countParams = new URLSearchParams()
        if (botUser) countParams.set('for_user', botUser.node_id.toString())
        if (ugFilter) countParams.set('for_usergroup', ugFilter.node_id.toString())

        // Fetch active count
        const activeResponse = await fetch(`/api/messages/count?${countParams.toString()}`, { credentials: 'include' })
        if (activeResponse.ok) {
          const activeData = await activeResponse.json()
          setTotalCount(activeData.count)
        }

        // Fetch archived count
        countParams.set('archive', '1')
        const archivedResponse = await fetch(`/api/messages/count?${countParams.toString()}`, { credentials: 'include' })
        if (archivedResponse.ok) {
          const archivedData = await archivedResponse.json()
          setArchivedCount(archivedData.count)
        }
      } else {
        // Fetch outbox count
        const outboxResponse = await fetch('/api/messages/count?outbox=1', { credentials: 'include' })
        if (outboxResponse.ok) {
          const outboxData = await outboxResponse.json()
          setOutboxCount(outboxData.count)
        }
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [pageSize, viewingBot, filterUsergroup])

  // Handle tab change
  const handleTabChange = (tab) => {
    if (tab !== activeTab) {
      setActiveTab(tab)
      setShowArchived(false)
      setPage(0)
      // Clear bot view when switching to outbox
      if (tab === 'outbox') {
        setViewingBot(null)
        setFilterUsergroup(null)
      }
      loadMessages(tab, false, 0, tab === 'outbox' ? null : viewingBot, tab === 'outbox' ? null : filterUsergroup)
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
    // When viewing bot inbox, set sendAsUser to that bot by default
    setSendAsUser(bot)
    loadMessages('inbox', false, 0, bot, filterUsergroup)
  }

  // Handle usergroup filter
  const handleUsergroupFilter = (ug) => {
    setFilterUsergroup(ug)
    setPage(0)
    loadMessages('inbox', showArchived, 0, viewingBot, ug)
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
    return (
      <div key={message.message_id} className="message-inbox-sent-item">
        <div className="message-inbox-sent-timestamp">
          <span>
            {new Date(message.timestamp).toLocaleString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            })}
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

      {/* Filters bar - only show if there are bots or usergroups available */}
      {(accessibleBots.length > 0 || usergroupsWithMessages.length > 0) && (
        <div className="message-inbox-filters">
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="message-inbox-filters-toggle"
          >
            <span>
              <strong>Filters</strong>
              {(viewingBot || filterUsergroup) && (
                <span className="message-inbox-filters-active">
                  {viewingBot && `Viewing: ${viewingBot.title}`}
                  {viewingBot && filterUsergroup && ' • '}
                  {filterUsergroup && `Group: ${filterUsergroup.title}`}
                </span>
              )}
            </span>
            <span>{showFilters ? '▲' : '▼'}</span>
          </button>

          {showFilters && (
            <div className="message-inbox-filters-panel">
              {/* Bot inbox selector */}
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

              {/* Usergroup filter */}
              {usergroupsWithMessages.length > 0 && (
                <div className="message-inbox-filter-group">
                  <label className="message-inbox-filter-label">
                    Filter by Group:
                  </label>
                  <select
                    value={filterUsergroup?.node_id || ''}
                    onChange={(e) => {
                      const ugId = e.target.value
                      if (ugId === '') {
                        handleUsergroupFilter(null)
                      } else {
                        const ug = usergroupsWithMessages.find(u => u.node_id.toString() === ugId)
                        handleUsergroupFilter(ug)
                      }
                    }}
                    className="message-inbox-filter-select"
                  >
                    <option value="">All groups</option>
                    {usergroupsWithMessages.map(ug => (
                      <option key={ug.node_id} value={ug.node_id}>
                        {ug.title}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {/* Clear filters button */}
              {(viewingBot || filterUsergroup) && (
                <div className="message-inbox-filter-clear">
                  <button
                    onClick={() => {
                      setViewingBot(null)
                      setFilterUsergroup(null)
                      setSendAsUser(null)
                      setPage(0)
                      loadMessages('inbox', showArchived, 0, null, null)
                    }}
                    className="message-inbox-clear-btn"
                  >
                    Clear Filters
                  </button>
                </div>
              )}
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

      {/* Delete confirmation modal */}
      {deleteConfirmOpen && (
        <div className="message-inbox-modal-overlay" onClick={cancelDelete}>
          <div className="message-inbox-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="message-inbox-modal-title">
              Delete Message
            </h3>
            <p className="message-inbox-modal-text">
              Are you sure you want to permanently delete this message? This action cannot be undone.
            </p>
            <div className="message-inbox-modal-actions">
              <button onClick={cancelDelete} className="message-inbox-modal-cancel">
                Cancel
              </button>
              <button onClick={confirmDelete} className="message-inbox-modal-confirm">
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default MessageInbox

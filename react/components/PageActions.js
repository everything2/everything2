import React, { useState, useEffect } from 'react'
import { FaStar, FaRegStar, FaBookmark, FaRegBookmark } from 'react-icons/fa'
import { AddToCategoryButton } from './AddToCategoryModal'
import { AddToWeblogButton } from './AddToWeblogModal'

/**
 * PageActions - Global action buttons for a page
 *
 * Renders bookmark, editor cool, add to category, and add to page buttons.
 * Uses global context (window.e2) for user and node information.
 *
 * Previously rendered by page_actions htmlcode in htmlcode.pm via legacy container.
 * Now rendered as a React component in the page header area.
 *
 * Shows buttons based on:
 * - Bookmark: All logged-in users
 * - Editor cool: Editors only, for e2node/superdoc/superdocnolinks/document types
 * - Add to category: All logged-in users (level > 1 or editor)
 * - Add to page (weblog): Logged-in users with weblog permissions, document-family types
 */
const PageActions = () => {
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) return null

  // Get user and node from global context
  const e2 = window.e2 || {}
  const user = e2.user || {}
  const node = e2.node || {}

  // No actions for guests
  if (user.guest) return null

  // Determine which actions to show based on node type and user permissions
  const nodeType = node.type || ''

  // Editor cool types: e2node, superdoc, superdocnolinks, document
  const edcoolTypes = ['e2node', 'superdoc', 'superdocnolinks', 'document']
  const showEdcool = user.editor && edcoolTypes.includes(nodeType)

  // Bookmark: all logged-in users (server will check can_bookmark)
  const showBookmark = !user.guest

  // Category: all logged-in users (level > 1 or editor, server validates)
  const showCategory = !user.guest

  // Weblog: only for document-family types (writeup, draft, document, superdoc, etc.)
  // AND user must have weblog permissions (checked by API)
  // The legacy check was: sqltablelist =~ /document/
  // Document-family types that can be added to weblogs:
  const weblogTypes = ['writeup', 'draft', 'document', 'superdoc', 'superdocnolinks', 'e2node']
  const showWeblog = !user.guest && weblogTypes.includes(nodeType)

  // Nothing to show
  if (!showBookmark && !showEdcool && !showCategory && !showWeblog) {
    return null
  }

  return (
    <div className="page-actions" style={styles.container} data-reader-ignore="true">
      {showEdcool && (
        <EditorCoolButton nodeId={node.node_id} />
      )}
      {showBookmark && (
        <BookmarkButton nodeId={node.node_id} />
      )}
      {showCategory && (
        <AddToCategoryButton
          nodeId={node.node_id}
          nodeTitle={node.title}
          nodeType={nodeType}
          user={user}
        />
      )}
      {showWeblog && (
        <AddToWeblogButton
          nodeId={node.node_id}
          nodeTitle={node.title}
          nodeType={nodeType}
          user={user}
        />
      )}
    </div>
  )
}

/**
 * EditorCoolButton - Toggle editor cool (endorsement) on a node
 * Fetches initial state from server
 */
const EditorCoolButton = ({ nodeId }) => {
  const [isCooled, setIsCooled] = useState(false)
  const [isLoading, setIsLoading] = useState(true)

  // Fetch initial state
  useEffect(() => {
    const fetchState = async () => {
      try {
        const response = await fetch(`/api/cool/edcool/${nodeId}/status`)
        const data = await response.json()
        if (data.success) {
          setIsCooled(data.edcooled)
        }
      } catch (error) {
        console.error('Error fetching editor cool status:', error)
      } finally {
        setIsLoading(false)
      }
    }
    fetchState()
  }, [nodeId])

  const handleToggle = async () => {
    if (isLoading) return
    setIsLoading(true)

    try {
      const response = await fetch(`/api/cool/edcool/${nodeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })

      const data = await response.json()

      if (!data.success) {
        throw new Error(data.error || 'Failed to toggle editor cool')
      }

      setIsCooled(data.edcooled)
    } catch (error) {
      console.error('Error toggling editor cool:', error)
      alert(`Failed to toggle editor cool: ${error.message}`)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <button
      onClick={handleToggle}
      disabled={isLoading}
      title={isCooled ? 'Remove editor cool' : 'Add editor cool (endorsement)'}
      style={{
        ...styles.button,
        color: isCooled ? '#f4d03f' : '#999',
        opacity: isLoading ? 0.5 : 1
      }}
    >
      {isCooled ? <FaStar /> : <FaRegStar />}
    </button>
  )
}

/**
 * BookmarkButton - Toggle bookmark on a node
 * Fetches initial state from server
 */
const BookmarkButton = ({ nodeId }) => {
  const [isBookmarked, setIsBookmarked] = useState(false)
  const [isLoading, setIsLoading] = useState(true)

  // Fetch initial state
  useEffect(() => {
    const fetchState = async () => {
      try {
        const response = await fetch(`/api/cool/bookmark/${nodeId}/status`)
        const data = await response.json()
        if (data.success) {
          setIsBookmarked(data.bookmarked)
        }
      } catch (error) {
        console.error('Error fetching bookmark status:', error)
      } finally {
        setIsLoading(false)
      }
    }
    fetchState()
  }, [nodeId])

  const handleToggle = async () => {
    if (isLoading) return

    // Optimistic update
    const newState = !isBookmarked
    setIsBookmarked(newState)
    setIsLoading(true)

    try {
      const response = await fetch(`/api/cool/bookmark/${nodeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })

      const data = await response.json()

      if (!data.success) {
        throw new Error(data.error || 'Failed to toggle bookmark')
      }

      // Verify server state matches
      if (data.bookmarked !== newState) {
        setIsBookmarked(data.bookmarked)
      }
    } catch (error) {
      // Revert on error
      setIsBookmarked(!newState)
      console.error('Error toggling bookmark:', error)
      alert(`Failed to toggle bookmark: ${error.message}`)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <button
      onClick={handleToggle}
      disabled={isLoading}
      title={isBookmarked ? 'Remove bookmark' : 'Bookmark this page'}
      style={{
        ...styles.button,
        color: isBookmarked ? '#4060b0' : '#999',
        opacity: isLoading ? 0.5 : 1
      }}
    >
      {isBookmarked ? <FaBookmark /> : <FaRegBookmark />}
    </button>
  )
}

const styles = {
  container: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '2px'
  },
  button: {
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    fontSize: '14px',
    padding: '2px 4px',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center'
  }
}

export default PageActions

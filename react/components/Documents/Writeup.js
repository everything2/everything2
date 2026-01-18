import React, { useState } from 'react'
import WriteupDisplay from '../WriteupDisplay'
import E2NodeToolsModal from '../E2NodeToolsModal'
import InlineWriteupEditor from '../InlineWriteupEditor'
import LinkNode from '../LinkNode'
import CategoryDisplay from '../CategoryDisplay'
import { FaTools, FaEdit } from 'react-icons/fa'

/**
 * Writeup Document Component
 *
 * Renders a single writeup page using React-based E2 link parsing.
 * Replaces server-side Mason2 templates with client-side React.
 *
 * Data comes from Everything::Page::writeup->buildReactData()
 *
 * Includes E2 Node Tools button for editors (applies to parent e2node)
 */

/**
 * SoftlinksTable - Displays softlinks from parent e2node in a 4-column table
 * Matches legacy softlink htmlcode behavior
 * - Nodeshell links (unfilled e2nodes) shown with 'nodeshell' class for logged-in users
 *   (CSS makes them red to indicate they need content)
 */
const SoftlinksTable = ({ softlinks, isLoggedIn }) => {
  const numCols = 4

  // Split softlinks into rows of 4
  const rows = []
  for (let i = 0; i < softlinks.length; i += numCols) {
    rows.push(softlinks.slice(i, i + numCols))
  }

  return (
    <nav id="softlinks" aria-label="Related topics" data-reader-ignore="true">
      <table cellPadding="10" cellSpacing="0" border="0" width="100%">
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {row.map((link) => {
                // Apply nodeshell class for unfilled nodes when user is logged in
                // Guests don't see the nodeshell styling (they shouldn't know about empty nodes)
                const isNodeshell = isLoggedIn && link.filled === false
                const className = isNodeshell ? 'nodeshell' : undefined

                return (
                  <td key={link.node_id} className={className}>
                    <LinkNode
                      nodeId={link.node_id}
                      title={link.title}
                      type={link.type || 'e2node'}
                    />
                  </td>
                )
              })}
              {/* Fill remaining cells in last row */}
              {row.length < numCols &&
                Array.from({ length: numCols - row.length }).map((_, i) => (
                  <td key={`empty-${i}`} className="slend">&nbsp;</td>
                ))
              }
            </tr>
          ))}
        </tbody>
      </table>
    </nav>
  )
}

const Writeup = ({ data }) => {
  const [toolsModalOpen, setToolsModalOpen] = useState(false)

  // Check for ?edit=1 query parameter OR start_in_edit_mode from controller (displaytype=edit)
  const urlParams = new URLSearchParams(window.location.search)
  const startInEditMode = urlParams.get('edit') === '1' || data?.start_in_edit_mode
  const [isEditing, setIsEditing] = useState(startInEditMode)

  // Track current doctext for live updates after editing
  const [currentDoctext, setCurrentDoctext] = useState(null)

  if (!data) return <div>Loading...</div>

  const { writeup, user, parent_e2node, existing_draft, categories, parent_categories } = data

  // Check for category_id URL parameter to focus on a specific category
  const focusedCategoryId = urlParams.get('category_id') ? parseInt(urlParams.get('category_id'), 10) : null

  // Use currentDoctext if set (after editing), otherwise use original
  const displayDoctext = currentDoctext !== null ? currentDoctext : writeup?.doctext

  if (!writeup) {
    return <div className="error">Writeup not found</div>
  }

  const isEditor = !!(user && (user.editor || user.is_editor))
  const isGuest = !user || user.guest
  // Use String() to handle type mismatch between number and string node_id
  const isOwnWriteup = !!(user && writeup.author && String(writeup.author.node_id) === String(user.node_id))
  const canEdit = !isGuest && (isEditor || isOwnWriteup)
  const authorName = writeup.author?.title || 'Unknown'
  const showTools = isEditor && parent_e2node
  const softlinks = parent_e2node?.softlinks || []

  // Check if user already has a writeup on the parent e2node
  const parentWriteups = parent_e2node?.group || []
  const userHasWriteup = user && parentWriteups.some(
    wu => wu.author && String(wu.author.node_id) === String(user.node_id)
  )

  // Check if parent e2node is locked
  const isLocked = !!(parent_e2node?.locked)
  const lockReason = parent_e2node?.lock_reason
  const lockUserTitle = parent_e2node?.lock_user_title

  // Show inline editor for adding new writeup if:
  // - User is logged in (not guest)
  // - User doesn't already have a writeup on this e2node
  // - Parent e2node is not locked
  const showAddWriteupEditor = !isGuest && parent_e2node && !userHasWriteup && !isLocked

  return (
    <div className="writeup-page">
      {/* Categories this writeup belongs to */}
      {categories && categories.length > 0 && (
        <CategoryDisplay
          categories={categories}
          focusedCategoryId={focusedCategoryId}
          className="writeup-categories"
        />
      )}

      {/* Categories the parent e2node belongs to (if different from writeup categories) */}
      {parent_categories && parent_categories.length > 0 && (
        <CategoryDisplay
          categories={parent_categories}
          label="Topic in:"
          focusedCategoryId={focusedCategoryId}
          className="writeup-parent-categories"
        />
      )}

      {/* Toolbar - E2 Node Tools for editors, Edit button for editors/owners */}
      {/* data-reader-ignore excludes from reading mode */}
      {(showTools || canEdit) && (
        <nav style={{ textAlign: 'right', marginBottom: '8px', display: 'flex', justifyContent: 'flex-end', gap: '8px' }} aria-label="Editor tools" data-reader-ignore="true">
          {canEdit && !isEditing && (
            <button
              onClick={() => setIsEditing(true)}
              title={isOwnWriteup ? 'Edit your writeup' : `Edit ${authorName}'s writeup`}
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
              <FaEdit />
            </button>
          )}
          {showTools && (
            <button
              onClick={() => setToolsModalOpen(true)}
              title={`Editor node tools (applies to parent: ${parent_e2node.title})`}
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
              <FaTools />
            </button>
          )}
        </nav>
      )}

      {/* Show editor or writeup display - wrapped in <main> for Chrome reading mode */}
      {isEditing ? (
        <aside aria-label="Edit writeup" data-reader-ignore="true">
          <InlineWriteupEditor
            e2nodeId={parent_e2node?.node_id}
            e2nodeTitle={parent_e2node?.title}
            initialContent={displayDoctext || ''}
            writeupId={writeup.node_id}
            writeupAuthor={authorName}
            isOwnWriteup={isOwnWriteup}
            onSave={(newContent) => {
              // Update the displayed content and exit edit mode
              if (newContent !== undefined) {
                setCurrentDoctext(newContent)
              }
              setIsEditing(false)
              // Remove ?edit=1 from URL if present
              if (window.history.replaceState && urlParams.get('edit') === '1') {
                const url = new URL(window.location)
                url.searchParams.delete('edit')
                window.history.replaceState({}, '', url)
              }
            }}
            onCancel={() => {
              setIsEditing(false)
              // Remove ?edit=1 from URL if present
              if (window.history.replaceState && urlParams.get('edit') === '1') {
                const url = new URL(window.location)
                url.searchParams.delete('edit')
                window.history.replaceState({}, '', url)
              }
            }}
          />
        </aside>
      ) : (
        <main className="writeup-main-content" aria-label="Writeup">
          <WriteupDisplay
            writeup={{ ...writeup, doctext: displayDoctext }}
            user={user}
            onEdit={() => setIsEditing(true)}
          />
        </main>
      )}

      {/* Softlinks from parent e2node */}
      {softlinks.length > 0 && (
        <SoftlinksTable softlinks={softlinks} isLoggedIn={!isGuest} />
      )}

      {/* E2 Node Tools Modal (operates on parent e2node) */}
      {showTools && (
        <E2NodeToolsModal
          e2node={parent_e2node}
          isOpen={toolsModalOpen}
          onClose={() => setToolsModalOpen(false)}
          user={user}
        />
      )}

      {/* Locked node warning - shown where "add a writeup" would go */}
      {isLocked && !isGuest && (
        <div className="locked-node-warning" style={{
          backgroundColor: '#fff3cd',
          border: '1px solid #ffc107',
          borderRadius: '4px',
          padding: '12px 16px',
          marginTop: '16px',
          marginBottom: '16px',
          color: '#856404'
        }}>
          <strong>🔒 This node is locked</strong>
          {lockUserTitle && <span> by <em>{lockUserTitle}</em></span>}
          {lockReason && <span>: {lockReason}</span>}
          <div style={{ marginTop: '4px' }}>
            This node is not accepting new contributions at this time.
          </div>
        </div>
      )}

      {/* Inline writeup editor for adding new writeup to parent e2node */}
      {/* data-reader-ignore excludes from reading mode */}
      {showAddWriteupEditor && (
        <aside style={{ marginTop: '24px' }} aria-label="Write a new writeup" data-reader-ignore="true">
          <InlineWriteupEditor
            e2nodeId={parent_e2node.node_id}
            e2nodeTitle={parent_e2node.title}
            initialContent={existing_draft?.doctext || ''}
            draftId={existing_draft?.node_id || null}
            onPublish={(writeupId) => {
              // Redirect to the e2node to show all writeups
              window.location.href = `/title/${encodeURIComponent(parent_e2node.title)}`
            }}
            onCancel={() => {
              // Optional: could hide the editor, but for now do nothing
            }}
          />
        </aside>
      )}
    </div>
  )
}

export default Writeup

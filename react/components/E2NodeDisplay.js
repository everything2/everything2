import React, { useState, useEffect } from 'react'
import WriteupDisplay from './WriteupDisplay'
import LinkNode from './LinkNode'
import E2NodeToolsModal from './E2NodeToolsModal'
import InlineWriteupEditor from './InlineWriteupEditor'
import CategoryDisplay from './CategoryDisplay'
import { InContentAd } from './Layout/GoogleAds'
import { FaTools } from 'react-icons/fa'
import { decodeHtmlEntities } from '../utils/textUtils'

/**
 * E2NodeDisplay - Renders an e2node with all its writeups
 *
 * Structure matches legacy htmlpage e2node_display_page:
 * - E2node title and created by info
 * - All writeups via WriteupDisplay (show_content + displayWriteupInfo)
 * - Softlinks in a 4-column table (legacy softlink htmlcode)
 * - E2 Node Tools button for editors (opens management modal)
 * - Hash navigation: Scrolls to specific writeup by author name (e.g., #AuthorName)
 *
 * Usage:
 *   <E2NodeDisplay e2node={e2nodeData} user={userData} existingDraft={draftData} />
 */
const E2NodeDisplay = ({ e2node, user, existingDraft, startWithToolsModalOpen, bestEntries, categories, focusedCategoryId }) => {
  const [toolsModalOpen, setToolsModalOpen] = useState(!!startWithToolsModalOpen)

  // Handle hash navigation to scroll to specific author's writeup
  // URLs like /title/Node#AuthorName should scroll to that author's writeup
  useEffect(() => {
    if (!e2node || !e2node.group) return

    const hash = window.location.hash
    if (!hash || hash.length <= 1) return

    // Decode the author name from the hash (remove the # prefix)
    const authorName = decodeURIComponent(hash.substring(1))
    if (!authorName) return

    // Find the writeup by this author
    const writeup = e2node.group.find(w => w.author && w.author.title === authorName)
    if (!writeup) return

    // Use setTimeout to ensure React has rendered the elements
    setTimeout(() => {
      // First try to find the anchor element with the author's name
      const anchor = document.querySelector(`a[name="${authorName}"]`)
      if (anchor) {
        anchor.scrollIntoView({ behavior: 'smooth', block: 'start' })
        return
      }

      // Fallback: find the writeup element by ID
      const writeupElement = document.getElementById(`writeup_${writeup.node_id}`)
      if (writeupElement) {
        writeupElement.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    }, 100)
  }, [e2node])

  if (!e2node) return null

  const {
    title,
    group,           // Array of writeups
    softlinks,
    createdby
  } = e2node

  const hasWriteups = group && group.length > 0
  const showTools = user && user.editor  // user.editor is from e2.user

  // Check if user already has a writeup on this node
  // Note: node_id types may differ (string vs int), so use == for comparison
  const userHasWriteup = user && group && group.some(
    writeup => writeup.author && String(writeup.author.node_id) === String(user.node_id)
  )

  // Check if node is locked (prevents new writeups)
  const isLocked = !!e2node.locked
  const lockReason = e2node.lock_reason
  const lockUserTitle = e2node.lock_user_title

  // Show inline editor if logged in, doesn't have writeup yet, and node is not locked
  // Note: user.guest is a boolean from e2.user, NOT user.is_guest (which is from contentData.user)
  const showInlineEditor = user && !user.guest && !userHasWriteup && !isLocked

  return (
    <div className="e2node-display">
      {/* E2node header - title and createdby already displayed by zen.mc #pageheader */}

      {/* E2 Node Tools button for editors - right-aligned icon */}
      {/* data-reader-ignore excludes from reading mode */}
      {showTools && (
        <nav className="e2node-tools-nav" aria-label="Editor tools" data-reader-ignore="true">
          <button
            onClick={() => setToolsModalOpen(true)}
            title="Editor node tools"
            className="e2node-tools-btn"
          >
            <FaTools />
          </button>
        </nav>
      )}

      {/* Categories this e2node belongs to */}
      {categories && categories.length > 0 && (
        <CategoryDisplay
          categories={categories}
          focusedCategoryId={focusedCategoryId}
          className="e2node-categories"
        />
      )}

      {/* Writeups - wrapped in <main> for Chrome reading mode detection */}
      {/* aria-label provides accessible name for landmark navigation */}
      <main className="e2node-writeups" aria-label="Writeups">
        {hasWriteups ? (
          group.map((writeup, index) => (
            <React.Fragment key={writeup.node_id}>
              <WriteupDisplay
                writeup={writeup}
                user={user}
              />
              {/* In-content ad after first writeup (only for guests, when multiple writeups) */}
              {index === 0 && group.length > 1 && user && user.guest && (
                <InContentAd show={true} />
              )}
            </React.Fragment>
          ))
        ) : user && user.guest ? (
          // Guest user nodeshell experience - encourage sign in and offer alternatives
          <GuestNodeshellMessage e2nodeTitle={title} bestEntries={bestEntries} />
        ) : (
          <p className="no-writeups">There are no writeups for this node yet.</p>
        )}
      </main>

      {/* Softlinks - 4-column table matching legacy softlink htmlcode */}
      {softlinks && softlinks.length > 0 && (
        <SoftlinksTable softlinks={softlinks} isLoggedIn={user && !user.guest} />
      )}

      {/* Locked node warning - shown where "add a writeup" would go */}
      {isLocked && (
        <div className="locked-node-warning">
          <strong>🔒 This node is locked</strong>
          {lockUserTitle && <span> by <em>{lockUserTitle}</em></span>}
          {lockReason && <span>: {lockReason}</span>}
          <div className="locked-node-warning-detail">
            This node is not accepting new contributions at this time.
          </div>
        </div>
      )}

      {/* E2 Node Tools Modal */}
      {showTools && (
        <E2NodeToolsModal
          e2node={e2node}
          isOpen={toolsModalOpen}
          onClose={() => setToolsModalOpen(false)}
          user={user}
        />
      )}

      {/* Inline writeup editor - shown for logged-in users without writeup on this node */}
      {/* aria-hidden and data-reader-ignore exclude from reading mode and accessibility tree */}
      {showInlineEditor && (
        <aside className="e2node-inline-editor" aria-label="Write a new writeup" data-reader-ignore="true">
          <InlineWriteupEditor
            e2nodeId={e2node.node_id}
            e2nodeTitle={title}
            initialContent={existingDraft?.doctext || ''}
            draftId={existingDraft?.node_id || null}
            onPublish={(writeupId) => {
              // Reload page to show the new writeup
              window.location.reload()
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

// Show an ad every N items in the best entries list (for guests only)
const NODESHELL_AD_INTERVAL = 4

/**
 * GuestNodeshellMessage - Friendly message for guests viewing nodeshells
 *
 * Shows:
 * - Explanation that this is a user-created topic without content
 * - Call to action to sign in and contribute
 * - Best recent entries as browsing alternatives
 * - Ads interspersed every few entries
 */
const GuestNodeshellMessage = ({ e2nodeTitle, bestEntries = [] }) => {
  return (
    <div className="guest-nodeshell-message">
      <p className="guest-nodeshell-explanation">
        This is a user-created topic that doesn't have any content yet.
      </p>

      <div className="guest-nodeshell-cta">
        <p>
          If you{' '}
          <a href="/?node=login" className="guest-nodeshell-cta-link">Sign In</a>
          , you could add something here.
          {' '}Don't have an account?{' '}
          <a href="/?node=Sign%20Up" className="guest-nodeshell-cta-link">Register here</a>.
        </p>
      </div>

      {bestEntries && bestEntries.length > 0 && (
        <div className="guest-nodeshell-best-entries">
          <h3 className="guest-nodeshell-best-title">
            Or browse some of our highly rated writeups:
          </h3>
          <ul className="guest-nodeshell-best-list">
            {bestEntries.map((entry, index) => (
              <React.Fragment key={entry.writeup_id || entry.node_id}>
                <li className="guest-nodeshell-best-item">
                  <a href={`/node/${entry.node_id}?lastnode_id=0`} className="guest-nodeshell-best-link">
                    {entry.title}
                  </a>
                  {entry.author && (
                    <span className="guest-nodeshell-best-author">
                      {' '}by{' '}
                      <a href={`/user/${encodeURIComponent(entry.author.title)}`}>
                        {entry.author.title}
                      </a>
                    </span>
                  )}
                  {entry.excerpt && (
                    <p className="guest-nodeshell-best-excerpt">{decodeHtmlEntities(entry.excerpt)}</p>
                  )}
                </li>
                {/* Show ad every NODESHELL_AD_INTERVAL items */}
                {(index + 1) % NODESHELL_AD_INTERVAL === 0 && index < bestEntries.length - 1 && (
                  <li className="guest-nodeshell-ad-item">
                    <InContentAd show={true} />
                  </li>
                )}
              </React.Fragment>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

/**
 * SoftlinksTable - Renders softlinks in a 4-column table
 *
 * Matches production Kernel Blue theme behavior:
 * - 4-column table layout
 * - Background color handled by CSS (#softlinks td { background-color: #f8f9f9; })
 * - No inline gradient styles
 * - Sorted by hits descending (highest first)
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

export default E2NodeDisplay

import React, { useState } from 'react'
import WriteupDisplay from './WriteupDisplay'
import LinkNode from './LinkNode'
import E2NodeToolsModal from './E2NodeToolsModal'
import InlineWriteupEditor from './InlineWriteupEditor'
import { FaTools } from 'react-icons/fa'

/**
 * E2NodeDisplay - Renders an e2node with all its writeups
 *
 * Structure matches legacy htmlpage e2node_display_page:
 * - E2node title and created by info
 * - All writeups via WriteupDisplay (show_content + displayWriteupInfo)
 * - Softlinks in a 4-column table (legacy softlink htmlcode)
 * - E2 Node Tools button for editors (opens management modal)
 *
 * Usage:
 *   <E2NodeDisplay e2node={e2nodeData} user={userData} existingDraft={draftData} />
 */
const E2NodeDisplay = ({ e2node, user, existingDraft }) => {
  const [toolsModalOpen, setToolsModalOpen] = useState(false)

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
  const userHasWriteup = user && group && group.some(
    writeup => writeup.author && writeup.author.node_id === user.node_id
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
      {showTools && (
        <div style={{ textAlign: 'right', marginBottom: '8px' }}>
          <button
            onClick={() => setToolsModalOpen(true)}
            title="Editor node tools"
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
        </div>
      )}

      {/* Writeups */}
      <div className="e2node-writeups">
        {hasWriteups ? (
          group.map((writeup) => (
            <WriteupDisplay
              key={writeup.node_id}
              writeup={writeup}
              user={user}
            />
          ))
        ) : (
          <p className="no-writeups">There are no writeups for this node yet.</p>
        )}
      </div>

      {/* Softlinks - 4-column table matching legacy softlink htmlcode */}
      {softlinks && softlinks.length > 0 && (
        <SoftlinksTable softlinks={softlinks} />
      )}

      {/* Locked node warning - shown where "add a writeup" would go */}
      {isLocked && (
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
      {showInlineEditor && (
        <div style={{ marginTop: '24px' }}>
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
 */
const SoftlinksTable = ({ softlinks }) => {
  const numCols = 4

  // Split softlinks into rows of 4
  const rows = []
  for (let i = 0; i < softlinks.length; i += numCols) {
    rows.push(softlinks.slice(i, i + numCols))
  }

  return (
    <div id="softlinks">
      <table cellPadding="10" cellSpacing="0" border="0" width="100%">
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {row.map((link) => (
                <td key={link.node_id}>
                  <LinkNode
                    nodeId={link.node_id}
                    title={link.title}
                    type={link.type || 'e2node'}
                  />
                </td>
              ))}
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
    </div>
  )
}

export default E2NodeDisplay

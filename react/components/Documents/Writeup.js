import React, { useState } from 'react'
import WriteupDisplay from '../WriteupDisplay'
import E2NodeToolsModal from '../E2NodeToolsModal'
import InlineWriteupEditor from '../InlineWriteupEditor'
import LinkNode from '../LinkNode'
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

const Writeup = ({ data }) => {
  const [toolsModalOpen, setToolsModalOpen] = useState(false)
  const [isEditing, setIsEditing] = useState(false)

  if (!data) return <div>Loading...</div>

  const { writeup, user, parent_e2node } = data

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

  return (
    <div className="writeup-page">
      {/* Toolbar - E2 Node Tools for editors, Edit button for editors/owners */}
      {(showTools || canEdit) && (
        <div style={{ textAlign: 'right', marginBottom: '8px', display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
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
        </div>
      )}

      {/* Show editor or writeup display */}
      {isEditing ? (
        <InlineWriteupEditor
          e2nodeId={parent_e2node?.node_id}
          e2nodeTitle={parent_e2node?.title}
          initialContent={writeup.doctext || ''}
          writeupId={writeup.node_id}
          writeupAuthor={authorName}
          isOwnWriteup={isOwnWriteup}
          onSave={() => setIsEditing(false)}
          onCancel={() => setIsEditing(false)}
        />
      ) : (
        <WriteupDisplay writeup={writeup} user={user} onEdit={() => setIsEditing(true)} />
      )}

      {/* Softlinks from parent e2node */}
      {softlinks.length > 0 && (
        <SoftlinksTable softlinks={softlinks} />
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
    </div>
  )
}

export default Writeup

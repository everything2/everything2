import React from 'react'
import WriteupDisplay from './WriteupDisplay'
import LinkNode from './LinkNode'

/**
 * E2NodeDisplay - Renders an e2node with all its writeups
 *
 * Structure matches legacy htmlpage e2node_display_page:
 * - E2node title and created by info
 * - All writeups via WriteupDisplay (show_content + displayWriteupInfo)
 * - Softlinks in a 4-column table (legacy softlink htmlcode)
 *
 * Usage:
 *   <E2NodeDisplay e2node={e2nodeData} user={userData} />
 */
const E2NodeDisplay = ({ e2node, user }) => {
  if (!e2node) return null

  const {
    title,
    group,           // Array of writeups
    softlinks,
    createdby
  } = e2node

  const hasWriteups = group && group.length > 0

  return (
    <div className="e2node-display">
      {/* E2node header - title and createdby already displayed by zen.mc #pageheader */}

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
    </div>
  )
}

/**
 * SoftlinksTable - Renders softlinks in a 4-column table
 *
 * Matches legacy htmlcode softlink structure:
 * - 4-column table layout
 * - Gradient background colors (white to gray) based on position
 * - sw{hits} class for each cell
 */
const SoftlinksTable = ({ softlinks }) => {
  const numCols = 4

  // Calculate gradient color (white to gray based on position)
  const getGradientColor = (index, total) => {
    const maxVal = 255
    const minVal = 170
    const step = total > 0 ? (maxVal - minVal) / total : 0
    const val = Math.round(maxVal - step * index)
    return `rgb(${val}, ${val}, ${val})`
  }

  // Split softlinks into rows of 4
  const rows = []
  for (let i = 0; i < softlinks.length; i += numCols) {
    rows.push(softlinks.slice(i, i + numCols))
  }

  return (
    <div className="softlinks">
      <table cellPadding="10" cellSpacing="0" border="0" width="100%">
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {row.map((link, colIndex) => {
                const globalIndex = rowIndex * numCols + colIndex
                const bgColor = getGradientColor(globalIndex, softlinks.length)

                return (
                  <td
                    key={link.node_id}
                    className={`sw${link.hits}`}
                    style={{ backgroundColor: bgColor }}
                  >
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
    </div>
  )
}

export default E2NodeDisplay

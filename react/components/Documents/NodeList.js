import React from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeList - Reusable component for displaying lists of recent writeups
 *
 * Used by numbered nodelist pages: 25, Everything New Nodes (100),
 * E2N (200), ENN (300), EKN (1024)
 *
 * Features:
 * - Displays writeups with parent e2node, writeuptype, date, author
 * - Editors see hide/unhide buttons for each writeup
 * - Dropdown selector to switch between different list sizes
 * - Striped row styling for readability
 */

const NodeList = ({ data, user }) => {
  const { type, nodelist, records, currentPage } = data
  const isEditor = user?.isEditor || false

  // Page size options and their display labels
  const pageSizeOptions = {
    '25': { label: '25', page: '25' },
    '100': { label: '100', page: 'Everything New Nodes' },
    '200': { label: '200', page: 'E2N' },
    '300': { label: '300', page: 'ENN' },
    '1024': { label: '1024', page: 'EKN' }
  }

  // Page title mapping
  const pageTitles = {
    '25': '25 Most Recent Writeups',
    'everything_new_nodes': 'Everything New Nodes (100)',
    'e2n': 'E2N - Everything2 New (200)',
    'enn': 'ENN - Everything New Nodes (300)',
    'ekn': 'EKN - Everything Killer Nodes (1024)'
  }

  const pageTitle = pageTitles[type] || `${records} Most Recent Writeups`

  return (
    <div className="nodelist">
      <h2>{pageTitle}</h2>

      {/* Page size selector */}
      <div style={{ textAlign: 'right', marginBottom: '10px' }}>
        <form method="post" style={{ display: 'inline' }}>
          <input type="hidden" name="type" value="superdoc" />
          <label htmlFor="nodelist-selector">Show: </label>
          <select
            name="node"
            id="nodelist-selector"
            onChange={(e) => {
              if (e.target.value) {
                window.location.href = `/title/${encodeURIComponent(e.target.value)}`
              }
            }}
            value={currentPage || ''}
          >
            {Object.entries(pageSizeOptions).map(([size, { label, page }]) => (
              <option key={size} value={page}>
                {label}
              </option>
            ))}
          </select>
          <input type="submit" value="go" />
        </form>
      </div>

      {/* Link to Writeups by Type page */}
      <p>
        (see also <LinkNode title="Writeups by Type" type="superdoc" />)
      </p>

      {/* Writeup list table */}
      {nodelist && nodelist.length > 0 ? (
        <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '10px' }}>
          <tbody>
            {nodelist.map((writeup, index) => {
              const isOddRow = index % 2 === 0
              const rowStyle = {
                backgroundColor: isOddRow ? '#f8f9fa' : 'transparent',
                borderBottom: '1px solid #dee2e6'
              }

              return (
                <tr key={writeup.node_id} style={rowStyle} className="contentinfo">
                  {/* Hide/unhide button (editors only) */}
                  {isEditor && (
                    <td style={{ padding: '4px 8px', whiteSpace: 'nowrap' }}>
                      <a
                        href={`?op=${writeup.notnew ? 'unhidewriteup' : 'hidewriteup'}&hidewriteup=${writeup.node_id}`}
                        style={{ fontSize: '0.85em' }}
                      >
                        {writeup.notnew ? '(un-h!)' : '(h?)'}
                      </a>
                    </td>
                  )}

                  {/* Parent e2node + writeuptype */}
                  <td style={{ padding: '4px 8px' }}>
                    <a href={`/e2node/${encodeURIComponent(writeup.parent_title)}`} className="title">
                      {writeup.parent_title}
                    </a>
                    {' '}
                    <a href={`/title/${encodeURIComponent(writeup.parent_title)}#${encodeURIComponent(writeup.author_name)}`}>
                      ({writeup.writeuptype})
                    </a>
                  </td>

                  {/* Publish date */}
                  <td style={{ padding: '4px 8px', whiteSpace: 'nowrap' }}>
                    <span className="date" style={{ fontSize: '0.9em', color: '#666' }}>
                      {writeup.publishtime}
                    </span>
                  </td>

                  {/* Author */}
                  <td style={{ padding: '4px 8px', whiteSpace: 'nowrap' }}>
                    <LinkNode
                      node_id={writeup.author_id}
                      title={writeup.author_name}
                      type="user"
                      className="author"
                    />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      ) : (
        <p>No writeups found.</p>
      )}
    </div>
  )
}

export default NodeList

import React from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

/**
 * What Does What - Admin page listing superdocs and their documentation
 *
 * Lists all superdocs, oppressor_superdocs, restricted_superdocs, and settings
 * with their documentation descriptions. Admin-only.
 */
const WhatDoesWhat = ({ data }) => {
  const { sections, mainDocSettingId, isAdmin } = data

  if (data.error) {
    return <div className="error">{data.error}</div>
  }

  return (
    <div className="what-does-what">
      {mainDocSettingId && isAdmin && (
        <p style={{ textAlign: 'right' }}>
          <LinkNode
            id={mainDocSettingId}
            display="edit/add documentation"
            params={{ displaytype: 'edit' }}
          />
        </p>
      )}

      {sections.map((section) => (
        <div key={section.type}>
          <h1>
            {section.type}
            {isAdmin && section.docSettingId && (
              <>
                {' - '}
                <LinkNode
                  id={section.docSettingId}
                  display="edit documentation"
                />
              </>
            )}
          </h1>

          <table>
            <tbody>
              {section.nodes.map((node, idx) => (
                <tr key={node.node_id} className={idx % 2 === 0 ? 'oddrow' : ''}>
                  <td>
                    <small>
                      <strong>
                        <LinkNode id={node.node_id} display={node.title} />
                      </strong>
                    </small>
                  </td>
                  <td>
                    <small>({node.node_id})</small>
                  </td>
                  <td>
                    {node.documentation ? <ParseLinks text={node.documentation} /> : <em>none</em>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <br />
        </div>
      ))}
    </div>
  )
}

export default WhatDoesWhat

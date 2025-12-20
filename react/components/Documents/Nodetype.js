import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Nodetype - Display page for nodetype nodes
 *
 * Migrated from Everything::Delegation::htmlpage::nodetype_display_page
 * Shows nodetype documentation, permissions, and configuration
 */
const Nodetype = ({ data, user }) => {
  if (!data || !data.nodetype) return null

  const { nodetype, sourceMap } = data
  const isDeveloper = user?.is_developer || user?.is_editor
  const {
    node_id,
    title,
    sql_tables = [],
    extends_nodetype,
    pages = [],
    maintenances = [],
    readers = [],
    writers = [],
    deleters = [],
    restrictdupes,
    verify_edits
  } = nodetype

  // Format restrictdupes value
  const getRestrictDupesText = () => {
    if (restrictdupes === -1) {
      return 'parent'
    }
    return restrictdupes ? 'Yes' : 'No'
  }

  return (
    <div className="nodetype-display">
      {/* List Nodes of Type link */}
      <p>
        <a href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${node_id}`}>
          List Nodes of Type
        </a>
      </p>

      {/* Authorized Readers */}
      <p>
        <strong>Authorized Readers:</strong>{' '}
        {readers.length > 0 ? (
          readers.map((reader, index) => (
            <React.Fragment key={reader.node_id}>
              {index > 0 && ', '}
              <LinkNode nodeId={reader.node_id} title={reader.title} />
            </React.Fragment>
          ))
        ) : (
          <em>none</em>
        )}
      </p>

      {/* Authorized Creators */}
      <p>
        <strong>Authorized Creators:</strong>{' '}
        {writers.length > 0 ? (
          writers.map((writer, index) => (
            <React.Fragment key={writer.node_id}>
              {index > 0 && ', '}
              <LinkNode nodeId={writer.node_id} title={writer.title} />
            </React.Fragment>
          ))
        ) : (
          <em>none</em>
        )}
      </p>

      {/* Authorized Deleters */}
      <p>
        <strong>Authorized Deleters:</strong>{' '}
        {deleters.length > 0 ? (
          deleters.map((deleter, index) => (
            <React.Fragment key={deleter.node_id}>
              {index > 0 && ', '}
              <LinkNode nodeId={deleter.node_id} title={deleter.title} />
            </React.Fragment>
          ))
        ) : (
          <em>none</em>
        )}
      </p>

      {/* Restrict Duplicates */}
      <p>
        <strong>Restrict Duplicates</strong> (identical titles): {getRestrictDupesText()}
      </p>

      {/* Verify Edits */}
      <p>
        <strong>Verify edits to maintain security:</strong>{' '}
        {verify_edits ? 'Yes' : 'No'}
      </p>

      {/* SQL Tables */}
      <p>
        <strong>Sql Table{sql_tables.length > 1 ? 's' : ''}:</strong>{' '}
        {sql_tables.length > 0 ? (
          sql_tables.map((table, index) => (
            <React.Fragment key={table.node_id}>
              {index > 0 && ', '}
              <LinkNode nodeId={table.node_id} title={table.title} />
            </React.Fragment>
          ))
        ) : (
          <em>none</em>
        )}
      </p>

      {/* Extends Nodetype */}
      <p>
        <strong>Extends Nodetype:</strong>{' '}
        {extends_nodetype ? (
          <LinkNode nodeId={extends_nodetype.node_id} title={extends_nodetype.title} />
        ) : (
          <em>none</em>
        )}
      </p>

      {/* Relevant Pages */}
      <p>
        <strong>Relevant pages:</strong>
      </p>
      {pages.length > 0 ? (
        <ul>
          {pages.map((page) => (
            <li key={page.node_id}>
              <LinkNode nodeId={page.node_id} title={page.title} />
            </li>
          ))}
        </ul>
      ) : (
        <p><em>no pages</em></p>
      )}

      {/* Active Maintenances */}
      <p>
        <strong>Active Maintenances:</strong>
      </p>
      {maintenances.length > 0 ? (
        <ul>
          {maintenances.map((maint) => (
            <li key={maint.node_id}>
              <LinkNode nodeId={maint.node_id} title={maint.title} />
            </li>
          ))}
        </ul>
      ) : (
        <p><em>no maintenance functions</em></p>
      )}

      {/* Developer Source Map */}
      {isDeveloper && sourceMap && sourceMap.components && sourceMap.components.length > 0 && (
        <div style={{
          marginTop: '30px',
          padding: '15px',
          backgroundColor: '#fff',
          border: '1px solid #4060b0',
          borderRadius: '4px'
        }}>
          <h3 style={{
            color: '#38495e',
            marginTop: 0,
            marginBottom: '15px',
            fontSize: '16px'
          }}>
            Developer Source Map
          </h3>

          {sourceMap.components.map((component, index) => (
            <div key={index} style={{ marginBottom: index < sourceMap.components.length - 1 ? '15px' : 0 }}>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                marginBottom: '5px'
              }}>
                <span style={{
                  display: 'inline-block',
                  padding: '2px 8px',
                  backgroundColor: '#38495e',
                  color: '#fff',
                  borderRadius: '3px',
                  fontSize: '11px',
                  fontWeight: 'bold',
                  marginRight: '10px',
                  textTransform: 'uppercase'
                }}>
                  {component.type.replace(/_/g, ' ')}
                </span>
                <span style={{ color: '#507898', fontSize: '13px' }}>
                  {component.description}
                </span>
              </div>
              <div style={{
                fontFamily: 'monospace',
                fontSize: '12px',
                padding: '8px 12px',
                backgroundColor: '#f8f9f9',
                border: '1px solid #d3d3d3',
                borderRadius: '3px',
                overflowX: 'auto'
              }}>
                <a
                  href={`${sourceMap.githubRepo}/blob/${sourceMap.branch}/${component.path}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#4060b0', textDecoration: 'none' }}
                >
                  {component.path}
                </a>
              </div>
            </div>
          ))}

          <div style={{
            marginTop: '15px',
            padding: '10px',
            backgroundColor: '#f8f9f9',
            borderRadius: '3px',
            fontSize: '12px',
            color: '#507898'
          }}>
            <strong>Repository:</strong>{' '}
            <a
              href={sourceMap.githubRepo}
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: '#4060b0', textDecoration: 'none' }}
            >
              {sourceMap.githubRepo}
            </a>
            <br />
            <strong>Branch:</strong> {sourceMap.branch}
            <br />
            <strong>Commit:</strong>{' '}
            <code style={{ fontSize: '11px' }}>{sourceMap.commitHash}</code>
          </div>
        </div>
      )}
    </div>
  )
}

export default Nodetype

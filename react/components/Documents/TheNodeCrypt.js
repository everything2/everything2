import React from 'react'

/**
 * TheNodeCrypt - View deleted nodes in the tomb
 *
 * Admin tool for viewing nodes stored in the tomb table after deletion.
 * Allows viewing details and provides resurrection links.
 */
const TheNodeCrypt = ({ data }) => {
  const {
    error,
    node_id,
    items = [],
    count = 0,
    viewing_coffin,
    coffin_id,
    is_resurrected,
    existing_title,
    lab_id,
    fields = [],
    field_count = 0
  } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // Viewing a specific coffin (deleted node details)
  if (Boolean(viewing_coffin)) {
    return (
      <div className="node-crypt coffin-view">
        <h2 style={{ textAlign: 'center' }}>
          <a href={`/?node_id=${node_id}`}>close the coffin</a>
        </h2>

        {Boolean(is_resurrected) && (
          <>
            <h2 style={{ textAlign: 'center', color: 'green' }}>
              This node has already been resurrected!
            </h2>
            <p style={{ textAlign: 'center' }}>
              View it here: <a href={`/?node_id=${coffin_id}`}>{existing_title}</a>
            </p>
          </>
        )}

        {!Boolean(is_resurrected) && lab_id && (
          <h2 style={{ textAlign: 'center' }}>
            <a href={`/?node_id=${lab_id}&olde2nodeid=${coffin_id}`}>RESURRECT</a>
          </h2>
        )}

        <p>items: {field_count}</p>

        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Field</th>
              <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Value</th>
            </tr>
          </thead>
          <tbody>
            {fields.map((field) => (
              <tr key={field.key}>
                <td style={{ padding: '4px', verticalAlign: 'top' }}>
                  <strong>{field.key}</strong>
                </td>
                <td style={{ padding: '4px' }}>
                  {Boolean(field.is_node_id) ? (
                    <a href={`/?node_id=${field.value}`}>{field.resolved_title || field.value}</a>
                  ) : (
                    field.value
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    )
  }

  // List view
  return (
    <div className="node-crypt list-view">
      <p>
        Here is where the nodes come to rest, after being skillfully slain by an
        editor or god. Tell them, if you believe this action was unjust... for
        nodes may live again.
      </p>

      <table style={{ borderCollapse: 'collapse', border: '1px solid #ccc' }}>
        <thead>
          <tr>
            <th style={{ border: '1px solid #ccc', padding: '4px' }}>Node Title</th>
            <th style={{ border: '1px solid #ccc', padding: '4px' }}>Type</th>
            <th style={{ border: '1px solid #ccc', padding: '4px' }}>Author</th>
            <th style={{ border: '1px solid #ccc', padding: '4px' }}>Killa</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.node_id}>
              <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                <a href={`/?node_id=${node_id}&opencoffin=${item.node_id}`}>{item.title}</a>
              </td>
              <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                <a href={`/?node_id=${item.type_id}&lastnode_id=0`}>{item.type_title}</a>
              </td>
              <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                {item.author_id ? (
                  <a href={`/?node_id=${item.author_id}&lastnode_id=0`}>{item.author_title}</a>
                ) : (
                  'none'
                )}
              </td>
              <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                {item.killa_id ? (
                  <a href={`/?node_id=${item.killa_id}&lastnode_id=0`}>{item.killa_title}</a>
                ) : (
                  '—'
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <p>number of items: {count}</p>
      <p style={{ textAlign: 'right' }}><em>In pace requiescant.</em></p>
    </div>
  )
}

export default TheNodeCrypt

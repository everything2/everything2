import React from 'react'

/**
 * TheNodeCrypt - View deleted nodes in the tomb
 *
 * Admin tool for viewing nodes stored in the tomb table after deletion.
 * Allows viewing details and provides resurrection links.
 * Styles are in CSS classes (node-crypt__*)
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
        <h2 className="node-crypt__heading">
          <a href={`/?node_id=${node_id}`}>close the coffin</a>
        </h2>

        {Boolean(is_resurrected) && (
          <>
            <h2 className="node-crypt__heading node-crypt__heading--success">
              This node has already been resurrected!
            </h2>
            <p className="node-crypt__text-center">
              View it here: <a href={`/?node_id=${coffin_id}`}>{existing_title}</a>
            </p>
          </>
        )}

        {!Boolean(is_resurrected) && lab_id && (
          <h2 className="node-crypt__heading">
            <a href={`/?node_id=${lab_id}&olde2nodeid=${coffin_id}`}>RESURRECT</a>
          </h2>
        )}

        <p>items: {field_count}</p>

        <table className="node-crypt__coffin-table">
          <thead>
            <tr>
              <th className="node-crypt__coffin-th">Field</th>
              <th className="node-crypt__coffin-th">Value</th>
            </tr>
          </thead>
          <tbody>
            {fields.map((field) => (
              <tr key={field.key}>
                <td className="node-crypt__coffin-td">
                  <strong>{field.key}</strong>
                </td>
                <td className="node-crypt__coffin-td--value">
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

      <table className="node-crypt__list-table">
        <thead>
          <tr>
            <th className="node-crypt__list-th">Node Title</th>
            <th className="node-crypt__list-th">Type</th>
            <th className="node-crypt__list-th">Author</th>
            <th className="node-crypt__list-th">Killa</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.node_id}>
              <td className="node-crypt__list-td">
                <a href={`/?node_id=${node_id}&opencoffin=${item.node_id}`}>{item.title}</a>
              </td>
              <td className="node-crypt__list-td">
                <a href={`/?node_id=${item.type_id}&lastnode_id=0`}>{item.type_title}</a>
              </td>
              <td className="node-crypt__list-td">
                {item.author_id ? (
                  <a href={`/?node_id=${item.author_id}&lastnode_id=0`}>{item.author_title}</a>
                ) : (
                  'none'
                )}
              </td>
              <td className="node-crypt__list-td">
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
      <p className="node-crypt__text-right"><em>In pace requiescant.</em></p>
    </div>
  )
}

export default TheNodeCrypt

import React from 'react'

/**
 * UsergroupMessageArchiveManager - Manage usergroup message archiving
 *
 * Admin tool for enabling/disabling automatic message archiving for usergroups.
 */
const UsergroupMessageArchiveManager = ({ data }) => {
  const {
    error,
    node_id,
    archive_node_id,
    usergroups = [],
    num_archiving = 0,
    num_not_archiving = 0,
    changes = []
  } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="usergroup-message-archive-manager">
      <p>
        This simple-minded doc just makes it easy to set if usergroups have their
        messages automatically archived. Users can read the messages at the{' '}
        {archive_node_id ? (
          <a href={`/?node_id=${archive_node_id}`}>usergroup message archive</a>
        ) : (
          'usergroup message archive'
        )}{' '}
        superdoc.
      </p>
      <p><small>Complain to N-Wing about problems and/or error messages you get.</small></p>

      <p>
        <strong>Note:</strong> to make a change, you must choose what you want from
        the dropdown menu <strong><big>and</big> check the checkbox next to it</strong>.
        (This is to help reduce accidental changes.)
      </p>

      {/* Show changes if any were made */}
      {changes.length > 0 && (
        <div style={{ marginBottom: '1em', padding: '10px', backgroundColor: '#f0fff0', border: '1px solid #0a0' }}>
          <p>Made {changes.length} change{changes.length === 1 ? '' : 's'}:</p>
          <ul>
            {changes.map((c) => (
              <li key={c.group_id}>
                {c.action === 'enabled' ? 'Enabled' : 'Disabled'} auto-archive for{' '}
                <a href={`/?node_id=${c.group_id}`}>{c.group_title}</a>.
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Stats */}
      <div style={{ marginBottom: '1em' }}>
        <p><strong>Stats:</strong></p>
        <ul>
          {num_not_archiving > 0 && (
            <li>{num_not_archiving} usergroup{num_not_archiving === 1 ? '' : 's'} not archiving</li>
          )}
          {num_archiving > 0 && (
            <li>{num_archiving} usergroup{num_archiving === 1 ? '' : 's'} archiving</li>
          )}
        </ul>
      </div>

      {/* Main form */}
      <form method="POST">
        <input type="hidden" name="node_id" value={node_id} />

        <table style={{ border: '1px solid #ccc', borderCollapse: 'collapse' }}>
          <thead>
            <tr>
              <th style={{ border: '1px solid #ccc', padding: '4px' }}>change this</th>
              <th style={{ border: '1px solid #ccc', padding: '4px' }}>usergroup</th>
              <th style={{ border: '1px solid #ccc', padding: '4px' }}>current status</th>
              <th style={{ border: '1px solid #ccc', padding: '4px' }}><code>/msg</code>s</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th colSpan={4} style={{ border: '1px solid #ccc', padding: '4px' }}>
                u s e r g r o u p s
              </th>
            </tr>
            {usergroups.map((ug) => (
              <tr key={ug.group_id}>
                <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                  <input
                    type="checkbox"
                    name={`umam_sure_id_${ug.group_id}`}
                    value="1"
                  />
                  <select name={`umam_what_id_${ug.group_id}`} defaultValue="0">
                    <option value="0">
                      {ug.is_archiving ? '(stay archiving)' : '(stay not archiving)'}
                    </option>
                    <option value="1">no archiving</option>
                    <option value="2">start archiving</option>
                  </select>
                </td>
                <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                  <a href={`/?node_id=${ug.group_id}`}>{ug.group_title}</a>
                </td>
                <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                  {ug.is_archiving ? 'archiving' : 'not archiving'}
                </td>
                <td style={{ border: '1px solid #ccc', padding: '4px' }}>
                  {archive_node_id && (
                    <a href={`/?node_id=${archive_node_id}&viewgroup=${encodeURIComponent(ug.group_title)}`}>
                      (view)
                    </a>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <p style={{ marginTop: '1em' }}>
          <button
            type="submit"
            style={{
              padding: '6px 15px',
              backgroundColor: '#38495e',
              color: '#fff',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
          >
            Submit
          </button>
        </p>
      </form>
    </div>
  )
}

export default UsergroupMessageArchiveManager

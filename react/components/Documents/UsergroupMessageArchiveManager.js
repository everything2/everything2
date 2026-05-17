import React from 'react'

/**
 * UsergroupMessageArchiveManager - Manage usergroup message archiving
 *
 * Admin tool for enabling/disabling automatic message archiving for usergroups.
 * Styles are in CSS classes (ug-archive__*)
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
        <div className="ug-archive__changes">
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
      <div className="ug-archive__stats">
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

        <table className="ug-archive__table">
          <thead>
            <tr>
              <th className="ug-archive__th">change this</th>
              <th className="ug-archive__th">usergroup</th>
              <th className="ug-archive__th">current status</th>
              <th className="ug-archive__th"><code>/msg</code>s</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th colSpan={4} className="ug-archive__th">
                u s e r g r o u p s
              </th>
            </tr>
            {usergroups.map((ug) => (
              <tr key={ug.group_id}>
                <td className="ug-archive__td">
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
                <td className="ug-archive__td">
                  <a href={`/?node_id=${ug.group_id}`}>{ug.group_title}</a>
                </td>
                <td className="ug-archive__td">
                  {ug.is_archiving ? 'archiving' : 'not archiving'}
                </td>
                <td className="ug-archive__td">
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

        <p className="ug-archive__submit-row">
          <button type="submit" className="ug-archive__btn">
            Submit
          </button>
        </p>
      </form>
    </div>
  )
}

export default UsergroupMessageArchiveManager

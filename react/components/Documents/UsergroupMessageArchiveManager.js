import React, { useState } from 'react'

/**
 * UsergroupMessageArchiveManager - Manage usergroup message archiving
 *
 * Admin tool for enabling/disabling automatic message archiving for usergroups.
 * Submit posts the checked changes to /api/usergroup_message_archive_manager/apply
 * (#4479, Refs #4298) — the page itself is pure-render. Styles: ug-archive__*.
 */
const UsergroupMessageArchiveManager = ({ data }) => {
  const {
    error,
    node_id,
    archive_node_id,
    usergroups: initialUsergroups = [],
    num_archiving: initialNumArchiving = 0,
    num_not_archiving: initialNumNot = 0,
    changes: initialChanges = []
  } = data

  const [usergroups, setUsergroups] = useState(initialUsergroups)
  const [numArchiving, setNumArchiving] = useState(initialNumArchiving)
  const [numNot, setNumNot] = useState(initialNumNot)
  const [changes, setChanges] = useState(initialChanges)
  // per-group selection: group_id -> { sure: bool, action: '0'|'1'|'2' }
  const [selections, setSelections] = useState({})
  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  if (error) {
    return <div className="error-message">{error}</div>
  }

  const selFor = (id) => selections[id] || { sure: false, action: '0' }
  const setSel = (id, patch) =>
    setSelections((prev) => ({ ...prev, [id]: { ...selFor(id), ...patch } }))

  const handleSubmit = async (e) => {
    e.preventDefault()
    // A change counts only when the checkbox is ticked AND a real action is chosen.
    const pending = usergroups
      .map((ug) => ({ group_id: ug.group_id, ...selFor(ug.group_id) }))
      .filter((s) => s.sure && (s.action === '1' || s.action === '2'))
      .map((s) => ({ group_id: s.group_id, action: s.action }))

    setSubmitting(true)
    setErrorMsg('')
    try {
      const res = await fetch('/api/usergroup_message_archive_manager/apply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ changes: pending })
      })
      const result = await res.json()
      if (!res.ok || result.success === 0) {
        setErrorMsg(result.error || 'Something went wrong applying your changes.')
      } else {
        setUsergroups(result.usergroups || [])
        setNumArchiving(result.num_archiving || 0)
        setNumNot(result.num_not_archiving || 0)
        setChanges(result.changes || [])
        setSelections({})
      }
    } catch (err) {
      setErrorMsg('Network error: ' + err.message)
    } finally {
      setSubmitting(false)
    }
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

      {errorMsg && <div className="ug-archive__error error-message">{errorMsg}</div>}

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
          {numNot > 0 && (
            <li>{numNot} usergroup{numNot === 1 ? '' : 's'} not archiving</li>
          )}
          {numArchiving > 0 && (
            <li>{numArchiving} usergroup{numArchiving === 1 ? '' : 's'} archiving</li>
          )}
        </ul>
      </div>

      {/* Main form */}
      <form onSubmit={handleSubmit}>
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
                    checked={selFor(ug.group_id).sure}
                    onChange={(e) => setSel(ug.group_id, { sure: e.target.checked })}
                  />
                  <select
                    name={`umam_what_id_${ug.group_id}`}
                    value={selFor(ug.group_id).action}
                    onChange={(e) => setSel(ug.group_id, { action: e.target.value })}
                  >
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
          <button type="submit" disabled={submitting} className="ug-archive__btn">
            {submitting ? 'Applying…' : 'Submit'}
          </button>
        </p>
      </form>
    </div>
  )
}

export default UsergroupMessageArchiveManager

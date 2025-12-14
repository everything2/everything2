import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * TheOracle - User variable viewer/editor
 *
 * Used by both "The Oracle" and "The Oracle Classic"
 * - Regular mode: Enhanced UI with CE-restricted vars
 * - Classic mode: Raw display, admin only
 */
const TheOracle = ({ data }) => {
  const {
    error,
    classic_mode,
    is_admin,
    is_editor,
    update_result,
    edit_mode,
    search_result,
    ce_help
  } = data

  const [searchUser, setSearchUser] = useState('')
  const [newValue, setNewValue] = useState(edit_mode?.old_value || '')

  const nodeId = window.e2?.node_id || ''

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // Edit mode - show form to edit a specific variable
  if (edit_mode) {
    return (
      <div className="the-oracle">
        <form method="GET">
          <input type="hidden" name="node_id" value={nodeId} />
          <input type="hidden" name="new_user" value={edit_mode.username} />
          <input type="hidden" name="new_var" value={edit_mode.var_name} />

          <p>
            Editing <strong>{edit_mode.username}</strong> - var{' '}
            <strong>{edit_mode.var_name}</strong>
          </p>

          <p>
            <strong>Old Value:</strong> {edit_mode.old_value || <em>(empty)</em>}
          </p>

          <p>
            <strong>New Value:</strong>{' '}
            <input
              type="text"
              name="new_value"
              value={newValue}
              onChange={(e) => setNewValue(e.target.value)}
              size={50}
            />
          </p>

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
            Save
          </button>
        </form>
      </div>
    )
  }

  return (
    <div className="the-oracle">
      {/* Update confirmation */}
      {update_result?.success && (
        <div
          style={{
            marginBottom: '1em',
            padding: '10px',
            backgroundColor: '#e8f5e9',
            border: '1px solid #4caf50',
            borderRadius: '4px'
          }}
        >
          Updated <strong>{update_result.var}</strong> for{' '}
          <strong>{update_result.user}</strong>
        </div>
      )}

      {/* Welcome / Search form */}
      <form method="GET" style={{ marginBottom: '1.5em' }}>
        <input type="hidden" name="node_id" value={nodeId} />

        <p>Welcome to the User Oracle. Please enter a user name</p>

        <input
          type="text"
          name="the_oracle_subject"
          value={searchUser}
          onChange={(e) => setSearchUser(e.target.value)}
          size={30}
        />{' '}
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
          Look Up
        </button>
      </form>

      {/* CE Help text (only for CEs who aren't admins) */}
      {!classic_mode && ce_help && ce_help.length > 0 && (
        <div style={{ marginBottom: '1.5em', fontSize: '0.9em' }}>
          <p>
            As a content editor, you can view an abbreviated list of user settings.
            <br />
            Any given variable will not be displayed unless the user has turned it on
            at least once. 1=on, 0 or blank=off
          </p>
          <dl>
            {ce_help.map((item) => (
              <React.Fragment key={item.var}>
                <dt>
                  <strong>{item.var}</strong>
                </dt>
                <dd>{item.desc}</dd>
              </React.Fragment>
            ))}
          </dl>
        </div>
      )}

      {/* Search results */}
      {search_result && (
        <div>
          <h3>
            Variables for{' '}
            <LinkNode
              node_id={search_result.user_id}
              title={search_result.username}
              type="user"
            />
          </h3>

          <table
            style={{
              borderCollapse: 'collapse',
              width: '100%',
              border: '0',
              cellPadding: '2',
              cellSpacing: '1'
            }}
          >
            <tbody>
              {search_result.vars.map((v, idx) => (
                <tr
                  key={v.key}
                  className={idx % 2 === 0 ? 'oddrow' : 'evenrow'}
                  style={{
                    backgroundColor: idx % 2 === 0 ? '#f8f9f9' : '#fff'
                  }}
                >
                  <td style={{ padding: '4px', verticalAlign: 'top' }}>
                    <strong>{v.key}</strong>
                  </td>
                  <td style={{ padding: '4px', verticalAlign: 'top' }}>=</td>
                  <td style={{ padding: '4px', verticalAlign: 'top' }}>
                    {/* Code formatting for customstyle */}
                    {v.is_code ? (
                      <pre style={{ fontSize: '0.85em', margin: 0 }}>
                        <small>{v.value}</small>
                      </pre>
                    ) : v.is_nodelet_list && v.value ? (
                      // Personal nodelet as list of links
                      <div>
                        {v.value.split(/<br>/i).map(
                          (item, i) =>
                            item && (
                              <div key={i}>
                                [{item}]
                              </div>
                            )
                        )}
                      </div>
                    ) : (
                      // Normal value with CSV spacing
                      <span>{v.value?.toString().replace(/,/g, ', ')}</span>
                    )}

                    {/* Edit link (admin only) */}
                    {Boolean(is_admin) && (
                      <>
                        {' '}
                        <a
                          href={`?node_id=${nodeId}&userEdit=${encodeURIComponent(
                            search_result.username
                          )}&varEdit=${encodeURIComponent(v.key)}`}
                        >
                          edit
                        </a>
                      </>
                    )}

                    {/* IP Hunter link */}
                    {v.ip_hunter_id && v.value && (
                      <>
                        <br />
                        <small>
                          <a
                            href={`?node_id=${v.ip_hunter_id}&hunt_ip=${encodeURIComponent(
                              v.value
                            )}`}
                          >
                            (check other users with this IP)
                          </a>
                        </small>
                      </>
                    )}

                    {/* Resolved single node reference */}
                    {v.resolved_title && !v.resolved_list && (
                      <>
                        <br />
                        <small>
                          (<LinkNode node_id={v.resolved_id} title={v.resolved_title} />)
                        </small>
                      </>
                    )}

                    {/* Resolved list of nodes */}
                    {v.resolved_list && v.resolved_list.length > 0 && (
                      <div style={{ marginTop: '4px' }}>
                        {v.resolved_list.map((item) => (
                          <div key={item.node_id}>
                            {item.missing ? (
                              <span style={{ color: 'red' }}>
                                ERROR: Node {item.node_id} not found!
                              </span>
                            ) : (
                              <LinkNode node_id={item.node_id} title={item.title} />
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default TheOracle

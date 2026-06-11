import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * ShowUserVars - Displays user variables for debugging.
 * Styles in CSS: .show-user-vars__*
 * Admin/Developer tool.
 */
const ShowUserVars = ({ data }) => {
  const { access_denied, message, is_admin, inspect_user, vars_data, user_data, viewvars_mode } = data

  const [username, setUsername] = useState(inspect_user?.title || '')

  if (access_denied) {
    return (
      <div className="show-user-vars">
        <h2 className="show-user-vars__title">Show User Vars</h2>
        <div className="show-user-vars__error-box">
          <p>{message}</p>
        </div>
      </div>
    )
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div className="show-user-vars">
      <h2 className="show-user-vars__title">Show User Vars</h2>

      {viewvars_mode ? (
        <p>
          Showing variables for: <LinkNode nodeId={inspect_user.node_id} title={inspect_user.title} />
        </p>
      ) : is_admin ? (
        <form method="GET" className="show-user-vars__form">
          <input type="hidden" name="node_id" value={nodeId} />
          <label>
            Showing user variables for{' '}
            <input
              type="text"
              name="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="show-user-vars__input"
              size={30}
            />
          </label>{' '}
          <button type="submit" className="show-user-vars__button">
            Show user vars
          </button>
        </form>
      ) : (
        <p>
          <LinkNode nodeId={inspect_user.node_id} title={inspect_user.title} />
        </p>
      )}

      {/* VARS table */}
      <h3 className="show-user-vars__subtitle">VARS</h3>
      <table className="show-user-vars__table">
        <tbody>
          {vars_data.map((item, idx) => (
            <tr key={item.key} className={idx % 2 === 1 ? 'show-user-vars__row--even' : 'show-user-vars__row--odd'}>
              <td className="show-user-vars__key-cell">{item.key}</td>
              <td className="show-user-vars__value-cell">{String(item.value)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* USER table (admin only) */}
      {!!is_admin && user_data.length > 0 && (
        <>
          <h3 className="show-user-vars__subtitle">USER</h3>
          <table className="show-user-vars__table">
            <tbody>
              {user_data.map((item, idx) => (
                <tr key={item.key} className={idx % 2 === 1 ? 'show-user-vars__row--even' : 'show-user-vars__row--odd'}>
                  <td className="show-user-vars__key-cell">{item.key}</td>
                  <td className="show-user-vars__value-cell">{String(item.value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  )
}

export default ShowUserVars

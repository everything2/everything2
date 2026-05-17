import React from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeForbiddance - Admin tool to forbid/unforbid users from creating nodes.
 * Styles in CSS: .node-forbiddance__*
 */
const NodeForbiddance = ({ data }) => {
  const { message, forbidden_users, node_id } = data

  return (
    <div className="node-forbiddance">
      {message && <p className="node-forbiddance__message">{message}</p>}

      <form method="post" className="node-forbiddance__form">
        <input type="hidden" name="node_id" value={node_id} />
        <div className="node-forbiddance__form-group">
          <label className="node-forbiddance__label">
            Forbid user:
            <input type="text" name="forbid" className="node-forbiddance__input" placeholder="Username" />
          </label>
        </div>
        <div className="node-forbiddance__form-group">
          <label className="node-forbiddance__label">
            Reason:
            <input type="text" name="reason" className="node-forbiddance__input" placeholder="Reason for forbiddance" />
          </label>
        </div>
        <button type="submit" className="node-forbiddance__button">Forbid User</button>
      </form>

      <hr className="node-forbiddance__hr" />

      <h3 className="node-forbiddance__subtitle">Currently Forbidden Users</h3>

      {forbidden_users.length === 0 ? (
        <p><em>No users are currently forbidden.</em></p>
      ) : (
        <ul className="node-forbiddance__list">
          {forbidden_users.map((user) => (
            <li key={user.user_id} className="node-forbiddance__list-item">
              <LinkNode nodeId={user.user_id} title={user.user_title} />
              {' '}is forbidden by{' '}
              <LinkNode nodeId={user.forbidder_id} title={user.forbidder_title} />
              {' '}
              <small>
                ({user.reason ? (
                  <span dangerouslySetInnerHTML={{ __html: user.reason }} />
                ) : (
                  <em>No reason given</em>
                )})
              </small>
              {' '}
              <a
                href={`?node_id=${node_id}&unforbid=${user.user_id}`}
                className="node-forbiddance__link"
              >
                unforbid
              </a>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default NodeForbiddance

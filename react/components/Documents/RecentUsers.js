import React from 'react';

/**
 * RecentUsers - Recent user logins display
 * Styles in CSS: .recent-users__*
 *
 * Lists users who have logged in within the last 24 hours with staff indicators.
 */
const RecentUsers = ({ data, e2 }) => {
  const {
    users = [],
    user_count = 0
  } = data;

  const staffLink = '/?node=E2+staff&nodetype=superdoc';

  return (
    <div className="recent-users">
      <p className="recent-users__intro">
        The following is a list of users who have logged in over the last 24 hours.
      </p>

      <div className="recent-users__summary">
        <strong>{user_count}</strong> user{user_count !== 1 ? 's' : ''} logged in within the last 24 hours
      </div>

      {users.length === 0 ? (
        <p className="recent-users__empty">No users have logged in recently.</p>
      ) : (
        <table className="recent-users__table">
          <thead>
            <tr className="recent-users__header-row">
              <th className="recent-users__th recent-users__th-num">#</th>
              <th className="recent-users__th recent-users__th-name">Name</th>
              <th className="recent-users__th recent-users__th-title">Staff</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, index) => (
              <tr key={user.user_id} className={index % 2 === 0 ? 'recent-users__even-row' : 'recent-users__odd-row'}>
                <td className="recent-users__td recent-users__td-num">{index + 1}</td>
                <td className="recent-users__td recent-users__td-name">
                  <a href={`/?node_id=${user.user_id}`} className="recent-users__user-link">
                    {user.username}
                  </a>
                </td>
                <td className="recent-users__td recent-users__td-title">
                  {Boolean(user.is_admin) && (
                    <a href={staffLink} title="e2gods" className="recent-users__badge">@</a>
                  )}
                  {Boolean(user.is_editor) && (
                    <a href={staffLink} title="Content Editors" className="recent-users__badge">$</a>
                  )}
                  {Boolean(user.is_chanop) && (
                    <a href={staffLink} title="chanops" className="recent-users__badge">+</a>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <div className="recent-users__legend">
        <span className="recent-users__legend-item">
          <span className="recent-users__legend-badge">@</span> = e2gods
        </span>
        <span className="recent-users__legend-item">
          <span className="recent-users__legend-badge">$</span> = Content Editors
        </span>
        <span className="recent-users__legend-item">
          <span className="recent-users__legend-badge">+</span> = chanops
        </span>
      </div>
    </div>
  );
};

export default RecentUsers;

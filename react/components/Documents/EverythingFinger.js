import React from 'react';
import LinkNode from '../LinkNode';

/**
 * Everything Finger - Who's online on Everything2
 * Styles in CSS: .e2-finger__*
 *
 * Displays list of currently logged-in users with:
 * - Username and nickname
 * - Status flags (admin @, editor $, developer %, invisible, newbie days)
 * - Current room/location
 */
const EverythingFinger = ({ data }) => {
  const { users = [], total = 0 } = data;

  if (total === 0) {
    return (
      <div className="e2-finger">
        <em>No users are logged in!</em>
      </div>
    );
  }

  return (
    <div className="e2-finger">
      <div className="e2-finger__header">
        <p className="e2-finger__intro">
          There are currently <strong>{total}</strong> user{total !== 1 ? 's' : ''} on Everything2
        </p>
      </div>

      <div className="e2-finger__table-wrapper">
        <table className="e2-finger__table">
          <thead>
            <tr>
              <th className="e2-finger__th">Who</th>
              <th className="e2-finger__th">What</th>
              <th className="e2-finger__th">Where</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, index) => (
              <tr key={user.user_id} className={index % 2 === 0 ? 'e2-finger__row--even' : 'e2-finger__row--odd'}>
                {/* Who - Username */}
                <td className="e2-finger__td">
                  <LinkNode type="user" title={user.username} />
                </td>

                {/* What - Status flags */}
                <td className="e2-finger__td">
                  <div className="e2-finger__flags">
                    {user.flags.map((flag, idx) => (
                      <span key={idx}>
                        {flag.type === 'invisible' && (
                          <span className="e2-finger__invisible-flag">{flag.label}</span>
                        )}
                        {flag.type === 'admin' && (
                          <span className="e2-finger__role-flag" title="Administrator">
                            {flag.label}
                          </span>
                        )}
                        {flag.type === 'editor' && (
                          <span className="e2-finger__role-flag" title="Content Editor">
                            {flag.label}
                          </span>
                        )}
                        {flag.type === 'developer' && (
                          <span className="e2-finger__role-flag" title="Developer">
                            {flag.label}
                          </span>
                        )}
                        {flag.type === 'newbie' && (
                          <span
                            className={flag.highlight ? 'e2-finger__newbie--highlight' : 'e2-finger__newbie'}
                            title={`Account is ${flag.label} days old`}
                          >
                            {flag.label}
                          </span>
                        )}
                      </span>
                    ))}
                  </div>
                </td>

                {/* Where - Current room */}
                <td className="e2-finger__td">
                  {user.room ? (
                    <LinkNode type="room" title={user.room.title} />
                  ) : (
                    <span className="e2-finger__outside">outside</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default EverythingFinger;

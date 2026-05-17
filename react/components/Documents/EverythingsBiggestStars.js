import React from 'react';

export default function EverythingsBiggestStars({ data }) {
  const { users = [], limit = 100 } = data;

  return (
    <div className="biggest-stars">
      <h3>{limit} Most Starred Noders</h3>

      {users.length === 0 ? (
        <p className="biggest-stars__empty">
          No users with stars found
        </p>
      ) : (
        <ol>
          {users.map((user) => (
            <li key={user.node_id}>
              <a href={`/user/${encodeURIComponent(user.title)}?lastnode_id=`}>
                {user.title}
              </a>
              {' '}({user.stars} star{user.stars !== 1 ? 's' : ''})
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

import React from 'react';

export default function EverythingsBestUsers({ data }) {
  const {
    users = [],
    showDevotion = false,
    showAddiction = false,
    showNewUsers = false,
    showRecent = false
  } = data;

  // Sort column based on display options
  const getSortColumn = () => {
    if (showDevotion) return 'devotion';
    if (showAddiction) return 'addiction';
    return 'experience';
  };

  const getSortLabel = () => {
    if (showDevotion) return 'Devotion';
    if (showAddiction) return 'Addiction';
    return 'Experience';
  };

  const sortColumn = getSortColumn();

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <p style={{ textAlign: 'right', fontSize: '0.9em' }}>
        <small>
          <a href="/title/News+for+noders.+Stuff+that+matters.">News for noders. Stuff that matters.</a>
        </small>
      </p>

      <form method="POST" action="" style={{ marginBottom: '20px' }}>
        <input type="hidden" name="node" value="Everything's Best Users" />
        <input type="hidden" name="displaytype" value="" />
        <input type="hidden" name="sexisgood" value="1" />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '15px', alignItems: 'center' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <input
              type="checkbox"
              name="ebu_showdevotion"
              defaultChecked={showDevotion}
            />
            Display by <a href="/title/devotion">devotion</a>
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <input
              type="checkbox"
              name="ebu_showaddiction"
              defaultChecked={showAddiction}
            />
            Display by <a href="/title/addiction">addiction</a>
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <input
              type="checkbox"
              name="ebu_newusers"
              defaultChecked={showNewUsers}
            />
            Show New users
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <input
              type="checkbox"
              name="ebu_showrecent"
              defaultChecked={showRecent}
            />
            Don't show fled users
          </label>

          <input type="hidden" name="gochange" value="foo" />
          <button
            type="submit"
            style={{
              padding: '5px 15px',
              backgroundColor: '#4060b0',
              color: 'white',
              border: 'none',
              borderRadius: '3px',
              cursor: 'pointer'
            }}
          >
            change
          </button>
        </div>
      </form>

      <p style={{ marginBottom: '15px' }}>
        Shake these people's manipulatory appendages. They deserve it.
        <br />
        <em>A drum roll please....</em>
      </p>

      <div style={{ overflowX: 'auto' }}>
        <table
          border="0"
          cellPadding="8"
          cellSpacing="0"
          style={{
            width: '70%',
            margin: '0 auto',
            borderCollapse: 'collapse',
            backgroundColor: '#ffffff'
          }}
        >
          <thead>
            <tr style={{ backgroundColor: '#ffffff' }}>
              <th style={{ textAlign: 'center', padding: '10px' }}></th>
              <th style={{ textAlign: 'left', padding: '10px' }}>User</th>
              <th style={{ textAlign: 'right', padding: '10px' }}>{getSortLabel()}</th>
              <th style={{ textAlign: 'right', padding: '10px' }}># Writeups</th>
              <th style={{ textAlign: 'center', padding: '10px' }}>Rank</th>
              <th style={{ textAlign: 'center', padding: '10px' }}>Level</th>
            </tr>
          </thead>
          <tbody>
            {users.length === 0 ? (
              <tr>
                <td colSpan="6" style={{ textAlign: 'center', padding: '20px', color: '#666' }}>
                  <em>No users found</em>
                </td>
              </tr>
            ) : (
              users.map((user, index) => (
                <tr
                  key={user.node_id}
                  style={{
                    backgroundColor: index % 2 === 0 ? '#ffffff' : '#f9f9f9'
                  }}
                >
                  <td style={{ textAlign: 'center', padding: '8px' }}>
                    <small>{index + 1}</small>
                  </td>
                  <td style={{ padding: '8px' }}>
                    <a href={`/user/${encodeURIComponent(user.title)}?lastnode_id=`}>
                      {user.title}
                    </a>
                  </td>
                  <td style={{ textAlign: 'right', padding: '8px' }}>
                    {sortColumn === 'addiction'
                      ? (user[sortColumn] || 0).toFixed(2)
                      : (user[sortColumn] || 0)
                    }
                  </td>
                  <td style={{ textAlign: 'right', padding: '8px' }}>
                    {user.writeup_count || 0}
                  </td>
                  <td style={{ textAlign: 'center', padding: '8px' }}>
                    {user.level_title || 'Initiate'}
                  </td>
                  <td style={{ textAlign: 'center', padding: '8px' }}>
                    {user.level_value || 0}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

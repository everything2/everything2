import React from 'react';

export default function LevelDistribution({ data }) {
  const { levels = [] } = data;

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <p>
        The following shows the number of active E2 users at each level (based on users logged in over the last month).
      </p>

      {levels.length === 0 ? (
        <p style={{ fontStyle: 'italic', color: '#666' }}>
          No active users found
        </p>
      ) : (
        <table
          align="center"
          style={{
            margin: '20px auto',
            borderCollapse: 'collapse',
            border: '1px solid #ccc'
          }}
        >
          <thead>
            <tr style={{ backgroundColor: '#f0f0f0' }}>
              <th style={{ padding: '10px', border: '1px solid #ccc', textAlign: 'center' }}>
                Level
              </th>
              <th style={{ padding: '10px', border: '1px solid #ccc', textAlign: 'center' }}>
                Title
              </th>
              <th style={{ padding: '10px', border: '1px solid #ccc', textAlign: 'right' }}>
                Number of Users
              </th>
            </tr>
          </thead>
          <tbody>
            {levels.map((levelData, index) => (
              <tr
                key={levelData.level}
                className={index % 2 === 0 ? 'evenrow' : 'oddrow'}
                style={{
                  backgroundColor: index % 2 === 0 ? '#f9f9f9' : 'white'
                }}
              >
                <td style={{ padding: '8px', border: '1px solid #ccc', textAlign: 'center' }}>
                  {levelData.level}
                </td>
                <td style={{ padding: '8px', border: '1px solid #ccc', textAlign: 'center' }}>
                  {levelData.title}
                </td>
                <td style={{ padding: '8px', border: '1px solid #ccc', textAlign: 'right' }}>
                  {levelData.count}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

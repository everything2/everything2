import React from 'react';

export default function EverythingsBestWriteups({ data }) {
  const { writeups = [] } = data;

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h3>Everything's 50 "Most Cooled" Writeups</h3>
      <p style={{ fontStyle: 'italic', color: '#666', marginBottom: '20px' }}>
        (Visible only to staff members)
      </p>

      {writeups.length === 0 ? (
        <p style={{ fontStyle: 'italic', color: '#666' }}>
          No cooled writeups found
        </p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ backgroundColor: '#CCCCCC' }}>
              <th style={{ width: '400px', padding: '8px', textAlign: 'left', border: '1px solid #999' }}>
                Writeup
              </th>
              <th style={{ width: '200px', padding: '8px', textAlign: 'left', border: '1px solid #999' }}>
                Author
              </th>
            </tr>
          </thead>
          <tbody>
            {writeups.map((w) => (
              <tr key={w.writeup_id}>
                <td style={{ padding: '8px', border: '1px solid #ddd' }}>
                  <a href={`/title/${encodeURIComponent(w.writeup_title)}?node_id=${w.writeup_id}`}>
                    {w.writeup_title}
                  </a>
                  {' - '}
                  <a href={`/title/${encodeURIComponent(w.parent_title)}?node_id=${w.parent_id}`}>
                    full
                  </a>
                  {' '}
                  <strong>{w.cooled}C!</strong>
                </td>
                <td style={{ padding: '8px', border: '1px solid #ddd' }}>
                  by{' '}
                  <a href={`/user/${encodeURIComponent(w.author_title)}?lastnode_id=`}>
                    {w.author_title}
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

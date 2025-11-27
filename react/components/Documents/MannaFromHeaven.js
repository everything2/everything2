import React from 'react'
import LinkNode from '../LinkNode'

const MannaFromHeaven = ({ data }) => {
  const { writeups, numdays } = data

  // Calculate totals
  const totalWriteups = writeups.reduce((sum, w) => sum + w.count, 0)

  return (
    <div className="manna-from-heaven">
      <h2>Manna from Heaven</h2>
      <p>
        Writeup activity for Content Editors and e2gods over the last {numdays} days.
      </p>

      <div style={{ marginBottom: '20px' }}>
        <strong>Total writeups: {totalWriteups}</strong>
      </div>

      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr style={{ backgroundColor: '#f0f0f0', borderBottom: '2px solid #ddd' }}>
            <th style={{ textAlign: 'left', padding: '8px' }}>User</th>
            <th style={{ textAlign: 'right', padding: '8px' }}>Writeups</th>
          </tr>
        </thead>
        <tbody>
          {writeups.map(({ username, user_id, count }) => (
            <tr key={user_id} style={{ borderBottom: '1px solid #eee' }}>
              <td style={{ padding: '8px' }}>
                <LinkNode node_id={user_id} title={username} type="user" />
              </td>
              <td style={{ textAlign: 'right', padding: '8px' }}>
                {count}
              </td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr style={{ borderTop: '2px solid #ddd', fontWeight: 'bold' }}>
            <td style={{ padding: '8px' }}>Total</td>
            <td style={{ textAlign: 'right', padding: '8px' }}>{totalWriteups}</td>
          </tr>
        </tfoot>
      </table>

      <div style={{ marginTop: '20px', fontSize: '0.9em', color: '#666' }}>
        <p>
          Change time period:
          {' '}
          <a href="/title/Manna+from+heaven?days=7">7 days</a>
          {' | '}
          <a href="/title/Manna+from+heaven?days=30">30 days</a>
          {' | '}
          <a href="/title/Manna+from+heaven?days=90">90 days</a>
          {' | '}
          <a href="/title/Manna+from+heaven?days=365">365 days</a>
        </p>
      </div>
    </div>
  )
}

export default MannaFromHeaven

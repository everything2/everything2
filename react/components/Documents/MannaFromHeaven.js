import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Manna from Heaven - Staff writeup activity
 * Styles in CSS: .manna-from-heaven__*
 */
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

      <div className="manna-from-heaven__total">
        <strong>Total writeups: {totalWriteups}</strong>
      </div>

      <table className="manna-from-heaven__table">
        <thead>
          <tr className="manna-from-heaven__header-row">
            <th className="manna-from-heaven__th">User</th>
            <th className="manna-from-heaven__th manna-from-heaven__th--right">Writeups</th>
          </tr>
        </thead>
        <tbody>
          {writeups.map(({ username, user_id, count }) => (
            <tr key={user_id} className="manna-from-heaven__row">
              <td className="manna-from-heaven__td">
                <LinkNode node_id={user_id} title={username} type="user" />
              </td>
              <td className="manna-from-heaven__td manna-from-heaven__td--right">
                {count}
              </td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr className="manna-from-heaven__footer-row">
            <td className="manna-from-heaven__td">Total</td>
            <td className="manna-from-heaven__td manna-from-heaven__td--right">{totalWriteups}</td>
          </tr>
        </tfoot>
      </table>

      <div className="manna-from-heaven__time-links">
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

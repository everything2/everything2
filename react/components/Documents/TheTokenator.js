import React, { useState } from 'react'

/**
 * TheTokenator - Admin tool to give tokens to users.
 * Tokens can be used to reset the chatterbox topic.
 * Styles in CSS: .tokenator__*
 */
const TheTokenator = ({ data }) => {
  const { access_denied, results: initialResults } = data

  const [users, setUsers] = useState(['', '', '', '', ''])
  const [results] = useState(initialResults || [])

  if (access_denied) {
    return (
      <div className="tokenator">
        <h2 className="tokenator__title">The Tokenator</h2>
        <div className="tokenator__error-box">
          <p>Access denied. Admins only.</p>
        </div>
      </div>
    )
  }

  const handleUserChange = (index, value) => {
    const newUsers = [...users]
    newUsers[index] = value
    setUsers(newUsers)
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    // Submit form via regular POST (let the server handle it)
    const form = e.target
    form.submit()
  }

  return (
    <div className="tokenator">
      <h2 className="tokenator__title">The Tokenator</h2>

      {results.length > 0 && (
        <div className="tokenator__results-box">
          {results.map((result, idx) => (
            <p
              key={idx}
              className={result.success ? 'tokenator__result--success' : 'tokenator__result--error'}
            >
              {result.message}
            </p>
          ))}
        </div>
      )}

      <form method="POST" onSubmit={handleSubmit}>
        <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />
        <table className="tokenator__table">
          <tbody>
            <tr>
              <th className="tokenator__th">Tokenate these users</th>
            </tr>
            {users.map((user, idx) => (
              <tr key={idx}>
                <td className="tokenator__td">
                  <input
                    type="text"
                    name={`tokenateUser${idx}`}
                    value={user}
                    onChange={(e) => handleUserChange(idx, e.target.value)}
                    className="tokenator__input"
                    placeholder="Username"
                  />
                </td>
              </tr>
            ))}
            <tr>
              <td className="tokenator__td tokenator__td--center">
                <button type="submit" className="tokenator__button">
                  Give Tokens
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </form>
    </div>
  )
}

export default TheTokenator

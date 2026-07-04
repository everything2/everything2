import React, { useState } from 'react'

/**
 * TheTokenator - Admin tool to give tokens to users.
 * Tokens can be used to reset the chatterbox topic.
 * Styles in CSS: .tokenator__*
 */
const TheTokenator = ({ data }) => {
  const { access_denied, results: initialResults } = data

  const [users, setUsers] = useState(['', '', '', '', ''])
  const [results, setResults] = useState(initialResults || [])
  const [loading, setLoading] = useState(false)

  if (access_denied) {
    return (
      <div className="tokenator">
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

  // The give-tokens WRITE moved to POST /api/the_tokenator/tokenate (#4455, Refs #4298);
  // post the usernames and render the per-user results from the response -- no more
  // throwaway full-page form POST.
  const handleSubmit = async (e) => {
    e.preventDefault()
    const names = users.map((u) => u.trim()).filter((u) => u.length)
    if (!names.length) return
    setLoading(true)
    try {
      const res = await fetch('/api/the_tokenator/tokenate', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ users: names }),
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        setResults(json.results || [])
      } else {
        setResults([{ success: 0, message: (json && json.error) || 'Tokenation failed' }])
      }
    } catch (err) {
      setResults([{ success: 0, message: err.message || 'Tokenation failed' }])
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="tokenator">
      <form onSubmit={handleSubmit}>
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
                <button type="submit" className="tokenator__button" disabled={loading}>
                  {loading ? 'Giving…' : 'Give Tokens'}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </form>

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
    </div>
  )
}

export default TheTokenator

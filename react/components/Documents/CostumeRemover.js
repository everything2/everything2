import React, { useState, useCallback } from 'react'

/**
 * CostumeRemover - Admin tool to remove user costumes
 * Styles in CSS: .costume-remover__*
 */
const CostumeRemover = ({ data }) => {
  const [usernames, setUsernames] = useState(['', '', '', '', ''])
  const [processing, setProcessing] = useState(false)
  const [results, setResults] = useState([])

  const handleUsernameChange = useCallback((index, value) => {
    setUsernames(prev => {
      const updated = [...prev]
      updated[index] = value
      return updated
    })
  }, [])

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()

    const usersToProcess = usernames.filter(u => u.trim() !== '')
    if (usersToProcess.length === 0) {
      return
    }

    setProcessing(true)
    setResults([])

    const newResults = []

    for (const username of usersToProcess) {
      try {
        const response = await fetch('/api/costumes/remove', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ username: username.trim() }),
        })

        const result = await response.json()

        if (result.success) {
          newResults.push({
            type: 'success',
            message: result.message,
          })
        } else {
          newResults.push({
            type: 'error',
            message: result.error || `Failed to remove costume from ${username}`,
          })
        }
      } catch (err) {
        newResults.push({
          type: 'error',
          message: `Failed to connect to server for ${username}`,
        })
      }
    }

    setResults(newResults)
    setProcessing(false)

    // Clear the input fields on success
    if (newResults.some(r => r.type === 'success')) {
      setUsernames(['', '', '', '', ''])
    }
  }, [usernames])

  return (
    <div className="costume-remover">
      <div className="costume-remover__header">
        <h1 className="costume-remover__title">Costume Remover</h1>
      </div>

      <div className="costume-remover__description">
        <p>
          This tool deletes the costume variable for selected users. Use it to remove
          abusively or inappropriately named costumes.
        </p>
        <p>
          Users whose costumes are removed will receive a private message from Klaproth
          informing them of the removal.
        </p>
      </div>

      <form onSubmit={handleSubmit}>
        <table className="costume-remover__table">
          <thead>
            <tr>
              <th className="costume-remover__th">Undress these users</th>
            </tr>
          </thead>
          <tbody>
            {usernames.map((username, index) => (
              <tr key={index}>
                <td className="costume-remover__td">
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => handleUsernameChange(index, e.target.value)}
                    className="costume-remover__input"
                    placeholder="Enter username"
                    disabled={processing}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <button
          type="submit"
          className={`costume-remover__button ${processing ? 'costume-remover__button--disabled' : ''}`}
          disabled={processing}
        >
          {processing ? 'Processing...' : 'Remove Costumes'}
        </button>
      </form>

      {results.length > 0 && (
        <div className="costume-remover__results">
          {results.map((result, index) => (
            <div
              key={index}
              className={`costume-remover__result-item costume-remover__result-item--${result.type}`}
            >
              {result.message}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default CostumeRemover

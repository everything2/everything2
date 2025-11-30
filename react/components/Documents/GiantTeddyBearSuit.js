import React, { useState } from 'react'

/**
 * GiantTeddyBearSuit - Admin tool for hugging users with GP grants
 *
 * Migrated from document.pm giant_teddy_bear_suit() delegation function
 *
 * Allows administrators to publicly hug users in the chatterbox and grant them
 * 2 GP each. This is a fun, positive alternative to superbless.
 *
 * Props:
 * - user: Current user object (must be admin)
 */
const GiantTeddyBearSuit = ({ user }) => {
  const [usernames, setUsernames] = useState(['', '', ''])
  const [results, setResults] = useState([])
  const [errors, setErrors] = useState([])
  const [isSubmitting, setIsSubmitting] = useState(false)

  const isAdmin = user?.admin || false

  const handleUsernameChange = (index, value) => {
    const newUsernames = [...usernames]
    newUsernames[index] = value
    setUsernames(newUsernames)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setResults([])
    setErrors([])

    // Filter out empty usernames
    const filteredUsernames = usernames.filter((name) => name.trim() !== '')

    if (filteredUsernames.length === 0) {
      setErrors([{ error: 'Please enter at least one username' }])
      setIsSubmitting(false)
      return
    }

    try {
      const response = await fetch('/api/teddybear/hug', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          usernames: filteredUsernames
        })
      })

      const data = await response.json()

      if (response.ok) {
        setResults(data.results || [])
        setErrors(data.errors || [])
        // Clear the form on success
        setUsernames(['', '', ''])
      } else {
        setErrors([{ error: data.error || 'An error occurred' }])
      }
    } catch (error) {
      setErrors([{ error: 'Network error: ' + error.message }])
    } finally {
      setIsSubmitting(false)
    }
  }

  if (!isAdmin) {
    return (
      <div style={{ maxWidth: '800px', margin: '20px auto', padding: '20px' }}>
        <p style={{ fontStyle: 'italic' }}>
          <strong>{user?.title}</strong> has donned the Giant Teddy Bear Suit . . .
        </p>
        <p style={{ marginTop: '20px', color: '#8b0000', fontWeight: 'bold' }}>
          Hands off the bear, bobo.
        </p>
      </div>
    )
  }

  return (
    <div style={{ maxWidth: '800px', margin: '20px auto', padding: '20px' }}>
      <p style={{ fontStyle: 'italic', marginBottom: '20px' }}>
        <strong>{user?.title}</strong> has donned the Giant Teddy Bear Suit . . .
      </p>

      {results.length > 0 && (
        <div
          style={{
            marginBottom: '20px',
            padding: '15px',
            backgroundColor: '#f8f9f9',
            border: '1px solid #d3d3d3',
            borderRadius: '4px'
          }}
        >
          <h3 style={{ marginTop: 0, color: '#38495e' }}>Hug Results</h3>
          {results.map((result, index) => (
            <div key={index} style={{ marginBottom: '5px', color: '#507898' }}>
              ✓ {result.message}
            </div>
          ))}
        </div>
      )}

      {errors.length > 0 && (
        <div
          style={{
            marginBottom: '20px',
            padding: '15px',
            backgroundColor: '#fff5f5',
            border: '1px solid #ff0000',
            borderRadius: '4px'
          }}
        >
          <h3 style={{ marginTop: 0, color: '#8b0000' }}>Errors</h3>
          {errors.map((error, index) => (
            <div key={index} style={{ marginBottom: '5px', color: '#8b0000' }}>
              ✗ {error.error || error.username + ': ' + error.error}
            </div>
          ))}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <table
          border="1"
          style={{
            width: '100%',
            borderCollapse: 'collapse',
            border: '1px solid #d3d3d3'
          }}
        >
          <thead>
            <tr style={{ backgroundColor: '#f8f9f9' }}>
              <th style={{ padding: '10px', textAlign: 'left', color: '#38495e' }}>
                Hug these users
              </th>
            </tr>
          </thead>
          <tbody>
            {usernames.map((username, index) => (
              <tr key={index}>
                <td style={{ padding: '10px' }}>
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => handleUsernameChange(index, e.target.value)}
                    placeholder="Username"
                    style={{
                      width: '100%',
                      padding: '5px',
                      border: '1px solid #d3d3d3',
                      borderRadius: '3px',
                      fontFamily: 'inherit'
                    }}
                    disabled={isSubmitting}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div style={{ marginTop: '15px' }}>
          <button
            type="submit"
            disabled={isSubmitting}
            style={{
              padding: '10px 20px',
              backgroundColor: isSubmitting ? '#c5cdd7' : '#38495e',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: isSubmitting ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: 'bold'
            }}
          >
            {isSubmitting ? 'Hugging...' : 'Hug Users'}
          </button>
        </div>

        <div
          style={{
            marginTop: '20px',
            padding: '15px',
            backgroundColor: '#f8f9f9',
            border: '1px solid #d3d3d3',
            borderRadius: '4px',
            fontSize: '13px',
            color: '#507898'
          }}
        >
          <strong>Note:</strong> The Giant Teddy Bear Suit grants 2 GP to each user and posts a
          public hug message to the chatterbox. Users also receive +1 karma.
        </div>
      </form>
    </div>
  )
}

export default GiantTeddyBearSuit

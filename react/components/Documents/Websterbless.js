import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Websterbless - Tool for rewarding users who suggest corrections to Webster 1913
 * Styles in CSS: .websterbless__*
 *
 * Fixed blessing amount: 3 GP
 * Sends automated thank-you message from Webster 1913
 */
const Websterbless = ({ data }) => {
  const { error, msg_count, webster_id, results: initialResults = [] } = data

  // Prefill the first username from the URL hint (user-tools / spam-detection tool links pass
  // ?prefill_username=…). This is a pure client concern — the server doesn't read or ship it.
  const prefill_username =
    new URLSearchParams(window.location.search).get('prefill_username') || ''

  const [rows, setRows] = useState(
    Array(5)
      .fill(null)
      .map((_, index) => ({
        username: index === 0 ? prefill_username : '',
        writeup: ''
      }))
  )
  const [results, setResults] = useState(initialResults)
  const [loading, setLoading] = useState(false)

  if (error) {
    return (
      <div className="websterbless">
        <div className="websterbless__error-box">{error}</div>
      </div>
    )
  }

  const updateRow = (index, field, value) => {
    const newRows = [...rows]
    newRows[index] = { ...newRows[index], [field]: value }
    setRows(newRows)
  }

  // Submit the blessings to the admin API (#4451) and render the per-user results
  // from the response -- no more server-rendered POST-back.
  const handleSubmit = async (e) => {
    e.preventDefault()
    const blessings = rows
      .filter((r) => r.username.trim())
      .map((r) => ({ user: r.username.trim(), writeup: r.writeup.trim() }))
    if (!blessings.length) return
    setLoading(true)
    try {
      const res = await fetch('/api/websterbless/bless', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ blessings }),
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        setResults(json.results || [])
      } else {
        setResults([{ success: 0, error: (json && json.error) || 'Blessing failed' }])
      }
    } catch (err) {
      setResults([{ success: 0, error: err.message || 'Blessing failed' }])
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="websterbless">
      <div className="websterbless__description">
        <p>A simple tool used to reward users who suggest writeup corrections to Webster 1913.</p>

        <div className="websterbless__note-box">
          <p>
            <strong>Users are blessed with 3 GP</strong> and receive an automated thank-you note
            from Webster 1913:
          </p>
          <blockquote className="websterbless__blockquote">
            <em>
              <LinkNode nodeId={webster_id} title="Webster 1913" /> says re [Writeup name]: Thank
              you! My servants have attended to any errors.
            </em>
          </blockquote>
          <p className="websterbless__note-text">
            Writeup name is optional (this parameter is pure text, it is not checked in any way).
          </p>
        </div>

        {msg_count > 0 && (
          <p>
            Webster 1913 has{' '}
            <a href={`?node_id=${webster_id}&node=Message+Inbox&spy_user=Webster+1913`}>
              {msg_count}
            </a>{' '}
            messages total
          </p>
        )}
      </div>

      <form onSubmit={handleSubmit}>
        <table className="websterbless__table">
          <thead>
            <tr>
              <th className="websterbless__th">Thank these users</th>
              <th className="websterbless__th">Writeup name</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={index}>
                <td className="websterbless__td">
                  <input
                    type="text"
                    name={`webbyblessUser${index}`}
                    value={row.username}
                    onChange={(e) => updateRow(index, 'username', e.target.value)}
                    className="websterbless__input userComplete"
                  />
                </td>
                <td className="websterbless__td">
                  <input
                    type="text"
                    name={`webbyblessNode${index}`}
                    value={row.writeup}
                    onChange={(e) => updateRow(index, 'writeup', e.target.value)}
                    className="websterbless__input"
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <button type="submit" className="websterbless__button" disabled={loading}>
          {loading ? 'Blessing…' : 'Websterbless'}
        </button>
      </form>

      {results.length > 0 && (
        <div className="websterbless__results">
          <h4 className="websterbless__results-title">Results:</h4>
          {results.map((result, index) => (
            <div key={index} className={result.success ? 'websterbless__success' : 'websterbless__result-error'}>
              {result.error ? (
                <span>✗ {result.error}</span>
              ) : (
                <span>✓ {result.message}</span>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default Websterbless

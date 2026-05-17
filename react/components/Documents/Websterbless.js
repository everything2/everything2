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
  const { error, msg_count, webster_id, results: initialResults = [], prefill_username = '' } = data

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

  const handleSubmit = (e) => {
    // Let form submit naturally - page will reload with results
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

      <form method="post" onSubmit={handleSubmit}>
        <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />

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

        <button type="submit" className="websterbless__button">
          Websterbless
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

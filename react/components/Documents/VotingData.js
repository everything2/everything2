import React, { useState } from 'react'

/**
 * VotingData - Admin tool for analyzing voting patterns
 *
 * Allows searching by date range or monthly breakdown.
 * Styles are in CSS classes (voting-data__*)
 */
const VotingData = ({ data }) => {
  const {
    error,
    search_type,
    results = [],
    voteday = '',
    voteday2 = '',
    votemonth = '',
    voteyear = ''
  } = data

  const [formData, setFormData] = useState({
    voteday: voteday,
    voteday2: voteday2,
    votemonth: votemonth,
    voteyear: voteyear
  })

  if (error) {
    return <div className="error-message">{error}</div>
  }

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div className="voting-data">
      {/* Results */}
      {search_type === 'date_range' && results.length > 0 && (
        <div className="voting-data__result-box">
          <strong>Vote Results:</strong> {results[0].count.toLocaleString()} votes
          {results[0].start_date !== results[0].end_date ? (
            <span> from {results[0].start_date} to {results[0].end_date}</span>
          ) : (
            <span> on {results[0].start_date}</span>
          )}
        </div>
      )}

      {search_type === 'monthly' && results.length > 0 && (
        <div className="voting-data__section">
          <h3>Monthly Breakdown</h3>
          <table className="voting-data__table">
            <thead>
              <tr>
                <th className="voting-data__th">Date</th>
                <th className="voting-data__th voting-data__th--right">Votes</th>
              </tr>
            </thead>
            <tbody>
              {results.map((row, idx) => (
                <tr key={row.date} className={idx % 2 === 0 ? 'voting-data__row--even' : 'voting-data__row--odd'}>
                  <td className="voting-data__td">{row.date}</td>
                  <td className="voting-data__td--right">{row.count.toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="voting-data__total-row">
                <td className="voting-data__td">Total</td>
                <td className="voting-data__td--right">
                  {results.reduce((sum, r) => sum + r.count, 0).toLocaleString()}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      )}

      {/* Search Form */}
      <form method="GET">
        <input type="hidden" name="node_id" value={nodeId} />

        <div className="voting-data__section">
          <h3>Date Range Search</h3>
          <div className="voting-data__form-row">
            <label>
              Start Date:{' '}
              <input
                type="text"
                name="voteday"
                value={formData.voteday}
                onChange={handleChange}
                placeholder="YYYY-MM-DD"
                size={12}
              />
            </label>
          </div>
          <div className="voting-data__form-row">
            <label>
              End Date:{' '}
              <input
                type="text"
                name="voteday2"
                value={formData.voteday2}
                onChange={handleChange}
                placeholder="YYYY-MM-DD"
                size={12}
              />
            </label>
          </div>
        </div>

        <div className="voting-data__section">
          <h3>Monthly Breakdown</h3>
          <div className="voting-data__form-row">
            <label>
              Year:{' '}
              <input
                type="text"
                name="voteyear"
                value={formData.voteyear}
                onChange={handleChange}
                placeholder="YYYY"
                size={6}
              />
            </label>
          </div>
          <div className="voting-data__form-row">
            <label>
              Month:{' '}
              <input
                type="text"
                name="votemonth"
                value={formData.votemonth}
                onChange={handleChange}
                placeholder="MM"
                size={4}
              />
            </label>
          </div>
        </div>

        <button type="submit" className="voting-data__submit">
          Search
        </button>
      </form>
    </div>
  )
}

export default VotingData

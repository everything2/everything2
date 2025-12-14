import React, { useState } from 'react'

/**
 * VotingData - Admin tool for analyzing voting patterns
 *
 * Allows searching by date range or monthly breakdown.
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
        <div style={{ marginBottom: '1.5em', padding: '10px', backgroundColor: '#f0f8ff', border: '1px solid #4060b0' }}>
          <strong>Vote Results:</strong> {results[0].count.toLocaleString()} votes
          {results[0].start_date !== results[0].end_date ? (
            <span> from {results[0].start_date} to {results[0].end_date}</span>
          ) : (
            <span> on {results[0].start_date}</span>
          )}
        </div>
      )}

      {search_type === 'monthly' && results.length > 0 && (
        <div style={{ marginBottom: '1.5em' }}>
          <h3>Monthly Breakdown</h3>
          <table style={{ borderCollapse: 'collapse', width: '300px' }}>
            <thead>
              <tr>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #ccc', padding: '4px' }}>Date</th>
                <th style={{ textAlign: 'right', borderBottom: '1px solid #ccc', padding: '4px' }}>Votes</th>
              </tr>
            </thead>
            <tbody>
              {results.map((row, idx) => (
                <tr key={row.date} style={{ backgroundColor: idx % 2 === 0 ? '#fff' : '#f8f9f9' }}>
                  <td style={{ padding: '4px' }}>{row.date}</td>
                  <td style={{ textAlign: 'right', padding: '4px' }}>{row.count.toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr style={{ fontWeight: 'bold', borderTop: '2px solid #ccc' }}>
                <td style={{ padding: '4px' }}>Total</td>
                <td style={{ textAlign: 'right', padding: '4px' }}>
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

        <div style={{ marginBottom: '1.5em' }}>
          <h3>Date Range Search</h3>
          <div style={{ marginBottom: '0.5em' }}>
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
          <div style={{ marginBottom: '0.5em' }}>
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

        <div style={{ marginBottom: '1.5em' }}>
          <h3>Monthly Breakdown</h3>
          <div style={{ marginBottom: '0.5em' }}>
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
          <div style={{ marginBottom: '0.5em' }}>
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

        <button type="submit" style={{
          padding: '6px 15px',
          backgroundColor: '#38495e',
          color: '#fff',
          border: 'none',
          borderRadius: '3px',
          cursor: 'pointer'
        }}>
          Search
        </button>
      </form>
    </div>
  )
}

export default VotingData

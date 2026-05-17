import React, { useState, useEffect } from 'react'

/**
 * SiteTrajectory - Historical site statistics visualization
 * Styles in CSS: .site-trajectory__*
 *
 * Displays monthly statistics for writeups, contributing users, and C!s spent
 * with interactive bar charts scaled to the data.
 *
 * Note: Bar widths are dynamic (computed from data) and must remain inline styles.
 */
const SiteTrajectory = ({ data }) => {
  const { back_to_year: initialYear, current_year: currentYear } = data

  const [trajectoryData, setTrajectoryData] = useState([])
  const [backToYear, setBackToYear] = useState(initialYear || currentYear - 5)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // Calculate maximum values for scaling
  const getMaxValues = (data) => {
    if (!data || data.length === 0) {
      return { maxWriteups: 1, maxUsers: 1, maxCools: 1, maxRatio: 0.1 }
    }

    return {
      maxWriteups: Math.max(...data.map(d => d.writeup_count)),
      maxUsers: Math.max(...data.map(d => d.user_count)),
      maxCools: Math.max(...data.map(d => d.cool_count)),
      maxRatio: Math.max(...data.map(d => parseFloat(d.cnw_ratio) || 0))
    }
  }

  const loadData = async (year) => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch(`/api/trajectory/get_data?back_to_year=${year}`)

      if (!response.ok) {
        throw new Error('Failed to load trajectory data')
      }

      const result = await response.json()
      setTrajectoryData(result.data || [])
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData(backToYear)
  }, [backToYear])

  const handleYearChange = (e) => {
    setBackToYear(parseInt(e.target.value, 10))
  }

  const maxValues = getMaxValues(trajectoryData)

  // Kernel Blue color scheme for bar charts
  const barColors = {
    writeups: '#4060b0',
    users: '#3bb5c3',
    cools: '#9e9',
    ratio: '#507898'
  }

  // Dynamic bar style (width computed from data - must stay inline)
  const getBarStyle = (value, maxValue, color) => ({
    backgroundColor: color,
    padding: '0px',
    display: 'block',
    position: 'absolute',
    left: 0,
    top: 0,
    height: '100%',
    width: maxValue > 0 ? `${(value * 100 / maxValue)}%` : '0%',
    borderRadius: '2px'
  })

  // Generate year options
  const yearOptions = []
  for (let y = currentYear; y >= 1999; y--) {
    yearOptions.push(y)
  }

  if (loading) {
    return (
      <div className="site-trajectory">
        <p>Loading trajectory data...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="site-trajectory">
        <p className="site-trajectory__error">Error: {error}</p>
      </div>
    )
  }

  return (
    <div className="site-trajectory">
      <form className="site-trajectory__form" onSubmit={(e) => e.preventDefault()}>
        <label>
          <strong>Report back to:</strong>
          <select value={backToYear} onChange={handleYearChange} className="site-trajectory__select">
            {yearOptions.map(year => (
              <option key={year} value={year}>
                {year}{year === 1999 ? ' (not suggested)' : ''}
              </option>
            ))}
          </select>
        </label>
      </form>

      <table className="site-trajectory__table">
        <thead>
          <tr>
            <th className="site-trajectory__th">Month</th>
            <th className="site-trajectory__th">New Writeups</th>
            <th className="site-trajectory__th">Contributing Users</th>
            <th className="site-trajectory__th">C!s Spent</th>
            <th className="site-trajectory__th site-trajectory__th--last" title="ratio of all C!s spent to new writeups">
              C!:NW
            </th>
          </tr>
        </thead>
        <tbody>
          {trajectoryData.map((row, index) => {
            const isJanuary = row.month === 1
            const dateLabel = isJanuary
              ? <strong>{row.month}/{row.year}</strong>
              : `${row.month}/${row.year}`

            return (
              <tr key={index}>
                <td className="site-trajectory__td site-trajectory__td--nowrap">{dateLabel}</td>
                <td className="site-trajectory__td">
                  <div className="site-trajectory__bar-container">
                    <span className="site-trajectory__bar-value">{row.writeup_count}</span>
                    <span style={getBarStyle(row.writeup_count, maxValues.maxWriteups, barColors.writeups)} />
                  </div>
                </td>
                <td className="site-trajectory__td">
                  <div className="site-trajectory__bar-container">
                    <span className="site-trajectory__bar-value">{row.user_count}</span>
                    <span style={getBarStyle(row.user_count, maxValues.maxUsers, barColors.users)} />
                  </div>
                </td>
                <td className="site-trajectory__td">
                  <div className="site-trajectory__bar-container">
                    <span className="site-trajectory__bar-value">{row.cool_count}</span>
                    <span style={getBarStyle(row.cool_count, maxValues.maxCools, barColors.cools)} />
                  </div>
                </td>
                <td className="site-trajectory__td site-trajectory__td--last">
                  <div className="site-trajectory__bar-container">
                    <span className="site-trajectory__bar-value">{row.cnw_ratio}</span>
                    <span style={getBarStyle(parseFloat(row.cnw_ratio), maxValues.maxRatio, barColors.ratio)} />
                  </div>
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}

export default SiteTrajectory

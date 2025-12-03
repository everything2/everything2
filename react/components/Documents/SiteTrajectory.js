import React, { useState, useEffect } from 'react'

/**
 * SiteTrajectory - Historical site statistics visualization
 *
 * Displays monthly statistics for writeups, contributing users, and C!s spent
 * with interactive bar charts scaled to the data.
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

  // Kernel Blue color scheme
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    text: '#111111',
    border: '#d3d3d3',
    barWriteups: '#4060b0',
    barUsers: '#3bb5c3',
    barCools: '#9e9',
    barRatio: '#507898'
  }

  const containerStyle = {
    padding: '20px',
    maxWidth: '1200px'
  }

  const formStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: colors.background,
    border: `1px solid ${colors.border}`,
    borderRadius: '4px'
  }

  const selectStyle = {
    padding: '8px',
    marginLeft: '10px',
    marginRight: '10px',
    border: `1px solid ${colors.border}`,
    borderRadius: '3px',
    fontSize: '14px'
  }

  const buttonStyle = {
    padding: '8px 16px',
    backgroundColor: colors.primary,
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '14px'
  }

  const tableStyle = {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '20px'
  }

  const thStyle = {
    backgroundColor: colors.primary,
    color: '#ffffff',
    padding: '12px 8px',
    textAlign: 'left',
    fontSize: '14px',
    fontWeight: 'bold',
    borderRight: `1px solid ${colors.border}`
  }

  const tdStyle = {
    borderBottom: `1px solid ${colors.border}`,
    borderRight: `1px solid ${colors.border}`,
    padding: '8px'
  }

  const barContainerStyle = {
    position: 'relative',
    height: '25px',
    width: '100%'
  }

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

  const valueStyle = {
    display: 'block',
    position: 'absolute',
    left: '5px',
    top: '2px',
    zIndex: 100,
    fontSize: '13px',
    fontWeight: 'bold',
    color: colors.text
  }

  // Generate year options
  const yearOptions = []
  for (let y = currentYear; y >= 1999; y--) {
    yearOptions.push(y)
  }

  if (loading) {
    return (
      <div style={containerStyle}>
        <p>Loading trajectory data...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div style={containerStyle}>
        <p style={{ color: '#8b0000' }}>Error: {error}</p>
      </div>
    )
  }

  return (
    <div style={containerStyle}>
      <form style={formStyle} onSubmit={(e) => e.preventDefault()}>
        <label>
          <strong>Report back to:</strong>
          <select value={backToYear} onChange={handleYearChange} style={selectStyle}>
            {yearOptions.map(year => (
              <option key={year} value={year}>
                {year}{year === 1999 ? ' (not suggested)' : ''}
              </option>
            ))}
          </select>
        </label>
      </form>

      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thStyle}>Month</th>
            <th style={thStyle}>New Writeups</th>
            <th style={thStyle}>Contributing Users</th>
            <th style={thStyle}>C!s Spent</th>
            <th style={{ ...thStyle, borderRight: 'none' }} title="ratio of all C!s spent to new writeups">
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
                <td style={{ ...tdStyle, whiteSpace: 'nowrap' }}>{dateLabel}</td>
                <td style={tdStyle}>
                  <div style={barContainerStyle}>
                    <span style={valueStyle}>{row.writeup_count}</span>
                    <span style={getBarStyle(row.writeup_count, maxValues.maxWriteups, colors.barWriteups)} />
                  </div>
                </td>
                <td style={tdStyle}>
                  <div style={barContainerStyle}>
                    <span style={valueStyle}>{row.user_count}</span>
                    <span style={getBarStyle(row.user_count, maxValues.maxUsers, colors.barUsers)} />
                  </div>
                </td>
                <td style={tdStyle}>
                  <div style={barContainerStyle}>
                    <span style={valueStyle}>{row.cool_count}</span>
                    <span style={getBarStyle(row.cool_count, maxValues.maxCools, colors.barCools)} />
                  </div>
                </td>
                <td style={{ ...tdStyle, borderRight: 'none' }}>
                  <div style={barContainerStyle}>
                    <span style={valueStyle}>{row.cnw_ratio}</span>
                    <span style={getBarStyle(parseFloat(row.cnw_ratio), maxValues.maxRatio, colors.barRatio)} />
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

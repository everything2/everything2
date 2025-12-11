import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * LogArchive - Displays monthly archives of day logs, dream logs, editor logs, and root logs.
 */
const LogArchive = ({ data }) => {
  const {
    month,
    year,
    month_name,
    months,
    years,
    min_year,
    max_year,
    prev_month,
    prev_year,
    next_month,
    next_year,
    prev_month_name,
    next_month_name,
    day_logs = [],
    dream_logs = [],
    editor_logs = [],
    root_logs = []
  } = data

  const [selectedMonth, setSelectedMonth] = useState(month)
  const [selectedYear, setSelectedYear] = useState(year)

  const handleSubmit = (e) => {
    e.preventDefault()
    const params = new URLSearchParams()
    params.set('node_id', window.e2?.node_id || '')
    params.set('m', selectedMonth)
    params.set('y', selectedYear)
    window.location.href = `?${params.toString()}`
  }

  const renderLogTable = (logs, title, emptyMessage) => {
    return (
      <>
        <tr>
          <th colSpan={3} style={styles.sectionHeader}>
            <h3 style={styles.h3}>{title}</h3>
          </th>
        </tr>
        {logs.length > 0 ? (
          <>
            <tr>
              <th style={styles.th}>Title</th>
              <th style={styles.th}>Author</th>
              <th style={{ ...styles.th, textAlign: 'right' }}>Create Time</th>
            </tr>
            {logs.map((log, idx) => (
              <tr key={log.writeup_id} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <LinkNode nodeId={log.parent_id} title={log.parent_title} />{' '}
                  (<LinkNode nodeId={log.writeup_id} title={log.writeup_type} />)
                </td>
                <td style={styles.td}>
                  <LinkNode nodeId={log.author_id} title={log.author_title} />
                </td>
                <td style={{ ...styles.td, textAlign: 'right', whiteSpace: 'nowrap' }}>
                  {log.createtime}
                </td>
              </tr>
            ))}
          </>
        ) : (
          <tr>
            <td colSpan={3} style={styles.td}>
              <em>{emptyMessage}</em>
            </td>
          </tr>
        )}
      </>
    )
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div style={styles.container}>
      {/* Month/Year selector form */}
      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formCenter}>
          <strong>Select Month and Year:</strong>{' '}
          <select
            value={selectedMonth}
            onChange={(e) => setSelectedMonth(parseInt(e.target.value, 10))}
            style={styles.select}
          >
            {months.map((m) => (
              <option key={m.value} value={m.value}>
                {m.label}
              </option>
            ))}
          </select>{' '}
          <select
            value={selectedYear}
            onChange={(e) => setSelectedYear(parseInt(e.target.value, 10))}
            style={styles.select}
          >
            {years.map((y) => (
              <option key={y.value} value={y.value}>
                {y.value}
              </option>
            ))}
          </select>{' '}
          <button type="submit" style={styles.button}>
            Get Logs
          </button>
          <br />
          <div style={styles.navLinks}>
            {prev_year >= min_year && (
              <a href={`?node_id=${nodeId}&m=${prev_month}&y=${prev_year}`}>
                &laquo; {prev_month_name} {prev_year}
              </a>
            )}
            {prev_year >= min_year && next_year <= max_year && ' - '}
            {next_year <= max_year && (
              <a href={`?node_id=${nodeId}&m=${next_month}&y=${next_year}`}>
                {next_month_name} {next_year} &raquo;
              </a>
            )}
          </div>
        </div>
      </form>

      {/* Explanation */}
      <p style={styles.note}>
        <small>
          Writeups are displayed based on their titles, and are sorted by &quot;Create Time&quot;.
          <br />
          Titles and create times do not always match up (i.e., someone can post a daylog for
          &quot;February 28, {year - 10}&quot; today, and that daylog will be displayed in the
          February {year - 10} archive).
        </small>
      </p>

      {/* Log tables */}
      <table style={styles.table}>
        <tbody>
          {renderLogTable(day_logs, 'Day Logs', 'No day logs found')}
          {dream_logs.length > 0 && renderLogTable(dream_logs, 'Dream Logs', '')}
          {renderLogTable(editor_logs, 'Editor Logs', 'No editor logs found')}
          {renderLogTable(root_logs, 'Root Logs', 'No root logs found')}
        </tbody>
      </table>
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  form: {
    marginBottom: '15px'
  },
  formCenter: {
    textAlign: 'center'
  },
  select: {
    padding: '4px 8px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    marginRight: '5px'
  },
  button: {
    padding: '5px 15px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  navLinks: {
    marginTop: '10px'
  },
  note: {
    color: '#507898',
    marginBottom: '15px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse'
  },
  sectionHeader: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    textAlign: 'center',
    padding: '5px'
  },
  h3: {
    margin: '5px 0',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  th: {
    backgroundColor: '#f0f0f0',
    padding: '8px',
    borderBottom: '1px solid #d3d3d3',
    textAlign: 'left',
    fontWeight: 'bold'
  },
  td: {
    padding: '6px 8px',
    borderBottom: '1px solid #e0e0e0'
  },
  oddRow: {
    backgroundColor: '#ffffff'
  },
  evenRow: {
    backgroundColor: '#f8f9f9'
  }
}

export default LogArchive

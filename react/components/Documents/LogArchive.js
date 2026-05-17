import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * LogArchive - Displays monthly archives of day logs, dream logs, editor logs, and root logs.
 * Styles in CSS: .log-archive__*
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
          <th colSpan={3} className="log-archive__section-header">
            <h3 className="log-archive__section-title">{title}</h3>
          </th>
        </tr>
        {logs.length > 0 ? (
          <>
            <tr>
              <th className="log-archive__th">Title</th>
              <th className="log-archive__th">Author</th>
              <th className="log-archive__th log-archive__th--right">Create Time</th>
            </tr>
            {logs.map((log, idx) => (
              <tr key={log.writeup_id} className={idx % 2 === 1 ? 'log-archive__row--even' : 'log-archive__row--odd'}>
                <td className="log-archive__td">
                  <LinkNode nodeId={log.parent_id} title={log.parent_title} />{' '}
                  (<LinkNode nodeId={log.writeup_id} title={log.writeup_type} />)
                </td>
                <td className="log-archive__td">
                  <LinkNode nodeId={log.author_id} title={log.author_title} />
                </td>
                <td className="log-archive__td log-archive__td--right">
                  {log.createtime}
                </td>
              </tr>
            ))}
          </>
        ) : (
          <tr>
            <td colSpan={3} className="log-archive__td">
              <em>{emptyMessage}</em>
            </td>
          </tr>
        )}
      </>
    )
  }

  const nodeId = window.e2?.node_id || ''

  return (
    <div className="log-archive">
      {/* Month/Year selector form */}
      <form onSubmit={handleSubmit} className="log-archive__form">
        <div className="log-archive__form-center">
          <strong>Select Month and Year:</strong>{' '}
          <select
            value={selectedMonth}
            onChange={(e) => setSelectedMonth(parseInt(e.target.value, 10))}
            className="log-archive__select"
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
            className="log-archive__select"
          >
            {years.map((y) => (
              <option key={y.value} value={y.value}>
                {y.value}
              </option>
            ))}
          </select>{' '}
          <button type="submit" className="log-archive__button">
            Get Logs
          </button>
          <div className="log-archive__nav-links">
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
      <p className="log-archive__note">
        <small>
          Writeups are displayed based on their titles, and are sorted by &quot;Create Time&quot;.
          <br />
          Titles and create times do not always match up (i.e., someone can post a daylog for
          &quot;February 28, {year - 10}&quot; today, and that daylog will be displayed in the
          February {year - 10} archive).
        </small>
      </p>

      {/* Log tables */}
      <table className="log-archive__table">
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

export default LogArchive

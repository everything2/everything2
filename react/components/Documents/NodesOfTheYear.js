import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Nodes of the Year - Best writeups by year
 * Shows top writeups for a given year with filtering options
 */
const NodesOfTheYear = ({ data }) => {
  const {
    year: initialYear,
    wutype: initialWutype,
    count: initialCount,
    orderby: initialOrderby,
    writeup_types = [],
    writeups = []
  } = data

  const [year, setYear] = useState(initialYear || 2014)
  const [wutype, setWutype] = useState(initialWutype || 0)
  const [count, setCount] = useState(initialCount || 50)
  const [orderby, setOrderby] = useState(initialOrderby || 'cooled DESC,reputation DESC')

  const handleSubmit = (e) => {
    e.preventDefault()
    // Construct URL with parameters
    const params = new URLSearchParams()
    params.set('year', year)
    params.set('wutype', wutype)
    params.set('count', count)
    params.set('orderby', orderby)
    window.location.href = `?${params.toString()}`
  }

  const formatDate = (dateStr) => {
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
  }

  const orderOptions = [
    { value: 'cooled DESC,reputation DESC', label: 'C!, then reputation' },
    { value: 'reputation DESC', label: 'Reputation' },
    { value: 'publishtime DESC', label: 'Date, most recent first' },
    { value: 'publishtime ASC', label: 'Date, most recent last' }
  ]

  const countOptions = [15, 25, 50, 75, 100, 150, 200, 250, 500]

  return (
    <div style={styles.container}>
      <form onSubmit={handleSubmit} style={styles.form}>
        <fieldset style={styles.fieldset}>
          <legend style={styles.legend}>Choose...</legend>

          <div style={styles.formRow}>
            <label style={styles.label}>
              <strong>Year:</strong>{' '}
              <input
                type="number"
                value={year}
                onChange={(e) => setYear(parseInt(e.target.value) || 2014)}
                size="4"
                maxLength="4"
                style={styles.input}
              />
            </label>

            <label style={styles.label}>
              <strong>Select Writeup Type:</strong>{' '}
              <select
                value={wutype}
                onChange={(e) => setWutype(parseInt(e.target.value))}
                style={styles.select}
              >
                <option value="0">All</option>
                {writeup_types.map((type) => (
                  <option key={type.node_id} value={type.node_id}>
                    {type.title}
                  </option>
                ))}
              </select>
            </label>

            <label style={styles.label}>
              <strong>Number of writeups to display:</strong>{' '}
              <select
                value={count}
                onChange={(e) => setCount(parseInt(e.target.value))}
                style={styles.select}
              >
                {countOptions.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div style={styles.formRow}>
            <label style={styles.label}>
              <strong>Order By:</strong>{' '}
              <select
                value={orderby}
                onChange={(e) => setOrderby(e.target.value)}
                style={styles.select}
              >
                {orderOptions.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </label>

            <button type="submit" style={styles.submitButton}>
              Get Writeups
            </button>
          </div>
        </fieldset>
      </form>

      {writeups.length === 0 ? (
        <p style={styles.emptyState}>No writeups found for the selected filters.</p>
      ) : (
        <table style={styles.table}>
          <thead>
            <tr style={styles.headerRow}>
              <th style={styles.th}>Title</th>
              <th style={styles.th}>Author</th>
              <th style={styles.th}>Published</th>
              <th style={styles.th}>C/rep</th>
            </tr>
          </thead>
          <tbody>
            {writeups.map((wu, index) => (
              <tr key={wu.writeup_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <LinkNode nodeId={wu.parent_id} title={wu.parent_title} />{' '}
                  <span style={styles.type}>({wu.type_title})</span>
                </td>
                <td style={styles.td}>
                  <LinkNode nodeId={wu.author_id} title={wu.author_title} />
                </td>
                <td style={{...styles.td, textAlign: 'right'}}>
                  <small>{formatDate(wu.publishtime)}</small>
                </td>
                <td style={styles.td}>
                  <small>{wu.cooled}/{wu.reputation}</small>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  form: {
    marginBottom: '20px'
  },
  fieldset: {
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '15px',
    backgroundColor: '#f8f9f9'
  },
  legend: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#38495e',
    padding: '0 5px'
  },
  formRow: {
    marginBottom: '12px',
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: '15px'
  },
  label: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '5px'
  },
  input: {
    padding: '4px 8px',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    fontSize: '13px'
  },
  select: {
    padding: '4px 8px',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    fontSize: '13px'
  },
  submitButton: {
    padding: '6px 12px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: '#4060b0',
    color: '#fff',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '600'
  },
  emptyState: {
    fontStyle: 'italic',
    color: '#6c757d',
    textAlign: 'center',
    padding: '20px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px'
  },
  headerRow: {
    backgroundColor: '#38495e',
    color: '#fff'
  },
  th: {
    padding: '10px',
    textAlign: 'left',
    fontWeight: '600',
    fontSize: '13px'
  },
  evenRow: {
    backgroundColor: '#f8f9f9'
  },
  oddRow: {
    backgroundColor: '#fff'
  },
  td: {
    padding: '8px 10px',
    borderBottom: '1px solid #dee2e6',
    fontSize: '13px'
  },
  type: {
    color: '#6c757d',
    fontSize: '12px'
  }
}

export default NodesOfTheYear

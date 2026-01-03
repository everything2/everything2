import React from 'react'

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px',
  },
  th: {
    textAlign: 'left',
    padding: '10px',
    border: '1px solid #ddd',
    backgroundColor: '#f8f9fa',
    fontWeight: 'bold',
  },
  td: {
    padding: '10px',
    border: '1px solid #ddd',
  },
  time: {
    fontSize: '12px',
    color: '#666',
    whiteSpace: 'nowrap',
  },
  pager: {
    display: 'flex',
    justifyContent: 'center',
    gap: '40px',
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
  },
  pagerLink: {
    color: '#007bff',
    textDecoration: 'none',
    padding: '8px 16px',
    border: '1px solid #007bff',
    borderRadius: '4px',
  },
  pagerDisabled: {
    color: '#999',
    padding: '8px 16px',
    border: '1px solid #ddd',
    borderRadius: '4px',
  },
  empty: {
    padding: '20px',
    textAlign: 'center',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
  },
  error: {
    padding: '15px',
    backgroundColor: '#f8d7da',
    color: '#721c24',
    borderRadius: '8px',
    marginBottom: '20px',
  },
}

const TopicArchive = ({ data }) => {
  const archiveData = data || {}
  const {
    entries = [],
    startat = 0,
    pageSize = 50,
    totalCount = 0,
    hasNext,
    hasPrev,
    error,
  } = archiveData

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.header}>
          <h1 style={styles.title}>Topic Archive</h1>
        </div>
        <div style={styles.error}>{error}</div>
      </div>
    )
  }

  const prevStart = Math.max(0, startat - pageSize)
  const nextStart = startat + pageSize

  const rangeStart = startat + 1
  const rangeEnd = Math.min(startat + entries.length, totalCount)

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Topic Archive</h1>
      </div>

      <p>Log of room topic changes from the E2 Gift Shop.</p>

      {entries.length === 0 ? (
        <div style={styles.empty}>No entries found.</div>
      ) : (
        <>
          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th}>Time</th>
                <th style={styles.th}>Details</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, index) => (
                <tr key={index} style={{ backgroundColor: index % 2 === 0 ? '#fff' : '#f8f9fa' }}>
                  <td style={styles.td}>
                    <span style={styles.time}>{entry.time}</span>
                  </td>
                  <td style={styles.td} dangerouslySetInnerHTML={{ __html: entry.details }} />
                </tr>
              ))}
            </tbody>
          </table>

          <div style={styles.pager}>
            {hasPrev ? (
              <a href={`?startat=${prevStart}`} style={styles.pagerLink}>
                Previous ({prevStart + 1}-{startat})
              </a>
            ) : (
              <span style={styles.pagerDisabled}>Previous</span>
            )}

            <span>
              Showing {rangeStart}-{rangeEnd} of {totalCount}
            </span>

            {hasNext ? (
              <a href={`?startat=${nextStart}`} style={styles.pagerLink}>
                Next ({nextStart + 1}-{Math.min(nextStart + pageSize, totalCount)})
              </a>
            ) : (
              <span style={styles.pagerDisabled}>(end of list)</span>
            )}
          </div>
        </>
      )}
    </div>
  )
}

export default TopicArchive

import React from 'react';

export default function Dbtable({ data }) {
  const { table, fields, indexes } = data;

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>Database Table: {table.name}</h1>

      {/* Table Statistics */}
      <div style={styles.statsBox}>
        <p style={styles.statLine}>
          <strong>Engine:</strong> {table.engine}
        </p>
        <p style={styles.statLine}>
          <strong>Approximate Rows:</strong>{' '}
          {table.approx_rows.toLocaleString()}
          {table.engine !== 'MyISAM' && (
            <span style={styles.hint}> (InnoDB estimates may vary)</span>
          )}
        </p>
      </div>

      {/* Fields Section */}
      <div style={styles.section}>
        <h2 style={styles.sectionTitle}>Columns ({fields.length})</h2>
        <div style={styles.tableWrapper}>
          <table style={styles.table}>
            <thead>
              <tr style={styles.headerRow}>
                <th style={styles.th}>Field</th>
                <th style={styles.th}>Type</th>
                <th style={styles.th}>Null</th>
                <th style={styles.th}>Key</th>
                <th style={styles.th}>Default</th>
                <th style={styles.th}>Extra</th>
              </tr>
            </thead>
            <tbody>
              {fields.map((field, idx) => (
                <tr key={field.name} style={idx % 2 === 0 ? styles.evenRow : styles.oddRow}>
                  <td style={styles.td}>
                    <code style={styles.fieldName}>{field.name}</code>
                  </td>
                  <td style={styles.td}>
                    <code>{field.type}</code>
                  </td>
                  <td style={styles.td}>{field.null}</td>
                  <td style={styles.td}>
                    {field.key && <span style={styles.keyBadge}>{field.key}</span>}
                  </td>
                  <td style={styles.td}>
                    {field.default === null ? (
                      <em style={styles.nullValue}>NULL</em>
                    ) : field.default === '' ? (
                      <em style={styles.emptyValue}>(empty)</em>
                    ) : (
                      <code>{field.default}</code>
                    )}
                  </td>
                  <td style={styles.td}>
                    {field.extra && <code style={styles.extra}>{field.extra}</code>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Indexes Section */}
      <div style={styles.section}>
        <h2 style={styles.sectionTitle}>Indexes ({indexes.length})</h2>
        {indexes.length > 0 ? (
          <div style={styles.tableWrapper}>
            <table style={styles.table}>
              <thead>
                <tr style={styles.headerRow}>
                  <th style={styles.th}>Name</th>
                  <th style={styles.th}>Seq</th>
                  <th style={styles.th}>Column</th>
                  <th style={styles.th}>Collation</th>
                  <th style={styles.th}>Cardinality</th>
                  <th style={styles.th}>Sub Part</th>
                  <th style={styles.th}>Packed</th>
                  <th style={styles.th}>Comment</th>
                </tr>
              </thead>
              <tbody>
                {indexes.map((idx, i) => (
                  <tr key={`${idx.key_name}-${idx.seq_in_index}`} style={i % 2 === 0 ? styles.evenRow : styles.oddRow}>
                    <td style={styles.td}>
                      <code style={styles.indexName}>{idx.key_name}</code>
                    </td>
                    <td style={styles.td}>{idx.seq_in_index}</td>
                    <td style={styles.td}>
                      <code>{idx.column_name}</code>
                    </td>
                    <td style={styles.td}>{idx.collation || '-'}</td>
                    <td style={styles.td}>
                      {idx.cardinality !== null ? idx.cardinality.toLocaleString() : '-'}
                    </td>
                    <td style={styles.td}>{idx.sub_part || '-'}</td>
                    <td style={styles.td}>{idx.packed || '-'}</td>
                    <td style={styles.td}>{idx.comment || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p style={styles.noData}>No indexes defined on this table.</p>
        )}
      </div>

      {/* Info Box */}
      <div style={styles.infoBox}>
        <strong>Note:</strong> Table schema modifications should be done through{' '}
        <a href="/?node=SQL%20Prompt">SQL Prompt</a> or database migrations.
        The edit page provides basic node metadata editing only.
      </div>
    </div>
  );
}

const styles = {
  container: {
    padding: '20px',
    fontFamily: 'system-ui, -apple-system, sans-serif',
    maxWidth: '1200px',
    margin: '0 auto',
  },
  title: {
    fontSize: '24px',
    fontWeight: 'bold',
    marginBottom: '20px',
    color: '#111',
  },
  statsBox: {
    backgroundColor: '#f8f9fa',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '15px 20px',
    marginBottom: '30px',
  },
  statLine: {
    margin: '8px 0',
    fontSize: '15px',
    color: '#333',
  },
  hint: {
    fontSize: '13px',
    color: '#666',
    fontStyle: 'italic',
  },
  section: {
    marginBottom: '30px',
  },
  sectionTitle: {
    fontSize: '18px',
    fontWeight: 'bold',
    marginBottom: '15px',
    color: '#333',
    borderBottom: '2px solid #4060b0',
    paddingBottom: '8px',
  },
  tableWrapper: {
    overflowX: 'auto',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px',
    fontFamily: 'monospace',
  },
  headerRow: {
    backgroundColor: '#4060b0',
  },
  th: {
    padding: '10px 12px',
    textAlign: 'left',
    color: 'white',
    fontWeight: 'bold',
    whiteSpace: 'nowrap',
  },
  evenRow: {
    backgroundColor: '#f9f9f9',
  },
  oddRow: {
    backgroundColor: 'white',
  },
  td: {
    padding: '8px 12px',
    borderBottom: '1px solid #dee2e6',
    verticalAlign: 'top',
  },
  fieldName: {
    fontWeight: 'bold',
    color: '#333',
  },
  indexName: {
    fontWeight: 'bold',
    color: '#4060b0',
  },
  keyBadge: {
    backgroundColor: '#ffc107',
    color: '#333',
    padding: '2px 6px',
    borderRadius: '3px',
    fontSize: '11px',
    fontWeight: 'bold',
  },
  nullValue: {
    color: '#999',
  },
  emptyValue: {
    color: '#999',
    fontSize: '12px',
  },
  extra: {
    color: '#28a745',
  },
  noData: {
    color: '#666',
    fontStyle: 'italic',
    padding: '20px',
    textAlign: 'center',
    backgroundColor: '#f5f5f5',
    borderRadius: '4px',
  },
  infoBox: {
    marginTop: '30px',
    padding: '15px',
    backgroundColor: '#e7f3ff',
    border: '1px solid #b6d4fe',
    borderRadius: '4px',
    fontSize: '14px',
    color: '#333',
  },
};

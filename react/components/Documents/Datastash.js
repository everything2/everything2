import React, { useState } from 'react';

export default function Datastash({ data }) {
  const { datastash } = data;
  const [viewMode, setViewMode] = useState('formatted'); // 'formatted' or 'raw'

  // Helper to render JSON data recursively
  const renderValue = (value, depth = 0) => {
    if (value === null) {
      return <span style={styles.nullValue}>null</span>;
    }
    if (value === undefined) {
      return <span style={styles.nullValue}>undefined</span>;
    }
    if (typeof value === 'boolean') {
      return <span style={styles.boolValue}>{value.toString()}</span>;
    }
    if (typeof value === 'number') {
      return <span style={styles.numberValue}>{value}</span>;
    }
    if (typeof value === 'string') {
      return <span style={styles.stringValue}>"{value}"</span>;
    }
    if (Array.isArray(value)) {
      if (value.length === 0) {
        return <span style={styles.emptyArray}>[]</span>;
      }
      return (
        <div style={{ marginLeft: depth > 0 ? '20px' : 0 }}>
          <span style={styles.bracket}>[</span>
          {value.map((item, idx) => (
            <div key={idx} style={{ marginLeft: '20px' }}>
              <span style={styles.arrayIndex}>{idx}:</span> {renderValue(item, depth + 1)}
              {idx < value.length - 1 && <span style={styles.comma}>,</span>}
            </div>
          ))}
          <span style={styles.bracket}>]</span>
          <span style={styles.count}> ({value.length} items)</span>
        </div>
      );
    }
    if (typeof value === 'object') {
      const keys = Object.keys(value);
      if (keys.length === 0) {
        return <span style={styles.emptyObject}>{'{}'}</span>;
      }
      return (
        <div style={{ marginLeft: depth > 0 ? '20px' : 0 }}>
          <span style={styles.bracket}>{'{'}</span>
          {keys.map((key, idx) => (
            <div key={key} style={{ marginLeft: '20px' }}>
              <span style={styles.keyName}>{key}</span>: {renderValue(value[key], depth + 1)}
              {idx < keys.length - 1 && <span style={styles.comma}>,</span>}
            </div>
          ))}
          <span style={styles.bracket}>{'}'}</span>
        </div>
      );
    }
    return <span>{String(value)}</span>;
  };

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>Datastash: {datastash.title}</h1>

      {/* Statistics */}
      <div style={styles.statsBox}>
        <p style={styles.statLine}>
          <strong>Node ID:</strong> {datastash.node_id}
        </p>
        <p style={styles.statLine}>
          <strong>Data Size:</strong> {datastash.vars_length.toLocaleString()} bytes
        </p>
        {datastash.parsed_data && Array.isArray(datastash.parsed_data) && (
          <p style={styles.statLine}>
            <strong>Array Length:</strong> {datastash.parsed_data.length.toLocaleString()} items
          </p>
        )}
      </div>

      {/* View Mode Toggle */}
      <div style={styles.toggleContainer}>
        <button
          onClick={() => setViewMode('formatted')}
          style={{
            ...styles.toggleButton,
            ...(viewMode === 'formatted' ? styles.toggleButtonActive : {})
          }}
        >
          Formatted View
        </button>
        <button
          onClick={() => setViewMode('raw')}
          style={{
            ...styles.toggleButton,
            ...(viewMode === 'raw' ? styles.toggleButtonActive : {})
          }}
        >
          Raw JSON
        </button>
      </div>

      {/* Content Display */}
      <div style={styles.section}>
        <h2 style={styles.sectionTitle}>Data Contents</h2>

        {datastash.parse_error ? (
          <div style={styles.errorBox}>
            <strong>JSON Parse Error:</strong> {datastash.parse_error}
            <div style={styles.rawPreview}>
              <h3>Raw Content (first 1000 chars):</h3>
              <pre style={styles.rawCode}>
                {datastash.vars_raw.substring(0, 1000)}
                {datastash.vars_raw.length > 1000 && '...'}
              </pre>
            </div>
          </div>
        ) : !datastash.vars_raw || datastash.vars_raw === '' ? (
          <p style={styles.noData}>No data stored in this datastash.</p>
        ) : viewMode === 'formatted' ? (
          <div style={styles.formattedView}>
            {renderValue(datastash.parsed_data)}
          </div>
        ) : (
          <pre style={styles.rawCode}>
            {JSON.stringify(datastash.parsed_data, null, 2)}
          </pre>
        )}
      </div>

      {/* Info Box */}
      <div style={styles.infoBox}>
        <strong>Note:</strong> Datastash nodes store cached JSON data for site features.
        The edit page allows direct modification of the raw JSON content.
        Changes should be made carefully as they may affect site functionality.
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
    marginBottom: '20px',
  },
  statLine: {
    margin: '8px 0',
    fontSize: '15px',
    color: '#333',
  },
  toggleContainer: {
    marginBottom: '20px',
    display: 'flex',
    gap: '8px',
  },
  toggleButton: {
    padding: '8px 16px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: 'white',
    color: '#4060b0',
    cursor: 'pointer',
    fontSize: '14px',
  },
  toggleButtonActive: {
    backgroundColor: '#4060b0',
    color: 'white',
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
  formattedView: {
    fontFamily: 'monospace',
    fontSize: '13px',
    backgroundColor: '#f9f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    padding: '15px',
    overflow: 'auto',
    maxHeight: '600px',
  },
  rawCode: {
    fontFamily: 'monospace',
    fontSize: '12px',
    backgroundColor: '#1e1e1e',
    color: '#d4d4d4',
    border: '1px solid #333',
    borderRadius: '4px',
    padding: '15px',
    overflow: 'auto',
    maxHeight: '600px',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-all',
  },
  bracket: {
    color: '#507898',
    fontWeight: 'bold',
  },
  keyName: {
    color: '#4060b0',
    fontWeight: 'bold',
  },
  stringValue: {
    color: '#a31515',
  },
  numberValue: {
    color: '#098658',
  },
  boolValue: {
    color: '#0000ff',
  },
  nullValue: {
    color: '#999',
    fontStyle: 'italic',
  },
  arrayIndex: {
    color: '#666',
    fontSize: '12px',
  },
  comma: {
    color: '#333',
  },
  count: {
    color: '#666',
    fontSize: '12px',
  },
  emptyArray: {
    color: '#999',
  },
  emptyObject: {
    color: '#999',
  },
  errorBox: {
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    padding: '15px',
    color: '#856404',
  },
  rawPreview: {
    marginTop: '15px',
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

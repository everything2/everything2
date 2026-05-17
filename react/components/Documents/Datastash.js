import React, { useState } from 'react';

/**
 * Datastash - Cached JSON data viewer
 * Styles in CSS: .datastash__*
 */
export default function Datastash({ data }) {
  const { datastash } = data;
  const [viewMode, setViewMode] = useState('formatted'); // 'formatted' or 'raw'

  // Helper to render JSON data recursively
  const renderValue = (value, depth = 0) => {
    if (value === null) {
      return <span className="datastash__null-value">null</span>;
    }
    if (value === undefined) {
      return <span className="datastash__null-value">undefined</span>;
    }
    if (typeof value === 'boolean') {
      return <span className="datastash__bool-value">{value.toString()}</span>;
    }
    if (typeof value === 'number') {
      return <span className="datastash__number-value">{value}</span>;
    }
    if (typeof value === 'string') {
      return <span className="datastash__string-value">"{value}"</span>;
    }
    if (Array.isArray(value)) {
      if (value.length === 0) {
        return <span className="datastash__empty-array">[]</span>;
      }
      return (
        <div className={depth > 0 ? 'datastash__nested' : undefined}>
          <span className="datastash__bracket">[</span>
          {value.map((item, idx) => (
            <div key={idx} className="datastash__nested">
              <span className="datastash__array-index">{idx}:</span> {renderValue(item, depth + 1)}
              {idx < value.length - 1 && <span className="datastash__comma">,</span>}
            </div>
          ))}
          <span className="datastash__bracket">]</span>
          <span className="datastash__count"> ({value.length} items)</span>
        </div>
      );
    }
    if (typeof value === 'object') {
      const keys = Object.keys(value);
      if (keys.length === 0) {
        return <span className="datastash__empty-object">{'{}'}</span>;
      }
      return (
        <div className={depth > 0 ? 'datastash__nested' : undefined}>
          <span className="datastash__bracket">{'{'}</span>
          {keys.map((key, idx) => (
            <div key={key} className="datastash__nested">
              <span className="datastash__key-name">{key}</span>: {renderValue(value[key], depth + 1)}
              {idx < keys.length - 1 && <span className="datastash__comma">,</span>}
            </div>
          ))}
          <span className="datastash__bracket">{'}'}</span>
        </div>
      );
    }
    return <span>{String(value)}</span>;
  };

  return (
    <div className="datastash">
      <h1 className="datastash__title">Datastash: {datastash.title}</h1>

      {/* Statistics */}
      <div className="datastash__stats-box">
        <p className="datastash__stat-line">
          <strong>Node ID:</strong> {datastash.node_id}
        </p>
        <p className="datastash__stat-line">
          <strong>Data Size:</strong> {datastash.vars_length.toLocaleString()} bytes
        </p>
        {datastash.parsed_data && Array.isArray(datastash.parsed_data) && (
          <p className="datastash__stat-line">
            <strong>Array Length:</strong> {datastash.parsed_data.length.toLocaleString()} items
          </p>
        )}
      </div>

      {/* View Mode Toggle */}
      <div className="datastash__toggle-container">
        <button
          onClick={() => setViewMode('formatted')}
          className={`datastash__toggle-button${viewMode === 'formatted' ? ' datastash__toggle-button--active' : ''}`}
        >
          Formatted View
        </button>
        <button
          onClick={() => setViewMode('raw')}
          className={`datastash__toggle-button${viewMode === 'raw' ? ' datastash__toggle-button--active' : ''}`}
        >
          Raw JSON
        </button>
      </div>

      {/* Content Display */}
      <div className="datastash__section">
        <h2 className="datastash__section-title">Data Contents</h2>

        {datastash.parse_error ? (
          <div className="datastash__error-box">
            <strong>JSON Parse Error:</strong> {datastash.parse_error}
            <div className="datastash__raw-preview">
              <h3>Raw Content (first 1000 chars):</h3>
              <pre className="datastash__raw-code">
                {datastash.vars_raw.substring(0, 1000)}
                {datastash.vars_raw.length > 1000 && '...'}
              </pre>
            </div>
          </div>
        ) : !datastash.vars_raw || datastash.vars_raw === '' ? (
          <p className="datastash__no-data">No data stored in this datastash.</p>
        ) : viewMode === 'formatted' ? (
          <div className="datastash__formatted-view">
            {renderValue(datastash.parsed_data)}
          </div>
        ) : (
          <pre className="datastash__raw-code">
            {JSON.stringify(datastash.parsed_data, null, 2)}
          </pre>
        )}
      </div>

      {/* Info Box */}
      <div className="datastash__info-box">
        <strong>Note:</strong> Datastash nodes store cached JSON data for site features.
        The edit page allows direct modification of the raw JSON content.
        Changes should be made carefully as they may affect site functionality.
      </div>
    </div>
  );
}

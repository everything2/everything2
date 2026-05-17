import React from 'react';

/**
 * Dbtable - Database table schema viewer
 * Styles in CSS: .dbtable__*
 *
 * Displays table structure including columns and indexes.
 */
export default function Dbtable({ data }) {
  const { table, fields, indexes } = data;

  return (
    <div className="dbtable">
      <h1 className="dbtable__title">Database Table: {table.name}</h1>

      {/* Table Statistics */}
      <div className="dbtable__stats-box">
        <p className="dbtable__stat-line">
          <strong>Engine:</strong> {table.engine}
        </p>
        <p className="dbtable__stat-line">
          <strong>Approximate Rows:</strong>{' '}
          {table.approx_rows.toLocaleString()}
          {table.engine !== 'MyISAM' && (
            <span className="dbtable__hint"> (InnoDB estimates may vary)</span>
          )}
        </p>
      </div>

      {/* Fields Section */}
      <div className="dbtable__section">
        <h2 className="dbtable__section-title">Columns ({fields.length})</h2>
        <div className="dbtable__table-wrapper">
          <table className="dbtable__table">
            <thead>
              <tr className="dbtable__header-row">
                <th className="dbtable__th">Field</th>
                <th className="dbtable__th">Type</th>
                <th className="dbtable__th">Null</th>
                <th className="dbtable__th">Key</th>
                <th className="dbtable__th">Default</th>
                <th className="dbtable__th">Extra</th>
              </tr>
            </thead>
            <tbody>
              {fields.map((field, idx) => (
                <tr key={field.name} className={idx % 2 === 0 ? 'dbtable__even-row' : 'dbtable__odd-row'}>
                  <td className="dbtable__td">
                    <code className="dbtable__field-name">{field.name}</code>
                  </td>
                  <td className="dbtable__td">
                    <code>{field.type}</code>
                  </td>
                  <td className="dbtable__td">{field.null}</td>
                  <td className="dbtable__td">
                    {field.key && <span className="dbtable__key-badge">{field.key}</span>}
                  </td>
                  <td className="dbtable__td">
                    {field.default === null ? (
                      <em className="dbtable__null-value">NULL</em>
                    ) : field.default === '' ? (
                      <em className="dbtable__empty-value">(empty)</em>
                    ) : (
                      <code>{field.default}</code>
                    )}
                  </td>
                  <td className="dbtable__td">
                    {field.extra && <code className="dbtable__extra">{field.extra}</code>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Indexes Section */}
      <div className="dbtable__section">
        <h2 className="dbtable__section-title">Indexes ({indexes.length})</h2>
        {indexes.length > 0 ? (
          <div className="dbtable__table-wrapper">
            <table className="dbtable__table">
              <thead>
                <tr className="dbtable__header-row">
                  <th className="dbtable__th">Name</th>
                  <th className="dbtable__th">Seq</th>
                  <th className="dbtable__th">Column</th>
                  <th className="dbtable__th">Collation</th>
                  <th className="dbtable__th">Cardinality</th>
                  <th className="dbtable__th">Sub Part</th>
                  <th className="dbtable__th">Packed</th>
                  <th className="dbtable__th">Comment</th>
                </tr>
              </thead>
              <tbody>
                {indexes.map((idx, i) => (
                  <tr key={`${idx.key_name}-${idx.seq_in_index}`} className={i % 2 === 0 ? 'dbtable__even-row' : 'dbtable__odd-row'}>
                    <td className="dbtable__td">
                      <code className="dbtable__index-name">{idx.key_name}</code>
                    </td>
                    <td className="dbtable__td">{idx.seq_in_index}</td>
                    <td className="dbtable__td">
                      <code>{idx.column_name}</code>
                    </td>
                    <td className="dbtable__td">{idx.collation || '-'}</td>
                    <td className="dbtable__td">
                      {idx.cardinality !== null ? idx.cardinality.toLocaleString() : '-'}
                    </td>
                    <td className="dbtable__td">{idx.sub_part || '-'}</td>
                    <td className="dbtable__td">{idx.packed || '-'}</td>
                    <td className="dbtable__td">{idx.comment || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="dbtable__no-data">No indexes defined on this table.</p>
        )}
      </div>

      {/* Info Box */}
      <div className="dbtable__info-box">
        <strong>Note:</strong> Table schema modifications should be done through{' '}
        <a href="/?node=SQL%20Prompt">SQL Prompt</a> or database migrations.
        The edit page provides basic node metadata editing only.
      </div>
    </div>
  );
}

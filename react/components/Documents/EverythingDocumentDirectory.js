import React, { useState } from 'react';

const EverythingDocumentDirectory = ({ data, e2 }) => {
  const {
    documents = [],
    total_count,
    shown_count,
    limit,
    current_sort = '0',
    filter_user = '',
    filter_nodetype = '',
    permissions = {},
    error,
    message
  } = data;

  // Handle guest user error
  if (error === 'guest') {
    return (
      <div style={styles.container}>
        <p>{message}</p>
      </div>
    );
  }

  const [sortOrder, setSortOrder] = useState(current_sort);
  const [filterUsername, setFilterUsername] = useState(filter_user);
  const [filterNodetype, setFilterNodetype] = useState(filter_nodetype);

  const sortOptions = [
    { value: '0', label: 'whatever the database feels like' },
    { value: 'idA', label: 'node_id, ascending (lowest first)' },
    { value: 'idD', label: 'node_id, descending (highest first)' },
    { value: 'nameA', label: 'title, ascending (ABC)' },
    { value: 'nameD', label: 'title, descending (ZYX)' },
    { value: 'authorA', label: "author's ID, ascending (lowest ID first)" },
    { value: 'authorD', label: "author's ID, descending (highest ID first)" },
    { value: 'createA', label: 'create time, ascending (oldest first)' },
    { value: 'createD', label: 'create time, descending (newest first)' }
  ];

  const handleSubmit = (e) => {
    e.preventDefault();
    const form = e.target;
    form.submit();
  };

  const handleShowAll = () => {
    const url = new URL(window.location.href);
    url.searchParams.set('edd_limit', total_count.toString());
    window.location.href = url.toString();
  };

  // Format timestamp to readable date
  const formatDate = (timestamp) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  const showNodeId = permissions.is_developer || permissions.is_admin;
  const showListNodesLink = permissions.is_developer || permissions.is_editor;

  return (
    <div style={styles.container}>
      {showListNodesLink && (
        <p>
          Lucky you; you also can use{' '}
          <a href="/?node=List+Nodes+of+Type&type=superdoc">List Nodes of Type</a>
        </p>
      )}

      <p>Choose your poison, sir:</p>

      <form method="POST" onSubmit={handleSubmit} style={styles.form}>
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />

        <div style={styles.formGroup}>
          <label style={styles.label}>
            sort order:{' '}
            <select
              name="EDD_Sort"
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              style={styles.select}
            >
              {sortOptions.map(opt => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>
            only show things written by{' '}
            <input
              type="text"
              name="filter_user"
              value={filterUsername}
              onChange={(e) => setFilterUsername(e.target.value)}
              style={styles.textInput}
              placeholder="username"
            />
          </label>
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>
            only show nodes of type{' '}
            <input
              type="text"
              name="filter_nodetype"
              value={filterNodetype}
              onChange={(e) => setFilterNodetype(e.target.value)}
              style={styles.textInput}
              placeholder="nodetype"
            />
          </label>
        </div>

        <button type="submit" style={styles.button}>
          Fetch!
        </button>
      </form>

      <div style={styles.summary}>
        {total_count !== shown_count ? (
          <a href="#" onClick={(e) => { e.preventDefault(); handleShowAll(); }}>
            {total_count}
          </a>
        ) : (
          shown_count
        )}{' '}
        found, {shown_count} most recent shown.
      </div>

      <table style={styles.table}>
        <thead>
          <tr style={styles.headerRow}>
            <th style={styles.th}>title</th>
            <th style={styles.th}>author</th>
            <th style={styles.th}>type</th>
            <th style={styles.th}>created</th>
            {showNodeId && <th style={styles.th}>node_id</th>}
          </tr>
        </thead>
        <tbody>
          {documents.map((doc, index) => (
            <tr key={doc.node_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
              <td style={styles.td}>
                <a href={`/?node_id=${doc.node_id}`}>{doc.title}</a>
              </td>
              <td style={styles.td}>{doc.author}</td>
              <td style={styles.td}>
                <small>{doc.type}</small>
              </td>
              <td style={styles.td}>
                <small>{formatDate(doc.createtime)}</small>
              </td>
              {showNodeId && (
                <td style={styles.td}>{doc.node_id}</td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '1000px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  form: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  formGroup: {
    marginBottom: '10px'
  },
  label: {
    display: 'block',
    fontSize: '14px',
    color: '#111111'
  },
  select: {
    padding: '6px 10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    background: 'white',
    minWidth: '300px'
  },
  textInput: {
    padding: '6px 10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    width: '250px'
  },
  button: {
    padding: '8px 16px',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  summary: {
    marginBottom: '15px',
    fontSize: '14px',
    color: '#507898'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '14px'
  },
  headerRow: {
    backgroundColor: '#f8f9f9'
  },
  th: {
    padding: '8px',
    textAlign: 'left',
    borderBottom: '2px solid #dee2e6',
    fontWeight: 'bold'
  },
  td: {
    padding: '6px 8px',
    borderBottom: '1px solid #dee2e6'
  },
  evenRow: {
    backgroundColor: '#ffffff'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  }
};

export default EverythingDocumentDirectory;

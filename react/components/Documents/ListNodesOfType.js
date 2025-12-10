import React, { useState, useEffect } from 'react';

const ListNodesOfType = ({ data, user }) => {
  const { access_denied, message, node_types = [], default_type = '', is_admin, is_editor, user_id, type } = data;

  // GNL (Gigantic Node Lister) uses same component but shows different title
  const isGNL = type === 'gnl';
  const pageTitle = isGNL ? 'Gigantic Node Lister' : 'List Nodes of Type';

  if (access_denied) {
    return (
      <div style={styles.container}>
        <div style={styles.accessDenied}>
          <p>{message}</p>
        </div>
      </div>
    );
  }

  // Convert to string for controlled select element (HTML select values are always strings)
  const [selectedType, setSelectedType] = useState(default_type ? String(default_type) : '');
  const [nodes, setNodes] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [pageSize, setPageSize] = useState(60);
  const [sort1, setSort1] = useState('0');
  const [sort2, setSort2] = useState('0');
  const [filterUser, setFilterUser] = useState('');
  const [filterUserNot, setFilterUserNot] = useState(false);

  const saveTypePreference = async (typeId) => {
    if (!typeId) return;

    try {
      await fetch('/api/preferences/update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          updates: [{ key: 'ListNodesOfType_Type', value: typeId }]
        })
      });
    } catch (err) {
      console.error('Failed to save type preference:', err);
    }
  };

  const fetchNodes = async () => {
    if (!selectedType) return;
    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams({
        type_id: selectedType,
        sort1,
        sort2,
        offset: offset.toString(),
        filter_user_not: filterUserNot ? '1' : '0'
      });

      if (filterUser) params.append('filter_user', filterUser);

      const response = await fetch('/api/list_nodes/list?' + params);
      const result = await response.json();

      if (result.success) {
        setNodes(result.nodes);
        setTotal(result.total);
        setPageSize(result.page_size);
      } else {
        setError(result.error || 'Failed to fetch nodes');
      }
    } catch (err) {
      setError('Network error: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchNodes();
  }, [selectedType, sort1, sort2, offset, filterUser, filterUserNot]);

  const sortOptions = [
    { value: '0', label: '(no sorting)' },
    { value: 'idA', label: 'node_id, ascending' },
    { value: 'idD', label: 'node_id, descending' },
    { value: 'nameA', label: 'title, ascending' },
    { value: 'nameD', label: 'title, descending' },
    { value: 'authorA', label: 'author ID, ascending' },
    { value: 'authorD', label: 'author ID, descending' },
    { value: 'createA', label: 'created, oldest first' },
    { value: 'createD', label: 'created, newest first' }
  ];

  function formatDate(createtime) {
    // Handle invalid SQL dates (0000-00-00 00:00:00)
    if (!createtime || createtime.startsWith('0000-00-00')) {
      return '—';
    }
    const created = new Date(createtime);
    if (isNaN(created.getTime())) {
      return '—';
    }
    return created.toLocaleString();
  }

  function getAge(createtime) {
    // Handle invalid SQL dates (0000-00-00 00:00:00)
    if (!createtime || createtime.startsWith('0000-00-00')) {
      return '—';
    }

    const created = new Date(createtime);
    if (isNaN(created.getTime())) {
      return '—';
    }

    const now = new Date();
    const diffMs = now - created;
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffDays > 365) return Math.floor(diffDays / 365) + ' yr';
    if (diffDays > 30) return Math.floor(diffDays / 30) + ' mo';
    if (diffDays > 0) return diffDays + ' d';
    return Math.floor(diffMs / 3600000) + ' hr';
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>{pageTitle}</h2>
      
      <div style={styles.section}>
        <label style={styles.label}>
          nodetype:{' '}
          <select
            value={selectedType}
            onChange={(e) => {
              const newType = e.target.value;
              setSelectedType(newType);
              setOffset(0);
              if (newType) {
                saveTypePreference(newType);
              }
            }}
            style={styles.select}
          >
            <option value="">Choose a node type...</option>
            {node_types.map((type) => (
              <option key={type.node_id} value={String(type.node_id)}>
                {type.title}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div style={styles.section}>
        <label style={styles.label}>
          sort: 1:{' '}
          <select value={sort1} onChange={(e) => setSort1(e.target.value)} style={styles.select}>
            {sortOptions.map((opt) => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
          </select>
          {' '}2:{' '}
          <select value={sort2} onChange={(e) => setSort2(e.target.value)} style={styles.select}>
            {sortOptions.map((opt) => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
          </select>
        </label>
      </div>

      <div style={styles.section}>
        <label style={styles.label}>
          <input type="checkbox" checked={filterUserNot} onChange={(e) => setFilterUserNot(e.target.checked)} />{' '}not{' '}
        </label>
        written by{' '}
        <input type="text" value={filterUser} onChange={(e) => setFilterUser(e.target.value)} placeholder="username" style={styles.input} />
      </div>

      {loading && <p style={styles.loading}>Loading...</p>}
      {error && <p style={styles.error}>{error}</p>}

      {!loading && nodes.length > 0 && (
        <>
          <p style={styles.resultInfo}>
            Found <strong>{total}</strong> nodes. (Showing items {offset + 1} to {Math.min(offset + nodes.length, total)}.)
          </p>
          
          <table style={styles.table}>
            <thead>
              <tr>
                <th style={styles.th}>edit</th><th style={styles.th}>title</th><th style={styles.th}>node_id</th>
                <th style={styles.th}>author</th><th style={styles.th}>created</th><th style={styles.th}>age</th>
              </tr>
            </thead>
            <tbody>
              {nodes.map((node, index) => (
                <tr key={node.node_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                  <td style={styles.td}>
                    {node.can_edit && <small>(<a href={'/?node_id=' + node.node_id + '&displaytype=edit'}>edit</a>)</small>}
                  </td>
                  <td style={styles.td}><a href={'/?node_id=' + node.node_id}>{node.title}</a></td>
                  <td style={styles.td}>{node.node_id}</td>
                  <td style={styles.td}><a href={'/?node_id=' + node.author_user}>{node.author_name}</a></td>
                  <td style={styles.td}>{formatDate(node.createtime)}</td>
                  <td style={styles.td}>{getAge(node.createtime)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {total > pageSize && (
            <div style={styles.pagination}>
              {offset > 0 && <button onClick={() => setOffset(Math.max(0, offset - pageSize))} style={styles.button}>prev {pageSize}</button>}
              {offset + pageSize < total && <button onClick={() => setOffset(offset + pageSize)} style={styles.button}>next {Math.min(pageSize, total - offset - pageSize)}</button>}
            </div>
          )}
        </>
      )}

      {!loading && selectedType && nodes.length === 0 && !error && <p style={styles.empty}>No nodes found for this type.</p>}
    </div>
  );
};

const styles = {
  container: { maxWidth: '1200px', margin: '0 auto', padding: '20px' },
  title: { fontSize: '24px', fontWeight: '600', color: '#38495e', marginBottom: '20px' },
  accessDenied: { padding: '40px', textAlign: 'center', background: '#fff3cd', border: '1px solid #ffc107', borderRadius: '4px', color: '#856404' },
  section: { marginBottom: '15px', padding: '10px', background: '#f8f9f9', borderRadius: '4px' },
  label: { fontSize: '14px', color: '#38495e' },
  select: { padding: '5px 10px', fontSize: '14px', border: '1px solid #dee2e6', borderRadius: '4px', marginLeft: '5px' },
  input: { padding: '5px 10px', fontSize: '14px', border: '1px solid #dee2e6', borderRadius: '4px', marginLeft: '5px' },
  resultInfo: { fontSize: '14px', color: '#507898', marginBottom: '15px' },
  loading: { textAlign: 'center', padding: '40px', color: '#507898' },
  error: { padding: '15px', background: '#f8d7da', color: '#721c24', border: '1px solid #f5c6cb', borderRadius: '4px', marginBottom: '15px' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: '14px', background: 'white', border: '1px solid #dee2e6', borderRadius: '4px' },
  th: { padding: '12px', fontWeight: '600', color: '#38495e', background: '#f8f9f9', borderBottom: '2px solid #dee2e6', textAlign: 'left' },
  td: { padding: '10px 12px', borderBottom: '1px solid #eee' },
  evenRow: { background: '#fff' },
  oddRow: { background: '#fafbfc' },
  pagination: { marginTop: '20px', textAlign: 'right' },
  button: { padding: '8px 16px', marginLeft: '10px', background: '#4060b0', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '14px' },
  empty: { textAlign: 'center', padding: '40px', color: '#6c757d', background: '#f8f9f9', borderRadius: '4px' }
};

export default ListNodesOfType;

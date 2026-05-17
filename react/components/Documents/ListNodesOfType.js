import React, { useState, useEffect } from 'react';

/**
 * ListNodesOfType - Node listing by type (GNL)
 * Styles in CSS: .list-nodes-of-type__*
 *
 * Displays nodes of a selected type with filtering and pagination.
 */
const ListNodesOfType = ({ data, user }) => {
  const { access_denied, message, node_types = [], default_type = '', type } = data;

  // GNL (Gigantic Node Lister) uses same component but shows different title
  const isGNL = type === 'gnl';
  const pageTitle = isGNL ? 'Gigantic Node Lister' : 'List Nodes of Type';

  if (access_denied) {
    return (
      <div className="list-nodes-of-type">
        <div className="list-nodes-of-type__access-denied">
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
    <div className="list-nodes-of-type">
      <h2 className="list-nodes-of-type__title">{pageTitle}</h2>

      <div className="list-nodes-of-type__section">
        <label className="list-nodes-of-type__label">
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
            className="list-nodes-of-type__select"
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

      <div className="list-nodes-of-type__section">
        <label className="list-nodes-of-type__label">
          sort: 1:{' '}
          <select value={sort1} onChange={(e) => setSort1(e.target.value)} className="list-nodes-of-type__select">
            {sortOptions.map((opt) => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
          </select>
          {' '}2:{' '}
          <select value={sort2} onChange={(e) => setSort2(e.target.value)} className="list-nodes-of-type__select">
            {sortOptions.map((opt) => <option key={opt.value} value={opt.value}>{opt.label}</option>)}
          </select>
        </label>
      </div>

      <div className="list-nodes-of-type__section">
        <label className="list-nodes-of-type__label">
          <input type="checkbox" checked={filterUserNot} onChange={(e) => setFilterUserNot(e.target.checked)} />{' '}not{' '}
        </label>
        written by{' '}
        <input type="text" value={filterUser} onChange={(e) => setFilterUser(e.target.value)} placeholder="username" className="list-nodes-of-type__input" />
      </div>

      {loading && <p className="list-nodes-of-type__loading">Loading...</p>}
      {error && <p className="list-nodes-of-type__error">{error}</p>}

      {!loading && nodes.length > 0 && (
        <>
          <p className="list-nodes-of-type__result-info">
            Found <strong>{total}</strong> nodes. (Showing items {offset + 1} to {Math.min(offset + nodes.length, total)}.)
          </p>

          <table className="list-nodes-of-type__table">
            <thead>
              <tr>
                <th className="list-nodes-of-type__th">edit</th><th className="list-nodes-of-type__th">title</th><th className="list-nodes-of-type__th">node_id</th>
                <th className="list-nodes-of-type__th">author</th><th className="list-nodes-of-type__th">created</th><th className="list-nodes-of-type__th">age</th>
              </tr>
            </thead>
            <tbody>
              {nodes.map((node, index) => (
                <tr key={node.node_id} className={index % 2 === 0 ? 'list-nodes-of-type__even-row' : 'list-nodes-of-type__odd-row'}>
                  <td className="list-nodes-of-type__td">
                    {node.can_edit && <small>(<a href={'/?node_id=' + node.node_id + '&displaytype=edit'}>edit</a>)</small>}
                  </td>
                  <td className="list-nodes-of-type__td"><a href={'/?node_id=' + node.node_id}>{node.title}</a></td>
                  <td className="list-nodes-of-type__td">{node.node_id}</td>
                  <td className="list-nodes-of-type__td"><a href={'/?node_id=' + node.author_user}>{node.author_name}</a></td>
                  <td className="list-nodes-of-type__td">{formatDate(node.createtime)}</td>
                  <td className="list-nodes-of-type__td">{getAge(node.createtime)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          {total > pageSize && (
            <div className="list-nodes-of-type__pagination">
              {offset > 0 && <button onClick={() => setOffset(Math.max(0, offset - pageSize))} className="list-nodes-of-type__button">prev {pageSize}</button>}
              {offset + pageSize < total && <button onClick={() => setOffset(offset + pageSize)} className="list-nodes-of-type__button">next {Math.min(pageSize, total - offset - pageSize)}</button>}
            </div>
          )}
        </>
      )}

      {!loading && selectedType && nodes.length === 0 && !error && <p className="list-nodes-of-type__empty">No nodes found for this type.</p>}
    </div>
  );
};

export default ListNodesOfType;

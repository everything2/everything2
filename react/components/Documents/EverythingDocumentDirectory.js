import React, { useState } from 'react';
import { formatShortDate } from '../../utils/dateFormat';

/**
 * EverythingDocumentDirectory - Document listing and filtering
 * Styles in CSS: .doc-directory__*
 */
const EverythingDocumentDirectory = ({ data, e2, user }) => {
  const {
    documents = [],
    total_count,
    shown_count,
    limit,
    current_sort = '0',
    filter_user = '',
    filter_nodetype = '',
    available_nodetypes = [],
    permissions = {},
    error,
    message
  } = data;

  // Handle guest user error
  if (error === 'guest') {
    return (
      <div className="doc-directory">
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
  const formatDate = (timestamp) => formatShortDate(timestamp) ?? '';

  // is_admin / is_editor read from the global e2.user prop (#4390);
  // is_developer stays on contentData (PageState user.developer is always-true).
  const isAdmin = !!user?.admin;
  const isEditor = !!user?.editor;

  const showNodeId = permissions.is_developer || isAdmin;
  const showListNodesLink = permissions.is_developer || isEditor;

  return (
    <div className="doc-directory">
      {showListNodesLink && (
        <p>
          Lucky you; you also can use{' '}
          <a href="/?node=List+Nodes+of+Type&type=superdoc">List Nodes of Type</a>
        </p>
      )}

      <p>Choose your poison, sir:</p>

      <form method="POST" onSubmit={handleSubmit} className="doc-directory__form">
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />

        <div className="doc-directory__form-group">
          <label className="doc-directory__label">
            sort order:{' '}
            <select
              name="EDD_Sort"
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              className="doc-directory__select"
            >
              {sortOptions.map(opt => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="doc-directory__form-group">
          <label className="doc-directory__label">
            only show things written by{' '}
            <input
              type="text"
              name="filter_user"
              value={filterUsername}
              onChange={(e) => setFilterUsername(e.target.value)}
              className="doc-directory__text-input"
              placeholder="username"
            />
          </label>
        </div>

        <div className="doc-directory__form-group">
          <label className="doc-directory__label">
            only show nodes of type{' '}
            {/* Was a free-text input; users had to know the exact slug.
                Server-side filter only honors a closed set of types gated
                on role — replaced with a <select> populated from
                available_nodetypes (#4100). */}
            <select
              name="filter_nodetype"
              value={filterNodetype}
              onChange={(e) => setFilterNodetype(e.target.value)}
              className="doc-directory__select"
            >
              <option value="">(all types)</option>
              {available_nodetypes.map(t => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </label>
        </div>

        <button type="submit" className="doc-directory__button">
          Fetch!
        </button>
      </form>

      <div className="doc-directory__summary">
        {total_count !== shown_count ? (
          <a href="#" onClick={(e) => { e.preventDefault(); handleShowAll(); }}>
            {total_count}
          </a>
        ) : (
          shown_count
        )}{' '}
        found, {shown_count} most recent shown.
      </div>

      <table className="doc-directory__table">
        <thead>
          <tr className="doc-directory__header-row">
            <th className="doc-directory__th">title</th>
            <th className="doc-directory__th">author</th>
            <th className="doc-directory__th">type</th>
            <th className="doc-directory__th">created</th>
            {showNodeId && <th className="doc-directory__th">node_id</th>}
          </tr>
        </thead>
        <tbody>
          {documents.map((doc, index) => (
            <tr key={doc.node_id} className={index % 2 === 0 ? 'doc-directory__row--even' : 'doc-directory__row--odd'}>
              <td className="doc-directory__td">
                <a href={`/?node_id=${doc.node_id}`}>{doc.title}</a>
              </td>
              <td className="doc-directory__td">{doc.author}</td>
              <td className="doc-directory__td">
                <small>{doc.type}</small>
              </td>
              <td className="doc-directory__td">
                <small>{formatDate(doc.createtime)}</small>
              </td>
              {showNodeId && (
                <td className="doc-directory__td">{doc.node_id}</td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default EverythingDocumentDirectory;

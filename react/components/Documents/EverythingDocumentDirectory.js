import React, { useState, useEffect, useCallback } from 'react';
import { formatShortDate } from '../../utils/dateFormat';

const FILTER_KEYS = ['filter_user', 'filter_nodetype', 'edd_limit'];

const readFilters = () => {
  const q = new URLSearchParams(window.location.search);
  return {
    filter_user: q.get('filter_user') || '',
    filter_nodetype: q.get('filter_nodetype') || '',
    edd_limit: q.get('edd_limit') || ''
  };
};

/**
 * EverythingDocumentDirectory - Document listing and filtering
 * Styles in CSS: .doc-directory__*
 *
 * Fetch-driven (#4557): the Page is a pure gate; this reads the filters off the URL and fetches
 * GET /api/everything_document_directory. Filtering refetches in place (history.pushState) instead
 * of POSTing the page. Login-required: the API returns state:'guest' for guests.
 */
const EverythingDocumentDirectory = ({ e2, user }) => {
  // NB: every hook runs before any early return -- the previous version returned for guests above
  // its useState calls, which is a Rules-of-Hooks violation.
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [sortOrder, setSortOrder] = useState('0');
  const [filterUsername, setFilterUsername] = useState('');
  const [filterNodetype, setFilterNodetype] = useState('');

  const load = useCallback((params, { push } = {}) => {
    setLoading(true);
    const qs = new URLSearchParams();
    FILTER_KEYS.forEach((k) => { if (params[k]) qs.set(k, params[k]); });
    if (push) {
      const url = new URL(window.location.href);
      FILTER_KEYS.forEach((k) => {
        if (params[k]) url.searchParams.set(k, params[k]);
        else url.searchParams.delete(k);
      });
      window.history.pushState({}, '', url.pathname + url.search);
    }
    return fetch(`/api/everything_document_directory?${qs}`, { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => {
        setData(j);
        // Sort lives in the viewer's stored pref, so it comes back from the server.
        if (j && j.current_sort) setSortOrder(j.current_sort);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    const apply = (p) => {
      setFilterUsername(p.filter_user);
      setFilterNodetype(p.filter_nodetype);
      load(p);
    };
    apply(readFilters());
    const onPop = () => apply(readFilters());
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, [load]);

  const {
    documents = [],
    total_count,
    shown_count,
    limit,
    available_nodetypes = [],
    is_developer,
    state
  } = data || {};

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

  const handleSubmit = async (e) => {
    e.preventDefault();
    // Persist the sort pref via the API first (it used to be a render-time
    // $VARS->{EDD_Sort}= side-effect in the controller, #4416), then refetch -- the API reads the
    // now-stored pref. No page POST: the list reloads in place.
    try {
      await fetch('/api/preferences/set', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ EDD_Sort: sortOrder })
      });
    } catch (err) {
      // best-effort: still show the requested view even if the pref didn't save
    }
    load({ filter_user: filterUsername, filter_nodetype: filterNodetype, edd_limit: '' }, { push: true });
  };

  const handleShowAll = () => {
    load(
      { filter_user: filterUsername, filter_nodetype: filterNodetype, edd_limit: String(total_count) },
      { push: true }
    );
  };

  // Format timestamp to readable date
  const formatDate = (timestamp) => formatShortDate(timestamp) ?? '';

  // is_admin / is_editor read from the global e2.user prop (#4390);
  // is_developer comes from the API (PageState user.developer is always-true).
  const isAdmin = !!user?.admin;
  const isEditor = !!user?.editor;

  const showNodeId = is_developer || isAdmin;
  const showListNodesLink = is_developer || isEditor;

  if (loading && !data) {
    return <div className="doc-directory"><p>Loading...</p></div>;
  }

  if (state === 'guest') {
    return (
      <div className="doc-directory">
        <p>Please log in first.</p>
      </div>
    );
  }

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
            {/* No form `name`: the sort is persisted via /api/preferences/set on
                submit (handleSubmit), not POSTed as a page param (#4416). The
                controller reads it from the viewer's stored VARS pref. */}
            <select
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

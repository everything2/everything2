import React, { useState } from 'react';
import { formatDateTime } from '../../utils/dateFormat';

/**
 * Who Is Doing What - Recent nodes viewer
 * Styles in CSS: .who-is-doing-what__*
 *
 * Admin tool showing recently created nodes.
 */
const WhoIsDoingWhat = ({ data, e2 }) => {
  const {
    access_denied,
    username,
    nodes = [],
    days = 2,
    node_count = 0
  } = data;

  const [daysInput, setDaysInput] = useState(days.toString());

  // Access denied for non-admins
  if (access_denied) {
    return (
      <div className="who-is-doing-what">
        <p className="who-is-doing-what__denied">
          Curiosity killed the cat, this means YOU{' '}
          <a href={`/?node=${encodeURIComponent(username)}`}>{username}</a>
        </p>
      </div>
    );
  }

  const handleSubmit = (e) => {
    e.preventDefault();
    const form = e.target;
    form.submit();
  };

  // Admin tool — shows month/day/time but skips year to save space.
  const formatDate = (dateStr) => formatDateTime(dateStr, { year: undefined }) ?? '';

  // Group nodes by type for summary
  const typeCount = {};
  nodes.forEach(node => {
    typeCount[node.type] = (typeCount[node.type] || 0) + 1;
  });

  return (
    <div className="who-is-doing-what">
      <form method="GET" onSubmit={handleSubmit} className="who-is-doing-what__form">
        <input type="hidden" name="node_id" value={e2?.node?.node_id || ''} />
        <label className="who-is-doing-what__label">
          Show nodes from the last{' '}
          <input
            type="number"
            name="days"
            value={daysInput}
            onChange={(e) => setDaysInput(e.target.value)}
            className="who-is-doing-what__number-input"
            min="1"
            max="30"
          />
          {' '}days
        </label>
        <button type="submit" className="who-is-doing-what__button">
          Update
        </button>
      </form>

      <div className="who-is-doing-what__summary">
        <strong>{node_count}</strong> nodes created in the last <strong>{days}</strong> day{days !== 1 ? 's' : ''}
        {Object.keys(typeCount).length > 0 && (
          <span className="who-is-doing-what__type-summary">
            {' '}({Object.entries(typeCount).map(([type, count], i) => (
              <span key={type}>
                {i > 0 ? ', ' : ''}{count} {type}{count !== 1 ? 's' : ''}
              </span>
            ))})
          </span>
        )}
      </div>

      {nodes.length === 0 ? (
        <p className="who-is-doing-what__empty">No nodes created in this time period.</p>
      ) : (
        <ul className="who-is-doing-what__list">
          {nodes.map((node) => (
            <li key={node.node_id} className="who-is-doing-what__item">
              <a href={`/?node_id=${node.node_id}`} className="who-is-doing-what__node-link">
                {node.title}
              </a>
              <span className="who-is-doing-what__meta">
                {' - '}
                <span className="who-is-doing-what__type">{node.type}</span>
                {' by '}
                <a href={`/?node_id=${node.author_id}`} className="who-is-doing-what__author-link">
                  {node.author}
                </a>
                <span className="who-is-doing-what__time"> ({formatDate(node.createtime)})</span>
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default WhoIsDoingWhat;
